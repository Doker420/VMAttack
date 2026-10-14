# Послания — Web App и боты

`web/` содержит готовый Web App, HTTP API и Telegram long polling transport. Запуск выполняется из корня репозитория; отдельный запуск из старого проекта или перенос базы из `web/data` не нужен.

## Запуск из корня

```bash
cp .env.example .env
npm install
npm start
# или напрямую:
node server.mjs
```

После запуска откройте значение `WEB_APP_URL` из `.env` или локально `http://localhost:4173`.

Все настройки приложения загружаются из корневого `.env`. Секреты в Git не добавляются. На Node.js 20 используется `better-sqlite3`, на Node.js 22+ — встроенный `node:sqlite`. Если SQLite-драйвер недоступен, включается JSON fallback с предупреждением.

```dotenv
WEB_APP_URL=https://app.goago.club
# Optional: getMe resolves the production username automatically; set this only to override it.
TELEGRAM_BOT_USERNAME=
VK_GROUP_ID=poslaniya_demo
VK_API_VERSION=5.199
DB_DRIVER=sqlite
SQLITE_FILE=data/dev.sqlite
DAILY_RU_FILE=content/daily/ru.txt
DAILY_EN_FILE=content/daily/en.txt
```

SQLite-файл и JSON runtime-состояние создаются в корневой `data/`. Файлы ежедневных посланий находятся в `content/daily/ru.txt` и `content/daily/en.txt`; в каждом файле по 500 вариантов.

## Referral-ссылки

Форматы ссылок строятся из значений `.env` и конкретного slug получателя:

- Telegram-бот: `https://t.me/<TELEGRAM_BOT_USERNAME>?start=ref_<slug>` — открывает обычный диалог бота с персональным параметром;
- VK: `https://vk.me/<VK_GROUP_ID>?ref=ref_<slug>`;
- сайт: `https://<WEB_APP_URL>/?ref=<slug>` — обычная форма послания без Web App.

Telegram-ссылка использует обычный bot deep link. После нажатия Telegram передаёт боту `/start ref_<slug>`, бот сохраняет получателя и показывает кнопку открытия формы. Настройка Main Mini App для этой ссылки не требуется.

При открытии обычной ссылки `https://app.goago.club/?ref=<slug>` форма отправки доступна сразу, без авторизации и без Telegram Web App. Сообщение отправляется через `POST /api/v1/links/<slug>/messages` и сохраняется в SQLite. Параметр `app=1` используется только для личного кабинета, а не для публичной реферальной ссылки.

Кнопка `Открыть мой ящик` в Telegram открывает личный кабинет владельца.

## Отправка посланий из Telegram через userbot

В меню Telegram добавлена кнопка `✍️ Написать послание`: отправитель указывает публичный `@username` получателя, после чего может отправить текст, фото, видео, голосовое, видеосообщение-кружок, стикер, аудио, GIF или файл. Referral deep link `?start=ref_<slug>` сразу открывает тот же режим для конкретного получателя. Прямой ввод `@username` не зависит от `publicLinks`: если Telegram identity ещё нет в локальном storage, сервер создаёт техническую запись получателя для userbot-доставки, а при последующем `/start` связывает её с реальным Telegram ID. Referral flow при этом по-прежнему использует только `ref_<slug>` и не подменяется поиском по username.

Сначала сервер проверяет доступность чата через Bot API. Если получатель уже запускал бота, послание отправляется обычным Bot API, а userbot вообще не вызывается. Если Bot API подтверждает, что получатель ещё не открывал бота, и `TELEGRAM_USERBOT_ENABLED=true` с авторизованной сессией, послание доставляется через Telegram userbot. Медиа скачивается Bot API и загружается userbot в исходном типе. В сообщение добавляются рекламная подпись «Послание отправлено через Послания 💌» и кнопка `🔎 Узнать кто отправил · 7 ₽`, которая ведёт в бота на оплату раскрытия. Если userbot временно не готов, для пользователей, уже открывших бота, сохраняется Bot API fallback.

