# Проект «Послания» 💌

План и техническое задание для сервиса анонимных сообщений: сайт + Telegram-бот + бот ВКонтакте.

> В папке `web/` уже собран интерактивный UI-прототип MVP: лендинг, отправка послания, генерация ссылки, демо-ящик, подключение каналов и сценарий оплаты. Данные прототипа хранятся в `localStorage`, поэтому он работает без ключей и сервера.

## 1. Идея продукта

Пользователь получает персональную ссылку вида `poslaniya.app/anya`, размещает её в профиле или сторис и получает анонимные сообщения. Послания можно читать в личном кабинете, а с платным тарифом — дублировать в Telegram и ВКонтакте.

Ключевой принцип: анонимность отправителя не должна превращаться в отсутствие контроля у получателя. Поэтому в первой версии нужны фильтр запрещённых слов, жалоба, блокировка и ограничение частоты отправки.

### Роли

- **Получатель** — входит через Telegram/VK-бота, создаёт ссылку, принимает послания, модерирует их и подключает тариф.
- **Отправитель** — открывает публичную ссылку, пишет послание без регистрации.
- **Администратор** — управляет пользователями, жалобами, стоп-словами, оплатами, рассылками и настройками каналов.

## 2. Сценарии MVP

### Получатель

1. Нажимает «Создать ссылку» на сайте или `/start` в боте.
2. Авторизуется через Telegram/VK или по email magic link.
3. Выбирает короткий slug и получает ссылку.
4. Копирует ссылку / делится ей в соцсети.
5. Получает послания в веб-ящике и, при подключении, в Telegram/VK.
6. Может пометить послание прочитанным, сохранить, удалить, пожаловаться или заблокировать отправителя.

### Отправитель

1. Переходит по публичной ссылке.
2. Видит имя получателя и форму послания.
3. Пишет от 3 до 500 символов; регистрация и ввод телефона не требуются.
4. Проходит невидимую проверку rate limit/антиспама.
5. Видит подтверждение «Послание отправлено».

### Оплата

1. Получатель выбирает VIP — **20 ₽ на 30 дней**.
2. Если у конкретного послания доступен отправитель, получатель может купить разовое раскрытие — **7 ₽ за одно послание**.
3. Сервер создаёт платёжную сессию и передаёт в браузер только публичные параметры.
4. Открывается CloudPayments Widget.
5. Статус тарифа меняется **только после серверного callback Pay** с проверенной подписью.
6. При `Fail` доступ не выдаётся; при `Refund`/`Recurrent` состояние подписки синхронизируется.

### Авторизация через бота

1. Сайт создаёт одноразовый challenge с TTL 10 минут.
2. Пользователь нажимает «Войти через Telegram» или «Войти через VK».
3. Сайт открывает deep link бота: `t.me/{bot}?start=auth_{challenge}` либо ссылку VK с ref-параметром.
4. Бот получает challenge, связывает `provider_user_id` с аккаунтом и отправляет подтверждение.
5. Backend переводит challenge в короткую сессию; frontend получает только access/refresh токены.
6. Повторное использование challenge, истёкшие challenge и чужой provider id отклоняются.

В UI-прототипе этот сценарий можно пройти в demo-режиме кнопкой «Я уже в боте». В `web/server.mjs` уже есть challenge endpoints и обработчики `/webhooks/telegram` и `/webhooks/vk`.

## 3. Объем первой версии

### Уже сделано в UI-прототипе

- адаптивный лендинг на русском языке;
- mobile-first стили и доступные focus-состояния;
- публичная форма отправки анонимного послания;
- счётчик символов и сообщение об успешной отправке;
- генерация и копирование персональной ссылки;
- демо-личный кабинет с unread-счётчиками и списком посланий;
- сохранение демо-сообщений между обновлениями страницы через `localStorage`;
- demo-вход через Telegram/VK-бота с экраном deep link и подтверждением;
- Telegram Web App shell с общим inbox и общей сессией;
- единый demo API для сайта, Web App и webhook-ботов;
- тариф VIP 20 ₽ / 30 дней;
- разовая опция «узнать отправителя» за 7 ₽;
- переключатель ежедневных рандомных посланий с opt-in;
- demo-сценарии платежа через CloudPayments;
- тарифы, объяснение сервиса и блок безопасности.

