import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createHmac, randomUUID } from 'node:crypto';
import { extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('.', import.meta.url));
const PORT = Number(process.env.PORT || 4173);
const RETENTION_INTERVAL_MS = Number(process.env.RETENTION_INTERVAL_MS || 24 * 60 * 60 * 1000);
const TELEGRAM_BOT_USERNAME = process.env.TELEGRAM_BOT_USERNAME || 'poslaniya_demo_bot';
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const VK_GROUP_ID = process.env.VK_GROUP_ID || 'poslaniya_demo';
const VK_GROUP_TOKEN = process.env.VK_GROUP_TOKEN || '';
const VK_CONFIRMATION_TOKEN = process.env.VK_CONFIRMATION_TOKEN || '';
const WEB_APP_URL = process.env.WEB_APP_URL || `http://localhost:${PORT}`;

// In-memory stores keep this starter runnable without a database. Replace them with
// PostgreSQL + Redis before production; the API shape is intentionally stable.
const users = new Map();
const pendingAuth = new Map();
const authResults = new Map();
const sessions = new Map();
const payments = new Map();
const retentionSettings = new Map();
const publicLinks = new Map();
const messages = new Map();

const randomMessages = [
  'Небольшое напоминание: вы уже справились со многим. Берегите себя сегодня 🤍',
  'Напишите сегодня тому, о ком давно думаете. Иногда одного «привет» достаточно.',
  'Ваши слова важны. Оставьте кому-нибудь тёплое послание — просто так.',
  'Пауза тоже часть пути. Сделайте вдох и найдите пять минут для себя ✦',
  'Кому сегодня можно сказать спасибо? Отправьте это послание, пока мысль рядом.'
];

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon'
};

function json(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Telegram-Init-Data',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS'
  });
  res.end(JSON.stringify(body));
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1024 * 1024) {
        req.destroy();
        reject(new Error('body too large'));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readBody(req) {
  const raw = await readRawBody(req);
  if (!raw.length) return {};
  try { return JSON.parse(raw.toString('utf8')); } catch { throw new Error('invalid json'); }
}

function getUserFromRequest(req) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  return token ? users.get(sessions.get(token)) : null;
}

function verifyTelegramWebAppInitData(initData) {
  if (!TELEGRAM_BOT_TOKEN || !initData) return null;
  const params = new URLSearchParams(initData);
  const receivedHash = params.get('hash');
  const authDate = Number(params.get('auth_date'));
  if (!receivedHash || !authDate || Date.now() / 1000 - authDate > 24 * 60 * 60) return null;
  const dataCheckString = [...params.entries()].filter(([key]) => key !== 'hash').sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => `${key}=${value}`).join('\\n');
  const secret = createHmac('sha256', 'WebAppData').update(TELEGRAM_BOT_TOKEN).digest();
  const expectedHash = createHmac('sha256', secret).update(dataCheckString).digest('hex');
  if (expectedHash !== receivedHash) return null;
  try { return JSON.parse(params.get('user') || '{}'); } catch { return null; }
}

function buildBotUrl(provider, challenge) {
  return provider === 'telegram'
    ? `https://t.me/${TELEGRAM_BOT_USERNAME}?start=auth_${challenge}`
    : `https://vk.me/${VK_GROUP_ID}?ref=auth_${challenge}`;
}

function createAuthChallenge(provider) {
  const challenge = randomUUID().replaceAll('-', '');
  pendingAuth.set(challenge, { provider, createdAt: Date.now() });
  return { challenge, botUrl: buildBotUrl(provider, challenge) };
}

function userIdentities(user) {
  if (!user.identities) {
    user.identities = user.provider ? [{ provider: user.provider, providerUserId: user.providerUserId, username: user.username || null }] : [];
  }
  return user.identities;
}

function identityFor(user, provider) {
  return userIdentities(user).find((identity) => identity.provider === provider);
}

