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

// In-memory stores keep this starter runnable without a database. Replace them with
// PostgreSQL + Redis before production; the API shape is intentionally stable.
const users = new Map();
const pendingAuth = new Map();
const authResults = new Map();
const sessions = new Map();
const payments = new Map();
const retentionSettings = new Map();

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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
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

function completeAuth(provider, providerUserId, profile = {}) {
  const existing = [...users.values()].find((user) => user.provider === provider && user.providerUserId === String(providerUserId));
  const user = existing || {
    id: randomUUID(),
    provider,
    providerUserId: String(providerUserId),
    displayName: profile.displayName || 'Новый пользователь',
    username: profile.username || null,
    createdAt: new Date().toISOString(),
    vipUntil: null,
    revealCredits: 0
  };
  Object.assign(user, profile);
  users.set(user.id, user);
  if (!retentionSettings.has(user.id)) retentionSettings.set(user.id, { dailyEnabled: false });
  const token = randomUUID();
  sessions.set(token, user.id);
  return { user, token };
}

async function sendTelegramMessage(chatId, text) {
  if (!TELEGRAM_BOT_TOKEN || !chatId) return { skipped: true, reason: 'TELEGRAM_BOT_TOKEN is not configured' };
  const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text })
  });
  return { sent: response.ok, status: response.status };
}

async function sendVkMessage(userId, text) {
  if (!VK_GROUP_TOKEN || !userId) return { skipped: true, reason: 'VK_GROUP_TOKEN is not configured' };
  const params = new URLSearchParams({ user_id: String(userId), random_id: String(Date.now()), message: text, access_token: VK_GROUP_TOKEN, v: '5.199' });
  const response = await fetch(`https://api.vk.com/method/messages.send?${params}`);
  return { sent: response.ok, status: response.status };
}

async function runDailyRetentionBroadcast() {
  const targets = [...users.values()].filter((user) => retentionSettings.get(user.id)?.dailyEnabled);
  const text = randomMessages[Math.floor(Math.random() * randomMessages.length)];
  let delivered = 0;
  for (const user of targets) {
    try {
      const result = user.provider === 'telegram'
        ? await sendTelegramMessage(user.providerUserId, `💌 Послания на сегодня\n\n${text}`)
        : await sendVkMessage(user.providerUserId, `💌 Послания на сегодня\n\n${text}`);
      if (result.sent) delivered += 1;
    } catch (error) {
      console.error(`[retention] delivery failed for ${user.id}:`, error.message);
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
    const result = completeAuth(provider, body.providerUserId || `demo_${provider}`, { displayName: body.displayName || `Demo ${provider}` });
    return json(res, 200, result);
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/me') {
    const user = getUserFromRequest(req);
    return user ? json(res, 200, { user, retention: retentionSettings.get(user.id) }) : json(res, 401, { error: 'unauthorized' });
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
  console.log(`Daily retention scheduler: every ${Math.round(RETENTION_INTERVAL_MS / 1000)}s, only opted-in users`);
});