### Требует подключения серверной части

- авторизация и реальные аккаунты;
- база данных и постоянные послания;
- вебхуки Telegram и VK;
- реальная интеграция CloudPayments;
- антиспам, модерация и уведомления;
- административная панель и журнал аудита.

## 4. Рекомендуемая архитектура

```text
                        ┌──────────────────┐
                        │  Web / публичная │
                        │  ссылка + кабинет│
                        └────────┬─────────┘
                                 │ HTTPS JSON API
┌───────────────┐        ┌────────▼─────────┐        ┌───────────────┐
│ Telegram Bot  ├───────►│ API / application│◄───────┤ VK Bot        │
│ webhook       │        │ auth, inbox, pay │        │ callback API   │
└───────────────┘        └───────┬─────────┘        └───────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │ PostgreSQL + Redis/queue  │
                    └────────────┬─────────────┘
                                 │ callbacks
                         ┌───────▼────────┐
                         │ CloudPayments  │
                         └────────────────┘
```

### Единая точка входа

Сайт и Telegram Web App не должны быть двумя продуктами. Это один frontend на одном origin и один backend API:

- Telegram `/start` или `/app` привязывает `provider_user_id` и выдаёт кнопку открытия Web App;
- Web App передаёт `Telegram.WebApp.initData`, backend проверяет HMAC через bot token и выдаёт обычную сессию;
- Web App, сайт и боты читают один inbox, одну персональную ссылку, один VIP-статус и одни настройки daily-уведомлений;
- новое послание из любого канала вызывает общий notification service, который доставляет его в подключённые identities;
- VK использует ту же ссылку на Web App через кнопку `open_link`.

Нельзя доверять `initDataUnsafe` на сервере и нельзя считать Web App пользователя авторизованным без HMAC-проверки `initData`.

### Стек

- **Frontend:** Next.js/React или текущий статический UI как стартовая страница; TypeScript, CSS Modules.
- **API:** ASP.NET Core 8 Minimal API (логично для текущего .NET-репозитория) либо NestJS. REST API + webhook endpoints.
- **Хранилище:** PostgreSQL; Redis для rate limit, идемпотентности и очереди уведомлений.
- **Файлы/экспорт:** S3-совместимое хранилище, если понадобится экспорт в файл.
- **Инфраструктура:** Docker Compose для разработки, HTTPS reverse proxy, CI с миграциями и health-check.

## 5. Модель данных

### `users`

`id`, `display_name`, `email`, `created_at`, `status`, `timezone`.

### `identities`

`id`, `user_id`, `provider` (`telegram` | `vk` | `email`), `provider_user_id`, `username`, `access_token_encrypted`, `created_at`.

### `public_links`

`id`, `user_id`, `slug`, `title`, `is_active`, `welcome_text`, `created_at`.

Уникальный индекс на `slug`; slug разрешает кириллицу и латиницу, но нормализуется в lowercase.

### `messages`

`id`, `public_link_id`, `body_encrypted`, `status` (`unread` | `read` | `saved` | `deleted`), `sender_fingerprint_hash`, `moderation_status`, `created_at`.

Текст лучше хранить зашифрованным на уровне приложения. IP/UA не показывать пользователю; fingerprint — только для rate limit и с ограниченным TTL.

### `subscriptions` / `payments`

`id`, `user_id`, `plan` (`vip_30d` | `reveal_sender`), `message_id` nullable, `cloudpayments_transaction_id`, `status`, `amount`, `currency`, `paid_at`, `next_payment_at`, `raw_event_hash`.

VIP создаёт доступ до `paid_at + 30 дней`; `reveal_sender` привязан к конкретному `message_id` и расходуется ровно один раз.

`raw_event_hash` нужен для идемпотентной обработки callback: повторный Pay не должен дважды включать тариф.

### `reports` / `blocked_fingerprints`

Жалобы, причина, статус обработки, кто заблокировал, срок блокировки и служебный fingerprint отправителя.