function ensurePublicLink(user, requestedSlug = null) {
  const existing = [...publicLinks.values()].find((link) => link.userId === user.id);
  if (existing && !requestedSlug) return existing;
  const base = (requestedSlug || user.username || user.displayName || `user-${user.id.slice(0, 6)}`).toLowerCase().replace(/[^a-zа-яё0-9_-]+/gi, '-').replace(/^-|-$/g, '') || `user-${user.id.slice(0, 6)}`;
  let slug = base;
  let suffix = 2;
  while (publicLinks.has(slug) && publicLinks.get(slug).userId !== user.id) slug = `${base}-${suffix++}`;
  const link = existing || { id: randomUUID(), userId: user.id, slug, createdAt: new Date().toISOString(), isActive: true };
  link.slug = slug;
  publicLinks.set(slug, link);
  return link;
}

function completeAuth(provider, providerUserId, profile = {}) {
  const providerId = String(providerUserId);
  const existing = [...users.values()].find((candidate) => identityFor(candidate, provider)?.providerUserId === providerId);
  const user = existing || {
    id: randomUUID(),
    displayName: profile.displayName || 'Новый пользователь',
    username: profile.username || null,
    createdAt: new Date().toISOString(),
    vipUntil: null,
    revealCredits: 0,
    identities: []
  };
  const identity = identityFor(user, provider);
  if (identity) Object.assign(identity, { providerUserId: providerId, username: profile.username || identity.username || null });
  else userIdentities(user).push({ provider, providerUserId: providerId, username: profile.username || null });
  Object.assign(user, profile);
  users.set(user.id, user);
  ensurePublicLink(user);
  if (!retentionSettings.has(user.id)) retentionSettings.set(user.id, { dailyEnabled: false });
  const token = randomUUID();
  sessions.set(token, user.id);
  return { user, token };
}

// A small shared fixture makes the Web App and public page demonstrable before
// credentials/database are configured. Production starts with an empty database.
const demoAccount = completeAuth('telegram', 'demo_recipient', { displayName: 'Аня', username: 'anya' }).user;
const demoLink = ensurePublicLink(demoAccount, 'anya');
for (const [text, hoursAgo, mood] of [
  ['Ты очень классно справляешься. Просто хотела, чтобы ты это знала 🤍', 2, 'pink'],
  ['Кажется, ты мне нравишься. Давно хотел сказать.', 8, 'yellow'],
  ['Спасибо, что однажды поддержала меня. Я этого не забыл.', 72, 'lilac']
]) {
  const id = `demo-${messages.size + 1}`;
  messages.set(id, { id, publicLinkId: demoLink.id, body: text, text, source: 'telegram', senderAvailable: false, unread: hoursAgo < 24, saved: false, createdAt: new Date(Date.now() - hoursAgo * 60 * 60 * 1000).toISOString(), time: hoursAgo < 24 ? 'сегодня, 12:44' : hoursAgo < 48 ? 'вчера, 20:18' : '12 марта, 09:02', mood });
}

function telegramAppKeyboard() {
  return { inline_keyboard: [[{ text: 'Открыть мой ящик 💌', web_app: { url: WEB_APP_URL } }]] };
}

function vkAppKeyboard() {
  return { inline: true, buttons: [[{ action: { type: 'open_link', label: 'Открыть мой ящик 💌', link: WEB_APP_URL } }]] };
}

async function sendTelegramMessage(chatId, text, withApp = true) {
  if (!TELEGRAM_BOT_TOKEN || !chatId) return { skipped: true, reason: 'TELEGRAM_BOT_TOKEN is not configured' };
  const payload = { chat_id: chatId, text };
  if (withApp) payload.reply_markup = telegramAppKeyboard();
  const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload)
  });
  return { sent: response.ok, status: response.status };
}

