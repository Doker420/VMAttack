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
TELEGRAM_BOT_USERNAME=poslaniya_robot
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

- Telegram: `https://t.me/<TELEGRAM_BOT_USERNAME>?start=ref_<slug>`;
- VK: `https://vk.me/<VK_GROUP_ID>?ref=ref_<slug>`;
- сайт: `https://<WEB_APP_URL>/?ref=<slug>`.

При открытии сайта с `?ref=<slug>` форма отправки доступна сразу, без авторизации. Сообщение отправляется через `POST /api/v1/links/<slug>/messages` и сохраняется в SQLite.

Telegram referral deep link сохраняет получателя и показывает кнопку Web App уже с тем же `?ref=<slug>`. Обычная кнопка `Открыть мой ящик` и меню Telegram также используют `WEB_APP_URL` из `.env`.

## Ежедневные послания

Сервер загружает по одному посланию на строку из файлов, заданных `DAILY_RU_FILE` и `DAILY_EN_FILE`. Можно заменить файлы без изменения кода. В каждом тексте бот дополнительно сообщает, что это игровой тизер сервиса, а не послание реального отправителя.

## Что проверить

- открыть `/?ref=anya` и отправить послание без входа;
- проверить `GET /api/v1/links/anya`;
- проверить `POST /api/v1/links/anya/messages`;
- открыть Telegram-бота, нажать `/start` или referral-ссылку и затем `Открыть мой ящик`;
- проверить нижнюю навигацию Web App и загрузку профиля через `/api/v1/me`;
- проверить `GET /health`.

Telegram polling запускается автоматически, если в `.env` задан `TELEGRAM_BOT_TOKEN`. Для production Web App URL должен быть HTTPS и реально открываться из интернета. Баннер `/start` загружается локальным файлом `TELEGRAM_START_BANNER_FILE`, поэтому Telegram не должен получать ошибку `failed to get HTTP URL content`; при любой ошибке отправка автоматически переключается на текст с кнопкой Web App. Токен и другие секреты нельзя хранить в исходниках или публиковать.

## Оплата и пополнение баланса

Для VIP, раскрытия отправителя и пополнения внутреннего баланса доступны четыре метода: карта через готовую ссылку ЮMoney, xRocket, CryptoBot и СБП с ручной проверкой чека администратором. Методы и их состояние возвращаются через `GET /api/v1/payments/methods`, а checkout выполняется через `POST /api/v1/payments/checkout`.

```dotenv
YUMONEY_RECEIVER=4100118715887132
YUMONEY_PAYMENT_URL=https://yoomoney.ru/quickpay/confirm.xml?... # optional override
YUMONEY_NOTIFICATION_SECRET=
YUMONEY_TOKEN=
YUMONEY_WEBHOOK_SECRET=
CRYPTOBOT_API_TOKEN=
CRYPTOBOT_API_URL=https://pay.crypt.bot/api
CRYPTOBOT_WEBHOOK_SECRET=
XROCKET_API_TOKEN=
XROCKET_CREATE_INVOICE_URL=
XROCKET_WEBHOOK_SECRET=
SBP_PAYMENT_DETAILS=Перевод по СБП на ...
TELEGRAM_ADMIN_IDS=123456789
```

Для CryptoBot и xRocket после оплаты нужно направить callback на `/webhooks/payments/cryptobot` или `/webhooks/payments/xrocket`; для ЮMoney доступен `/webhooks/payments/yoomoney`. Callback можно защитить заголовком `X-Payment-Webhook-Secret`. При заданном `YUMONEY_RECEIVER` ссылка ЮMoney строится автоматически и получает параметры `label` с ID заявки и `sum` с суммой; webhook должен передать тот же `label` и статус `paid`. `YUMONEY_NOTIFICATION_SECRET` и `YUMONEY_TOKEN` остаются пустыми, если уведомления и OAuth API не используются.

СБП создаёт заявку `manual_pending`. Пользователь получает реквизиты и deep link в Telegram, отправляет боту фото или документ чека, а администратор получает копию чека с кнопками «Одобрить» и «Отклонить». После одобрения сумма зачисляется на баланс или активируется выбранная функция. Авторизованный пользователь также может оплатить VIP или раскрытие непосредственно с внутреннего баланса.

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
