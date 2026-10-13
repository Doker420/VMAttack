# Послания — единый Web + Bot MVP

Интерактивный сервис анонимных посланий, где сайт, Telegram Web App, Telegram-бот и VK-бот используют общий API, аккаунт, ящик, тарифы и настройки рассылок.

## Запуск

Из корня репозитория:

```bash
# Node 20: ставим SQLite-драйвер
npm install
node web/server.mjs
```

На Node.js 22+ встроенный `node:sqlite` используется автоматически. На Node.js 20 используется `better-sqlite3` из `package.json`.

Откройте `http://localhost:4173`.

Сервер использует встроенные модули Node.js и SQLite-драйвер для development, одновременно отдавая сайт и demo API. На Node 20 после `npm install` используется `better-sqlite3`; если драйвер временно недоступен, включается JSON fallback с предупреждением. Файл dev-базы создаётся в `web/data/dev.sqlite` и не попадает в Git. Для одного только UI также можно запустить:

```bash
python3 -m http.server 4173 --directory web --bind 0.0.0.0
```

Сборщик и зависимости не нужны: HTML, CSS и vanilla JavaScript специально оставлены простыми для дальнейшего подключения к production API.

### Переменные для ботов

```bash
TELEGRAM_BOT_USERNAME=poslaniya_robot
TELEGRAM_BOT_TOKEN=...
VK_GROUP_ID=poslaniya_demo
VK_GROUP_TOKEN=...
VK_CONFIRMATION_TOKEN=...
WEB_APP_URL=https://app.gogoa.club
DB_DRIVER=sqlite
SQLITE_FILE=web/data/dev.sqlite
PORT=4173
```

Без токенов работают demo-авторизация, Web App shell, общий inbox, тарифы и настройки удержания. При наличии токенов scheduler сможет отправлять ежедневные сообщения через официальные API Telegram/VK.

## Единый организм

- `/start` и `/app` в Telegram автоматически создают/находят общий аккаунт и отправляют кнопку Telegram Web App;
- `setChatMenuButton` на production настраивает постоянную кнопку «Мой ящик»;
- Web App подтверждает `Telegram.WebApp.initData` на backend, после чего получает ту же сессию, что и сайт;
- сайт и Web App читают один `/api/v1/inbox`, отправляют в один `/api/v1/links/{slug}/messages` и используют одинаковые платежи/retention settings;
- новое послание из сайта вызывает общий `notifyUser`, который доставляет уведомление в привязанные Telegram и VK identities;
- VK-бот отправляет такую же ссылку на общий Web App через inline keyboard.

Telegram Web App требует HTTPS в production. Укажите его адрес в `WEB_APP_URL` и устанавливайте webhook на `/webhooks/telegram` только в webhook-режиме.

По умолчанию бот работает через отдельный модуль `telegram-bot.mjs` в polling-режиме, поэтому для старта не нужен публичный webhook. Баннер `/start` находится в `web/assets/start-banner.png`, а Telegram получает его через `TELEGRAM_START_BANNER_URL`.

## Что можно проверить

- «Получить свою ссылку» → введите имя → скопируйте созданную ссылку;
- форма на hero-экране → отправьте тестовое послание;
- «Мои послания» → откройте inbox, увидите счётчики и тестовое сообщение;
- «Подключить Telegram или VK» → сценарии каналов;
- «Подключить VIP» → демо-сценарий оплаты 20 ₽ за 7 дней;
- «Узнать отправителя» → демо-сценарий разовой оплаты 7 ₽;
- обновите страницу: демо-сообщения сохраняются в `localStorage`.

Без production-токенов кнопки платежей и авторизации работают в demo-режиме. Webhook/API-контракты и план запуска находятся в [`../docs/anonymous-messages-plan.md`](../docs/anonymous-messages-plan.md).

## Быстрый запуск Telegram-бота в polling-режиме

Polling нужен для первого запуска без публичного HTTPS webhook:

```bash
export TELEGRAM_BOT_TOKEN='токен_бота'
export TELEGRAM_BOT_USERNAME='имя_бота_без_@'
export TELEGRAM_ADMIN_IDS='ваш_telegram_id'
export TELEGRAM_MODE=polling
node web/server.mjs
```

После запуска бот отвечает на `/start`, показывает выбор `Русский / English`, открывает Web App, принимает callback-кнопки, отправляет daily-послания и поддерживает `/admin`, `/stats` через админскую панель.

Команда `/id` показывает Telegram ID, который нужно добавить в `TELEGRAM_ADMIN_IDS`. Токен не следует хранить в Git или публиковать в чате.