async function sendVkMessage(userId, text, withApp = true) {
  if (!VK_GROUP_TOKEN || !userId) return { skipped: true, reason: 'VK_GROUP_TOKEN is not configured' };
  const payload = { user_id: String(userId), random_id: String(Date.now()), message: text, access_token: VK_GROUP_TOKEN, v: '5.199' };
  if (withApp) payload.keyboard = JSON.stringify(vkAppKeyboard());
  const params = new URLSearchParams(payload);
  const response = await fetch(`https://api.vk.com/method/messages.send?${params}`);
  return { sent: response.ok, status: response.status };
}

async function notifyUser(user, text) {
  const deliveries = [];
  for (const identity of userIdentities(user)) {
    deliveries.push(identity.provider === 'telegram'
      ? sendTelegramMessage(identity.providerUserId, text)
      : sendVkMessage(identity.providerUserId, text));
  }
  return Promise.allSettled(deliveries);
}

async function configureTelegramBot() {
  if (!TELEGRAM_BOT_TOKEN || !WEB_APP_URL.startsWith('https://')) return;
  const headers = { 'Content-Type': 'application/json' };
  const menuPayload = { menu_button: { type: 'web_app', text: 'Мой ящик 💌', web_app: { url: WEB_APP_URL } } };
  const commandsPayload = { commands: [{ command: 'start', description: 'Открыть Послания' }, { command: 'app', description: 'Открыть мой ящик' }, { command: 'settings', description: 'Настройки уведомлений' }] };
  await Promise.all([
    fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setChatMenuButton`, { method: 'POST', headers, body: JSON.stringify(menuPayload) }),
    fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setMyCommands`, { method: 'POST', headers, body: JSON.stringify(commandsPayload) })
  ]).catch((error) => console.error('[telegram] bot setup failed:', error.message));
}

async function runDailyRetentionBroadcast() {
  const targets = [...users.values()].filter((user) => retentionSettings.get(user.id)?.dailyEnabled);
  const text = randomMessages[Math.floor(Math.random() * randomMessages.length)];
  let delivered = 0;
  for (const user of targets) {
    for (const identity of userIdentities(user)) {
      try {
        const result = identity.provider === 'telegram'
          ? await sendTelegramMessage(identity.providerUserId, `💌 Послания на сегодня\n\n${text}`)
          : await sendVkMessage(identity.providerUserId, `💌 Послания на сегодня\n\n${text}`);
        if (result.sent) delivered += 1;
      } catch (error) {
        console.error(`[retention] delivery failed for ${user.id}:`, error.message);
      }
    }
  }
  console.log(`[retention] ${new Date().toISOString()} targets=${targets.length} delivered=${delivered}`);
  return { targets: targets.length, delivered, text };
}