## 6. API-контракт

```http
POST /api/v1/auth/{telegram|vk}/start
POST /api/v1/auth/{telegram|vk}/complete
POST /api/v1/auth/telegram/webapp
GET  /api/v1/me
GET  /api/v1/plans
POST /api/v1/links
GET  /api/v1/links/{slug}
POST /api/v1/links/{slug}/messages
GET  /api/v1/inbox?cursor=...
POST /api/v1/messages/{id}/read
POST /api/v1/messages/{id}/save
POST /api/v1/messages/{id}/report
POST /api/v1/integrations/{telegram|vk}/connect
PUT  /api/v1/retention/settings
POST /api/v1/retention/broadcast
POST /api/v1/messages/{id}/reveal
POST /api/v1/payments/checkout
POST /webhooks/cloudpayments/{check|pay|fail|confirm|refund|recurrent|cancel}
POST /webhooks/telegram
POST /webhooks/vk
GET  /health
```

`POST /api/v1/links/{slug}/messages` должен возвращать одинаковый нейтральный ответ при существующем и ограниченном slug, чтобы не помогать перебирать ссылки:

```json
{ "ok": true, "message": "Послание отправлено" }
```

## 7. Telegram-бот

### Команды

- `/start` — приветствие, вход/привязка аккаунта;
- `/link` — показать и скопировать персональную ссылку;
- `/inbox` — последние 5 посланий;
- `/settings` — уведомления, фильтр, приватность;
- `/help` — помощь и правила.

### Уведомление о новом послании

> 💌 Новое анонимное послание для вас\n\n«Текст сообщения…»\n\n[Открыть ящик] [Сохранить] [Пожаловаться]

Использовать webhook, secret token, проверку `X-Telegram-Bot-Api-Secret-Token`, idempotency по `update_id` и очередь отправки.

### Telegram Web App

- `WEB_APP_URL` — HTTPS origin сайта;
- `/start` и `/app` создают/находят пользователя и отправляют inline keyboard с `web_app.url`;
- `setChatMenuButton` задаёт постоянную кнопку «Мой ящик»;
- frontend вызывает `Telegram.WebApp.ready()` и `expand()`;
- backend принимает `Telegram.WebApp.initData`, проверяет HMAC по алгоритму Telegram и срок `auth_date`;
- после валидации Web App получает обычную сессию и использует `/api/v1/inbox`, `/api/v1/links`, `/api/v1/payments` и `/api/v1/retention/settings`;
- в Telegram-сообщениях о новом послании прикладывается кнопка «Открыть мой ящик».

## 8. Ежедневные рандомные послания

Функция удержания включается пользователем в настройках бота и по умолчанию выключена. Это не безусловный спам: отправлять сообщение можно только пользователям с явным согласием на daily-уведомления и активной связкой Telegram/VK.

- scheduler запускается раз в 24 часа;
- выбирает случайный текст из безопасного каталога или генерирует его из заранее проверенных шаблонов;
- выбирает всех пользователей с `daily_enabled = true` и активной подпиской/согласием;
- отправляет одно сообщение через Telegram Bot API или VK Messages API;
- пишет результат доставки в `notification_deliveries`, повторяет временные ошибки через очередь;
- кнопка `/settings` и ссылка «Отключить ежедневные послания» должны быть в каждом сообщении;
- тихие часы и часовой пояс пользователя учитываются перед отправкой;
- дневной лимит — одно послание на пользователя.

В demo API есть `PUT /api/v1/retention/settings` и `POST /api/v1/retention/broadcast`; встроенный scheduler запускается в `web/server.mjs`. Для production заменить in-memory хранилища на Redis/PostgreSQL и вынести worker в отдельный процесс.

## 9. Бот ВКонтакте

- Callback API, подтверждение callback-сервера;
- клавиатура: «Моя ссылка», «Последние послания», «Настройки»;
- отправка нового послания в личные сообщения сообщества;
- обработка повторов по `event_id`;
- хранение только минимального `vk_user_id` и статуса согласия на уведомления.

## 10. CloudPayments