Для relay медиа userbot использует тот же `TELEGRAM_BOT_TOKEN`, а отдельный userbot требует `TELEGRAM_USERBOT_API_ID`, `TELEGRAM_USERBOT_API_HASH` и `TELEGRAM_USERBOT_SESSION`.

## Ежедневные послания

Сервер загружает по одному посланию на строку из файлов, заданных `DAILY_RU_FILE` и `DAILY_EN_FILE`. Можно заменить файлы без изменения кода. Каждый день активным пользователям, подключившим Telegram или VK, отправляется одно сообщение из этой библиотеки с пометкой «Аноним». Такое сообщение также появляется в Web App как ежедневное послание без реального отправителя. По умолчанию рассылка включена; пользователь может отключить её в настройках.

## Что проверить

- открыть `/?ref=anya` и отправить послание без входа;
- проверить `GET /api/v1/links/anya`;
- проверить `POST /api/v1/links/anya/messages`;
- открыть Telegram-бота, нажать `/start` или referral-ссылку и затем `Открыть мой ящик`;
- проверить нижнюю навигацию Web App и загрузку профиля через `/api/v1/me`;
- проверить `GET /health`.

Telegram polling запускается автоматически, если в `.env` задан `TELEGRAM_BOT_TOKEN`. При `/start` бот выдаёт одноразовый Web App auth-токен для первичной передачи авторизации. Он нужен только один раз: после обмена через `POST /api/v1/auth/telegram/token` сайт получает постоянную серверную сессию, сохраняемую вместе с пользователем. Повторно нажимать `/start` не требуется; при открытии настоящего Telegram Web App сервер также автоматически проверяет подписанный `initData`. Скопированная обычная реферальная ссылка авторизацию не выполняет — она сразу открывает форму отправки послания. Для production Web App URL должен быть HTTPS и реально открываться из интернета. Баннер `/start` загружается локальным файлом `TELEGRAM_START_BANNER_FILE`, поэтому Telegram не должен получать ошибку `failed to get HTTP URL content`; при любой ошибке отправка автоматически переключается на текст с кнопкой Web App. Токен и другие секреты нельзя хранить в исходниках или публиковать.

## Анонимные подарки через MyStars и Telegram userbot

В Web App пользователь указывает `@username` получателя и подтверждает заказ. Рубли списываются с его внутреннего баланса. Premium и прямые Telegram Stars доставляются через MyStars; обычный Telegram Star Gift выбирается из актуального Telegram-каталога и отправляется через userbot. Внутренние MyStars-заказы пользователю не показываются.

Для Premium и Stars backend создаёт MyStars-заказ, отслеживает его через callback и после доставки показывает заказ как выполненный. Для обычного Star Gift при нехватке Stars на userbot создаётся отдельное MyStars-пополнение, после чего подарок отправляется userbot. API key задаётся только в root `.env`:

```dotenv
MYSTARS_API_KEY=
MYSTARS_API_URL=https://api.mystars.tg
MYSTARS_PAYMENT_CURRENCY=ton

# Цена одного Telegram Star в рублях для списания с внутреннего баланса.
# Не указывайте сюда Telegram option.amount: для native currency это минимальные единицы.
MYSTARS_BALANCE_MARKUP_PERCENT=10
MYSTARS_BALANCE_STARS_RUB_PER_UNIT=
MYSTARS_BALANCE_PREMIUM_3_RUB=
MYSTARS_BALANCE_PREMIUM_6_RUB=
MYSTARS_BALANCE_PREMIUM_12_RUB=
```

Userbot запускается из того же production entrypoint — `node server.mjs`; второй постоянный процесс не нужен. Настройки находятся в корневом `.env`:

```dotenv
TELEGRAM_USERBOT_ENABLED=false
TELEGRAM_USERBOT_API_ID=
TELEGRAM_USERBOT_API_HASH=
TELEGRAM_USERBOT_SESSION=
# Leave blank to build the promo link from the verified username returned by getMe.
TELEGRAM_USERBOT_GIFT_PROMO=
```

Одноразовая настройка:

1. Получите собственные API ID и API hash на `https://my.telegram.org`.
2. Запишите их в root `.env` и оставьте `TELEGRAM_USERBOT_ENABLED=false`.
3. Запустите `node userbot/setup.mjs` из корня. Скрипт запросит номер телефона, код Telegram и пароль 2FA, если он включён.
4. Убедитесь, что аккаунт userbot имеет публичный `@username` и Stars для первой покупки либо настроенный MyStars.
5. Скопируйте напечатанный `StringSession` в `TELEGRAM_USERBOT_SESSION`, затем включите `TELEGRAM_USERBOT_ENABLED=true` и перезапустите `node server.mjs`.

Каталог доступен через `GET /api/v1/gifts/catalog` только авторизованному Web App. Callback MyStars принимается на `/webhooks/mystars` и сверяется через `GET /v1/orders/:id`. Отправитель подарка не передаётся получателю и не раскрывается. Получатель выбирается по Telegram `@username`. Успешный Star Gift содержит промо-текст, заданный `TELEGRAM_USERBOT_GIFT_PROMO`.

## Оплата и пополнение баланса

Для VIP, раскрытия отправителя и пополнения внутреннего баланса доступны четыре метода: карта через готовую ссылку ЮMoney, xRocket, CryptoBot и СБП с ручной проверкой чека администратором. Методы и их состояние возвращаются через `GET /api/v1/payments/methods`, а checkout выполняется через `POST /api/v1/payments/checkout`.

```dotenv
YUMONEY_RECEIVER=4100118715887132
YUMONEY_PAYMENT_URL=https://yoomoney.ru/quickpay/confirm.xml?... # optional override
# OAuth token with operation-history scope; used to confirm incoming payments by label.
YUMONEY_TOKEN=
YUMONEY_API_URL=https://yoomoney.ru/api
# Crypto Pay API token. CryptoBot webhook signatures are derived from this token;
# there is no separate CryptoBot webhook secret to configure.
CRYPTOBOT_API_TOKEN=
CRYPTOBOT_API_URL=https://pay.crypt.bot/api
# Background server reconciliation interval; it runs even with no Web App open.
PAYMENT_RECONCILE_INTERVAL_MS=15000
XROCKET_API_TOKEN= # именно Pay API token из приложения xRocket
XROCKET_TESTNET=false
XROCKET_API_URL=https://pay.api.xrocket.exchange
XROCKET_WEBHOOK_SECRET=
# Суммы каталога в приложении указаны в RUB; backend конвертирует их в актив xRocket.
XROCKET_PRICE_CURRENCY=USDT
XROCKET_FALLBACK_PRICE_CURRENCY=USDT
XROCKET_RUB_ASSET_RATE=
XROCKET_PAYOUT_CURRENCY=
# Заполните реальными реквизитами; при пустом значении кнопка СБП скрывается.
SBP_PAYMENT_DETAILS=
TELEGRAM_ADMIN_IDS=123456789
```