async function handleApi(req, res, url) {
  if (req.method === 'OPTIONS') return json(res, 204, {});
  if (req.method === 'GET' && url.pathname === '/api/v1/plans') {
    return json(res, 200, { plans: [{ id: 'vip', amount: 20, currency: 'RUB', durationDays: 30 }, { id: 'reveal', amount: 7, currency: 'RUB', durationDays: 0 }] });
  }
  if (req.method === 'POST' && /^\/api\/v1\/auth\/(telegram|vk)\/start$/.test(url.pathname)) {
    const provider = url.pathname.split('/')[4];
    const challenge = createAuthChallenge(provider);
    return json(res, 200, { ...challenge, expiresIn: 600 });
  }
  if (req.method === 'GET' && /^\/api\/v1\/auth\/(telegram|vk)\/status$/.test(url.pathname)) {
    const challenge = url.searchParams.get('challenge');
    const pending = challenge && pendingAuth.get(challenge);
    if (challenge && authResults.has(challenge)) return json(res, 200, { status: 'authorized', ...authResults.get(challenge) });
    if (pending && Date.now() - pending.createdAt < 10 * 60 * 1000) return json(res, 200, { status: 'pending', expiresIn: Math.max(0, 600 - Math.floor((Date.now() - pending.createdAt) / 1000)) });
    return json(res, 404, { status: 'expired' });
  }
  if (req.method === 'POST' && /^\/api\/v1\/auth\/(telegram|vk)\/complete$/.test(url.pathname)) {
    const provider = url.pathname.split('/')[4];
    const body = await readBody(req);
    const authorized = body.challenge && authResults.get(body.challenge);
    if (authorized) return json(res, 200, authorized);
    // `demo: true` makes the UI preview useful without bot credentials. Disable this
    // fallback in production with DEMO_MODE=false; real users complete via webhook.
    if (body.demo !== true || process.env.DEMO_MODE === 'false') return json(res, 409, { error: 'waiting_for_bot_confirmation' });
    const result = completeAuth(provider, body.providerUserId || (provider === 'telegram' ? 'demo_recipient' : 'demo_vk_recipient'), { displayName: provider === 'telegram' ? 'Аня' : (body.displayName || 'VK user'), username: provider === 'telegram' ? 'anya' : null });
    return json(res, 200, result);
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/auth/telegram/webapp') {
    const body = await readBody(req);
    const telegramUser = verifyTelegramWebAppInitData(body.initData || req.headers['x-telegram-init-data']);
    if (!telegramUser?.id) return json(res, 401, { error: 'invalid_telegram_webapp_data' });
    const result = completeAuth('telegram', telegramUser.id, { displayName: [telegramUser.first_name, telegramUser.last_name].filter(Boolean).join(' ') || 'Telegram user', username: telegramUser.username || null });
    return json(res, 200, result);
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/me') {
    const user = getUserFromRequest(req);
    return user ? json(res, 200, { user, retention: retentionSettings.get(user.id), link: ensurePublicLink(user) }) : json(res, 401, { error: 'unauthorized' });
  }
  if (req.method === 'GET' && /^\/api\/v1\/inbox$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    const linkIds = new Set([...publicLinks.values()].filter((link) => link.userId === user.id).map((link) => link.id));
    const inbox = [...messages.values()].filter((message) => linkIds.has(message.publicLinkId)).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return json(res, 200, { messages: inbox });
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/links') {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    const body = await readBody(req);
    const link = ensurePublicLink(user, body.slug);
    return json(res, 200, { link: `${new URL(WEB_APP_URL).origin}/${link.slug}`, slug: link.slug });
  }
  const publicLinkMatch = url.pathname.match(/^\/api\/v1\/links\/([^/]+)$/);
  if (req.method === 'GET' && publicLinkMatch) {
    const link = publicLinks.get(decodeURIComponent(publicLinkMatch[1]));
    if (!link || !link.isActive) return json(res, 404, { error: 'link_not_found' });
    const owner = users.get(link.userId);
    return json(res, 200, { slug: link.slug, displayName: owner?.displayName || 'Получатель', welcomeText: 'Оставьте анонимное послание' });
  }
  const publicMessageMatch = url.pathname.match(/^\/api\/v1\/links\/([^/]+)\/messages$/);
  if (req.method === 'POST' && publicMessageMatch) {
    const link = publicLinks.get(decodeURIComponent(publicMessageMatch[1]));
    const body = await readBody(req);
    const cleanText = String(body.text || '').trim();
    if (!link || !link.isActive) return json(res, 200, { message: 'Послание отправлено' });
    if (cleanText.length < 3 || cleanText.length > 500) return json(res, 422, { error: 'message_length' });
    const message = { id: randomUUID(), publicLinkId: link.id, body: cleanText, text: cleanText, source: body.channel || 'web', senderAvailable: false, unread: true, saved: false, createdAt: new Date().toISOString(), time: 'только что', mood: 'pink' };
    messages.set(message.id, message);
    const owner = users.get(link.userId);
    if (owner) await notifyUser(owner, `💌 Новое анонимное послание\n\n«${cleanText}»`);
    return json(res, 200, { message: 'Послание отправлено', id: message.id });
  }
  if (req.method === 'POST' && /^\/api\/v1\/messages\/[^/]+\/(read|save)$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    const messageId = url.pathname.split('/')[5];
    const action = url.pathname.split('/')[6];
    const message = messages.get(messageId);
    const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user?.id);
    if (!ownerLink) return json(res, 404, { error: 'message_not_found' });
    if (action === 'read') message.unread = false;
    if (action === 'save') message.saved = true;
    return json(res, 200, { ok: true, message });
  }
  if (req.method === 'POST' && /^\/api\/v1\/messages\/[^/]+\/reveal$/.test(url.pathname)) {
    const messageId = url.pathname.split('/')[5];
    // A real implementation checks that a successful 7 RUB payment is bound to this
    // message and that the sender used a bot channel. The demo returns the same
    // privacy-safe shape without exposing a fabricated identity.
    return json(res, 200, { messageId, status: 'pending', amount: 7, currency: 'RUB', sender: null, reason: 'sender_consent_or_bot_identity_required' });
  }
  if (req.method === 'PUT' && url.pathname === '/api/v1/retention/settings') {
    const user = getUserFromRequest(req);
    const body = await readBody(req);
    // The preview sends no bearer token, so keep the anonymous demo setting separate.
    const userId = user?.id || 'demo';
    const settings = { dailyEnabled: Boolean(body.dailyEnabled), updatedAt: new Date().toISOString() };
    retentionSettings.set(userId, settings);
    return json(res, 200, settings);
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/retention/broadcast') {
    const result = await runDailyRetentionBroadcast();
    return json(res, 200, result);
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/payments/checkout') {
    const body = await readBody(req);
    const user = getUserFromRequest(req);
    const plan = body.plan === 'reveal' ? 'reveal' : 'vip';
    const amount = plan === 'reveal' ? 7 : 20;
    const invoiceId = `demo-${plan}-${randomUUID()}`;
    payments.set(invoiceId, { plan, amount, userId: user?.id || null, messageId: body.messageId || null, status: 'pending', createdAt: new Date().toISOString() });
    return json(res, 200, { invoiceId, plan, amount, currency: 'RUB', status: 'pending', provider: 'cloudpayments' });
  }
  if (req.method === 'POST' && url.pathname.startsWith('/webhooks/cloudpayments/')) {
    const raw = await readRawBody(req);
    const signature = req.headers['x-content-hmac'];
    if (process.env.CLOUDPAYMENTS_API_SECRET) {
      const expected = createHmac('sha256', process.env.CLOUDPAYMENTS_API_SECRET).update(raw).digest('base64');
      if (!signature || signature !== expected) return json(res, 401, { code: 13, error: 'invalid_signature' });
    }
    let body = {};
    try { body = raw.length ? JSON.parse(raw.toString('utf8')) : {}; } catch { return json(res, 400, { code: 12, error: 'invalid_json' }); }
    const event = url.pathname.split('/').pop();
    const invoiceId = body.InvoiceId || body.invoiceId;
    const payment = invoiceId && payments.get(invoiceId);
    if (payment) {
      payment.status = event === 'pay' ? 'paid' : event === 'fail' ? 'failed' : event;
      const user = payment.userId && users.get(payment.userId);
      if (event === 'pay' && user && payment.plan === 'vip') user.vipUntil = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
      if (event === 'pay' && user && payment.plan === 'reveal') user.revealCredits += 1;
    }
    console.log(`[cloudpayments] event=${event} invoice=${invoiceId || 'unknown'}`);
    return json(res, 200, { code: 0 });
  }
  if (req.method === 'POST' && url.pathname.startsWith('/webhooks/telegram')) {
    const webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET;
    if (webhookSecret && req.headers['x-telegram-bot-api-secret-token'] !== webhookSecret) return json(res, 403, { error: 'invalid_telegram_secret' });
    const body = await readBody(req);
    const message = body.message;
    const text = message?.text || '';
    if (text === '/start' || text === '/app' || text === '/settings') {
      completeAuth('telegram', message.from?.id || message.chat?.id, { displayName: [message.from?.first_name, message.from?.last_name].filter(Boolean).join(' ') || 'Telegram user', username: message.from?.username || null });
      const intro = text === '/settings' ? 'Настройки уведомлений и ежедневных посланий доступны в приложении:' : 'Добро пожаловать в «Послания» 💌\\n\\nЗдесь живут ваши анонимные сообщения. Откройте ящик в приложении:';
      await sendTelegramMessage(message.chat?.id, intro);
      return json(res, 200, { ok: true });
    }
    const match = text.match(/^\/start\s+auth_([a-z0-9]+)$/i);
    if (match && pendingAuth.has(match[1])) {
      const auth = pendingAuth.get(match[1]);
      if (auth.provider === 'telegram' && Date.now() - auth.createdAt < 10 * 60 * 1000) {
        authResults.set(match[1], completeAuth('telegram', message.from?.id || message.chat?.id, { displayName: [message.from?.first_name, message.from?.last_name].filter(Boolean).join(' ') || 'Telegram user', username: message.from?.username || null }));
        pendingAuth.delete(match[1]);
        await sendTelegramMessage(message.chat?.id, 'Готово! Авторизация подтверждена. Вернитесь на сайт 💌');
      }
    }
    return json(res, 200, { ok: true });
  }
  if (req.method === 'POST' && url.pathname.startsWith('/webhooks/vk')) {
    const body = await readBody(req);
    if (body.type === 'confirmation') {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end(VK_CONFIRMATION_TOKEN || 'set VK_CONFIRMATION_TOKEN');
    }
    const object = body.object || {};
    const text = object.text || '';
    if (text === '/start' || text === '/app' || text === '/settings') {
      completeAuth('vk', object.from_id || object.peer_id, { displayName: 'VK user' });
      const intro = text === '/settings' ? 'Настройки уведомлений и ежедневных посланий доступны в приложении:' : 'Добро пожаловать в «Послания» 💌\\n\\nОткройте общий ящик в приложении:';
      await sendVkMessage(object.from_id || object.peer_id, intro);
      return json(res, 200, { ok: true });
    }
    const match = text.match(/^auth_([a-z0-9]+)$/i);
    if (match && pendingAuth.has(match[1])) {
      const auth = pendingAuth.get(match[1]);
      if (auth.provider === 'vk' && Date.now() - auth.createdAt < 10 * 60 * 1000) {
        authResults.set(match[1], completeAuth('vk', object.from_id || object.peer_id, { displayName: 'VK user' }));
        pendingAuth.delete(match[1]);
        await sendVkMessage(object.from_id || object.peer_id, 'Готово! Авторизация подтверждена. Вернитесь на сайт 💌');
      }
    }
    return json(res, 200, { ok: true });
  }
  return json(res, 404, { error: 'not_found' });
}