Использовать [официальную документацию CloudPayments](https://developers.cloudpayments.ru/):

1. публичный ключ — только во frontend/widget;
2. `PublicId`, `Amount`, `Currency`, `Description`, `InvoiceId` передавать из backend;
3. секретный пароль не хранить во frontend и не логировать;
4. для callback проверять HMAC SHA-256 заголовка `X-Content-HMAC` по сырому body;
5. `Check` использовать для валидации счета, `Pay` — для выдачи доступа, `Fail` — для ошибки;
6. включить идемпотентность по `InvoiceId`/transaction id;
7. для подписки хранить токен и получать события `Recurrent`/`Cancel`;
8. продумать возврат и ручную синхронизацию статусов из CloudPayments API.

Пример клиентского вызова после добавления виджета (секреты сюда не попадают):

```js
const widget = new cp.CloudPayments();
widget.pay('charge', {
  publicId: window.RUNTIME_CLOUDPAYMENTS_PUBLIC_ID,
  description: 'VIP-доступ «Послания», 30 дней',
  amount: 20,
  currency: 'RUB',
  invoiceId: checkout.invoiceId,
  accountId: checkout.accountId
}, {
  onSuccess: () => showPaymentPending(),
  onFail: () => showPaymentFailed(),
  onComplete: () => refreshSubscription()
});
```

Frontend не должен считать `onSuccess` подтверждением подписки: окончательный статус приходит через API после callback `Pay`.

## 11. Безопасность и модерация

- HTTPS везде, secure/httpOnly/sameSite cookies;
- CSRF для cookie-сессии или короткоживущие access/refresh tokens;
- rate limit: например, 5 сообщений на slug в 10 минут и 30 в сутки с одного fingerprint;
- лимит размера body, нормализация Unicode и санитизация HTML;
- Cloudflare Turnstile после подозрительного поведения;
- стоп-слова и модерационный статус до уведомления в боты;
- кнопки «Пожаловаться» и «Заблокировать» в ящике;
- удаление технических fingerprint/IP по TTL, экспорт и удаление данных по запросу;
- аудит админских действий, секреты только в secret manager.

Важно явно написать в оферте, privacy policy и интерфейсе: анонимность означает отсутствие отображения профиля отправителя, но не обещает абсолютную неотслеживаемость при противоправных действиях.

## 12. Этапы реализации

### Этап 0 — уточнение (1–2 дня)

- название, домен, визуальные референсы и tone of voice;
- лимиты бесплатного тарифа, стоимость и модель recurring;
- политика хранения данных, возрастное ограничение, список стоп-слов;
- создание Telegram-бота, сообщества VK и кабинета CloudPayments.

### Этап 1 — backend core (4–6 дней)

- проект API, PostgreSQL migrations, Redis;
- авторизация Telegram/VK и сессии;
- создание slug, публичная форма, inbox;
- rate limit, базовая модерация и жалобы;
- OpenAPI, тесты и Docker Compose.

### Этап 2 — боты (3–4 дня)

- Telegram webhook + команды + inline buttons;
- VK Callback API + клавиатура;
- очередь уведомлений, retry и журнал доставок;
- тестирование повторных webhook-событий.

### Этап 3 — платежи (2–3 дня)

- CloudPayments Widget;
- backend checkout, callback-подписи, idempotency;
- включение тарифа, recurring/cancel/refund;
- тестовые платежи и чек-лист перехода в production.

### Этап 4 — hardening и запуск (3–5 дней)

- адаптивный frontend на реальном API;
- privacy/offer, error states, аналитика без текста посланий;
- нагрузочный тест отправки;
- мониторинг, backup, staging и production deploy.

## 13. Definition of Done для MVP

- послание от отправителя попадает в ящик не более чем за 5 секунд;
- отправитель не обязан регистрироваться;
- одно и то же webhook-событие не создаёт дубль;
- платный доступ выдаётся только после валидного `Pay` callback;
- пользователь может удалить послание и запросить удаление аккаунта;
- Telegram и VK можно отключить;
- проект запускается одной командой через Docker Compose;
- покрыты тестами создание slug, rate limit, подпись CloudPayments и permissions inbox.