Для CryptoBot callback URL нужно один раз указать в `@CryptoBot` → приложение → `Webhooks`: `${origin(WEB_APP_URL)}/webhooks/payments/cryptobot`. Crypto Pay не использует отдельный webhook secret: `Crypto-Pay-API-Signature` проверяется через SHA-256 от `CRYPTOBOT_API_TOKEN` как HMAC-ключ. В production `WEB_APP_URL` должен быть публичным HTTPS-адресом, доступным от CryptoBot/xRocket; проверьте DNS, reverse proxy, TLS, путь `/webhooks/payments/*` и токены. Для актуального xRocket Pay callback создаётся вложенным объектом `callback`, а server принимает documented envelope `type=invoice`, `data.event=invoice_status_changed|payment_status_changed`; при наличии `XROCKET_WEBHOOK_SECRET` дополнительно проверяется HMAC-подпись `v1`. Callback сверяет client invoice ID или внешний invoice ID и сумму существующей заявки. Независимо от callback и открытого Web App сервер после запуска периодически сверяет все pending-платежи: CryptoBot через `getInvoices({ invoice_ids: [invoice_id] })`, xRocket через invoice endpoint, YooMoney через operation history. В CryptoBot только статус `paid` зачисляет оплату; `active` остаётся pending, а `expired` закрывает заявку. Поэтому для фоновой сверки должны быть заполнены соответствующие API-токены. После подтверждения платежа сервер сразу отправляет пользователю сообщение в Telegram с суммой зачисления и текущим балансом. Если Bot API временно недоступен, уведомление остаётся в очереди и повторяется следующим циклом сверки.

ЮMoney не требует `successURL` для этого сценария: ссылка содержит только `receiver`, `sum`, `targets` и уникальный `label`. Сервер подтверждает поступление через `POST /api/operation-history` с form-параметрами `label` и `records`, OAuth `YUMONEY_TOKEN` (scope `operation-history`), проверяя `label`, `status=success`, входящее направление и точную сумму. Поэтому ЮMoney показывается как способ оплаты только при наличии OAuth token; после оплаты Web App polling автоматически обновляет баланс. `/webhooks/payments/yoomoney` оставлен для совместимости, но основная надёжная проверка — через историю операций.

СБП создаёт заявку `manual_pending`: без банковского API сервер не может автоматически доказать перевод по реквизитам. Пользователь получает реквизиты и deep link в Telegram, отправляет боту фото или документ чека, а администратор получает копию чека с кнопками «Одобрить» и «Отклонить». Web App также polling-ит заявку и сразу обновляет баланс после одобрения. После одобрения сумма зачисляется на баланс или активируется выбранная функция. Авторизованный пользователь также может оплатить VIP или раскрытие непосредственно с внутреннего баланса.

## Ответы, блокировка и стикеры

У каждого послания доступны «Ответить», «Узнать кто · 7 ₽» и «Заблокировать» — в Web App и в Telegram-уведомлении. Ответ доставляется через Telegram только если backend подтвердил `Telegram.WebApp.initData`; у обычного анонимного web-отправителя ответ сохраняется в карточке с явным статусом, что канала доставки нет. Блокировка хранится отдельно для владельца и использует SHA-256 fingerprint первого forwarded IP или socket IP вместе с User-Agent; исходные IP/UA не сохраняются.

Стикеры задаются Telegram `file_id` в корневом `.env`:

```dotenv
TELEGRAM_STICKER_ID=
TELEGRAM_RECEIVED_STICKER_ID=
TELEGRAM_SENT_STICKER_ID=
```

`TELEGRAM_STICKER_ID` — общий fallback, а два специализированных значения имеют приоритет. Пустые значения отключают стикеры, не отключая сообщения.

## Групповой чат Telegram

Бот получает `my_chat_member`, приветствует себя после добавления в `group` или `supergroup` и обрабатывает только команды `/start`, `/app`, `/link`, `/daily`, `/help`. Обычные сообщения в группе игнорируются. Режим и allowlist настраиваются в root `.env`:

```dotenv
TELEGRAM_GROUPS_ENABLED=true
TELEGRAM_GROUP_CHAT_IDS=-1001234567890,-1009876543210
```

Пустой allowlist означает все группы. Если Telegram privacy mode мешает получать нужные обновления, откройте BotFather → `/setprivacy` → выберите бота → `Disable`, затем перезапустите процесс. Для production также проверьте, что polling/webhook получает `message`, `callback_query` и `my_chat_member`.