async function serveStatic(req, res, url) {
  const requested = url.pathname === '/' ? 'index.html' : url.pathname.replace(/^\//, '');
  const rootPath = normalize(ROOT).replace(/[\\/]$/, '');
  const filePath = normalize(join(rootPath, requested));
  if (!(filePath === rootPath || filePath.startsWith(rootPath + sep))) return res.writeHead(403).end('Forbidden');
  try {
    const content = await readFile(filePath);
    res.writeHead(200, { 'Content-Type': mimeTypes[extname(filePath)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(content);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  try {
    if (url.pathname === '/health') return json(res, 200, { ok: true, service: 'poslaniya', now: new Date().toISOString() });
    if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/webhooks/')) return await handleApi(req, res, url);
    return await serveStatic(req, res, url);
  } catch (error) {
    console.error(error);
    return json(res, 500, { error: 'internal_error' });
  }
});

setInterval(runDailyRetentionBroadcast, RETENTION_INTERVAL_MS).unref();
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Послания listening on http://0.0.0.0:${PORT}`);
  console.log(`Telegram Web App: ${WEB_APP_URL}`);
  console.log(`Daily retention scheduler: every ${Math.round(RETENTION_INTERVAL_MS / 1000)}s, only opted-in users`);
  configureTelegramBot();
});
