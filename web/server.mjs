import dotenv from 'dotenv';
import { existsSync } from 'node:fs';
import { createServer } from 'node:http';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createTelegramBot } from './telegram-bot.mjs';
import { createTelegramUserbot } from '../userbot/service.mjs';
import { createSqliteStore } from './sqlite-store.mjs';

const WEB_ROOT = fileURLToPath(new URL('.', import.meta.url));
const PROJECT_ROOT = resolve(WEB_ROOT, '..');
const configuredEnvFile = process.env.ENV_FILE?.trim();
const envCandidates = configuredEnvFile
  ? [resolveProjectPath(configuredEnvFile)]
  // Load web/.env first and the project-root .env second so a root file wins,
  // while deployments that keep their settings next to server.mjs still work.
  : [join(WEB_ROOT, '.env'), join(PROJECT_ROOT, '.env')];
const envFiles = envCandidates.filter((candidate, index, list) => existsSync(candidate) && list.indexOf(candidate) === index);
for (const envFile of envFiles) {
  const dotenvResult = dotenv.config({ path: envFile, override: false });
  if (dotenvResult?.error) {
    console.warn(`[config] failed to load ${envFile}: ${dotenvResult.error.message}`);
  } else {
    // A second .env file should not erase a real value with an empty template
    // line. Non-empty values from the later/root file still take precedence.
    for (const [name, value] of Object.entries(dotenvResult.parsed || {})) {
      if (String(value).trim()) process.env[name] = String(value).trim();
    }
    console.log(`[config] loaded ${envFile}`);
  }
}
if (!envFiles.length) console.warn(`[config] .env not found; using process environment and safe defaults`);

function env(name, fallback = '') {
  return process.env[name]?.trim() || fallback;
}

function resolveProjectPath(value) {
  return value.startsWith('/') ? value : join(PROJECT_ROOT, value);
}

// Values in .env always win. Defaults keep an older, partial .env file
// bootable; secrets never have a source-code fallback.
const PORT = Number(env('PORT', '4173'));
const RETENTION_INTERVAL_MS = Number(env('RETENTION_INTERVAL_MS', '86400000'));
const PAYMENT_RECONCILE_INTERVAL_MS = Number(env('PAYMENT_RECONCILE_INTERVAL_MS', '15000'));
const DEMO_MODE = env('DEMO_MODE', 'true') === 'true';
const TELEGRAM_MODE = env('TELEGRAM_MODE', 'polling');
let TELEGRAM_BOT_USERNAME = env('TELEGRAM_BOT_USERNAME', '');
const LEGACY_TELEGRAM_BOT_USERNAMES = new Set(['poslaniya_robot']);
const TELEGRAM_BOT_TOKEN = env('TELEGRAM_BOT_TOKEN');
let telegramBotUserId = null;
let telegramBotIdentityPromise = null;
const TELEGRAM_ADMIN_IDS = env('TELEGRAM_ADMIN_IDS');
const TELEGRAM_WEBHOOK_SECRET = env('TELEGRAM_WEBHOOK_SECRET');
const TELEGRAM_GROUPS_ENABLED = env('TELEGRAM_GROUPS_ENABLED', 'true') === 'true';
const TELEGRAM_GROUP_CHAT_IDS = env('TELEGRAM_GROUP_CHAT_IDS').split(',').map((id) => id.trim()).filter(Boolean);
const TELEGRAM_STICKER_ID = env('TELEGRAM_STICKER_ID');
const TELEGRAM_RECEIVED_STICKER_ID = env('TELEGRAM_RECEIVED_STICKER_ID', TELEGRAM_STICKER_ID);
const TELEGRAM_SENT_STICKER_ID = env('TELEGRAM_SENT_STICKER_ID', TELEGRAM_STICKER_ID);
const TELEGRAM_SBP_ADMIN_TEXT = env('TELEGRAM_SBP_ADMIN_TEXT');
const TELEGRAM_USERBOT_ENABLED = env('TELEGRAM_USERBOT_ENABLED', 'false') === 'true';
const TELEGRAM_USERBOT_API_ID = Number(env('TELEGRAM_USERBOT_API_ID', '0'));
const TELEGRAM_USERBOT_API_HASH = env('TELEGRAM_USERBOT_API_HASH');
const TELEGRAM_USERBOT_SESSION = env('TELEGRAM_USERBOT_SESSION');
const TELEGRAM_USERBOT_GIFT_PROMO = env('TELEGRAM_USERBOT_GIFT_PROMO');

function telegramUserbotGiftPromo() {
  const botUsername = TELEGRAM_BOT_USERNAME || 'poslaniya_robot';
  return TELEGRAM_USERBOT_GIFT_PROMO || `Подарок отправлен через Послания 💌 t.me/${botUsername}`;
}
const MYSTARS_API_KEY = env('MYSTARS_API_KEY');
const MYSTARS_API_URL = env('MYSTARS_API_URL', 'https://api.mystars.tg');
const MYSTARS_PAYMENT_CURRENCY = env('MYSTARS_PAYMENT_CURRENCY', 'ton');
const MYSTARS_BALANCE_MARKUP_PERCENT = Number(env('MYSTARS_BALANCE_MARKUP_PERCENT', '10'));
const MYSTARS_BALANCE_STARS_RUB_PER_UNIT = Number(env('MYSTARS_BALANCE_STARS_RUB_PER_UNIT', '0'));
const MYSTARS_BALANCE_PREMIUM_3_RUB = Number(env('MYSTARS_BALANCE_PREMIUM_3_RUB', '0'));
const MYSTARS_BALANCE_PREMIUM_6_RUB = Number(env('MYSTARS_BALANCE_PREMIUM_6_RUB', '0'));
const MYSTARS_BALANCE_PREMIUM_12_RUB = Number(env('MYSTARS_BALANCE_PREMIUM_12_RUB', '0'));
const YUMONEY_RECEIVER = env('YUMONEY_RECEIVER');
const YUMONEY_PAYMENT_URL = env('YUMONEY_PAYMENT_URL');
const YUMONEY_TOKEN = env('YUMONEY_TOKEN');
const YUMONEY_API_URL = env('YUMONEY_API_URL', 'https://yoomoney.ru/api');
const CRYPTOBOT_API_TOKEN = env('CRYPTOBOT_API_TOKEN');
const CRYPTOBOT_API_URL = env('CRYPTOBOT_API_URL', 'https://pay.crypt.bot/api');
const XROCKET_API_TOKEN = env('XROCKET_API_TOKEN');
const XROCKET_TESTNET = env('XROCKET_TESTNET', 'false').toLowerCase() === 'true';
const XROCKET_API_URL = env('XROCKET_API_URL', XROCKET_TESTNET ? 'https://pay.api.testnet.xrocket.exchange' : 'https://pay.api.xrocket.exchange');
const XROCKET_WEBHOOK_SECRET = env('XROCKET_WEBHOOK_SECRET');
// The public xRocket asset list does not contain RUB on every account. Keep the
// old RUB setting compatible by converting the RUB checkout amount to USDT (or
// another configured fallback asset) before creating the invoice.
const XROCKET_PRICE_CURRENCY = env('XROCKET_PRICE_CURRENCY', 'RUB').toUpperCase();
const XROCKET_FALLBACK_PRICE_CURRENCY = env('XROCKET_FALLBACK_PRICE_CURRENCY', 'USDT').toUpperCase();
const XROCKET_RUB_ASSET_RATE = Number(env('XROCKET_RUB_ASSET_RATE', '0'));
const XROCKET_PAYOUT_CURRENCY = env('XROCKET_PAYOUT_CURRENCY');
const TELEGRAM_SBP_DETAILS = env('SBP_PAYMENT_DETAILS', env('SBP_DETAILS', env('SBP_REQUISITES', env('TELEGRAM_SBP_ADMIN_TEXT'))));
const SBP_PAYMENT_DETAILS = TELEGRAM_SBP_DETAILS;

function sbpDetailsConfigured() {
  return Boolean(SBP_PAYMENT_DETAILS && !/нет\s+реквизитов|не\s+настроен/i.test(SBP_PAYMENT_DETAILS));
}

function sbpInstructions(payment = null) {
  const stored = payment?.instructions || '';
  return SBP_PAYMENT_DETAILS || (stored && !/нет\s+реквизитов|не\s+настроен/i.test(stored) ? stored : '') || 'Реквизиты СБП временно не настроены. Выберите другой способ оплаты.';
}

function sbpBotUrl(payment) {
  return TELEGRAM_BOT_USERNAME && payment?.id
    ? `https://t.me/${TELEGRAM_BOT_USERNAME}?start=sbp_${encodeURIComponent(payment.id)}`
    : '';
}
const VK_GROUP_ID = env('VK_GROUP_ID', 'poslaniya_demo');
const VK_GROUP_TOKEN = env('VK_GROUP_TOKEN');
const VK_API_VERSION = env('VK_API_VERSION', '5.199');
const VK_CONFIRMATION_TOKEN = env('VK_CONFIRMATION_TOKEN');
const CLOUDPAYMENTS_API_SECRET = env('CLOUDPAYMENTS_API_SECRET');
const WEB_APP_URL = env('WEB_APP_URL', 'https://app.goago.club');
const DEFAULT_RECIPIENT_SLUG = env('DEFAULT_RECIPIENT_SLUG', 'anya');
const DEMO_RECIPIENT_ID = env('DEMO_RECIPIENT_ID', 'demo_recipient');
const DEMO_RECIPIENT_NAME = env('DEMO_RECIPIENT_NAME', 'Аня');
const DATA_FILE = resolveProjectPath(env('DATA_FILE', 'data/store.json'));
const DB_DRIVER = env('DB_DRIVER', 'sqlite');
const SQLITE_FILE = resolveProjectPath(env('SQLITE_FILE', 'data/dev.sqlite'));
const DAILY_RU_FILE = resolveProjectPath(env('DAILY_RU_FILE', 'content/daily/ru.txt'));
const DAILY_EN_FILE = resolveProjectPath(env('DAILY_EN_FILE', 'content/daily/en.txt'));
const USE_START_BANNER = env('TELEGRAM_USE_START_BANNER', 'true') === 'true';
const START_BANNER_FILE = resolveProjectPath(env('TELEGRAM_START_BANNER_FILE', 'web/assets/start-banner.png'));
const CORS_ORIGIN = env('CORS_ORIGIN', WEB_APP_URL);
const devStore = DB_DRIVER === 'json' ? null : await createSqliteStore(SQLITE_FILE);

// In-memory stores keep this starter runnable without a database. Replace them with
// PostgreSQL + Redis before production; the API shape is intentionally stable.
const users = new Map();
const pendingAuth = new Map();
const authResults = new Map();
const webAuthTokens = new Map();
const sessions = new Map();
const payments = new Map();
const retentionSettings = new Map();
const blockedSenders = new Map();
const publicLinks = new Map();
const messages = new Map();
const mystarsOrders = new Map();
let persistenceTimer = null;

function currentSnapshot() {
  return {
    users: [...users.values()],
    publicLinks: [...publicLinks.values()],
    messages: [...messages.values()],
    payments: [...payments.entries()],
    retentionSettings: [...retentionSettings.entries()],
    blockedSenders: [...blockedSenders.entries()].map(([userId, fingerprints]) => [userId, [...fingerprints]]),
    mystarsOrders: [...mystarsOrders.entries()]
  };
}

async function persistState() {
  try {
    const snapshot = currentSnapshot();
    if (devStore) devStore.save(snapshot);
    else {
      await mkdir(join(PROJECT_ROOT, 'data'), { recursive: true });
      await writeFile(DATA_FILE, JSON.stringify(snapshot, null, 2));
    }
  } catch (error) {
    console.error('[store] persist failed:', error.message);
  }
}

function schedulePersist() {
  clearTimeout(persistenceTimer);
  persistenceTimer = setTimeout(() => persistState(), 100);
}

async function loadState() {
  try {
    let snapshot = devStore?.load() || null;
    if (!devStore) {
      const raw = await readFile(DATA_FILE, 'utf8');
      snapshot = JSON.parse(raw);
    }
    if (!snapshot) return schedulePersist();
    if (Array.isArray(snapshot.users)) { users.clear(); snapshot.users.forEach((user) => users.set(user.id, user)); }
    if (Array.isArray(snapshot.publicLinks)) { publicLinks.clear(); snapshot.publicLinks.forEach((link) => publicLinks.set(link.slug, link)); }
    if (Array.isArray(snapshot.messages)) { messages.clear(); snapshot.messages.forEach((message) => messages.set(message.id, message)); }
    if (Array.isArray(snapshot.payments)) { payments.clear(); snapshot.payments.forEach(([id, payment]) => payments.set(id, payment)); }
    if (Array.isArray(snapshot.retentionSettings)) { retentionSettings.clear(); snapshot.retentionSettings.forEach(([id, settings]) => retentionSettings.set(id, settings)); }
    if (Array.isArray(snapshot.blockedSenders)) { blockedSenders.clear(); snapshot.blockedSenders.forEach(([id, fingerprints]) => blockedSenders.set(id, new Set(fingerprints || []))); }
    if (Array.isArray(snapshot.mystarsOrders)) { mystarsOrders.clear(); snapshot.mystarsOrders.forEach(([id, order]) => mystarsOrders.set(id, order)); }
    for (const user of users.values()) {
      ensurePublicLink(user);
      ensureWebSession(user);
    }
    purgeDemoDataIfDisabled();
    console.log(`[store] loaded ${users.size} users, ${messages.size} messages via ${devStore ? 'SQLite' : 'JSON'}`);
  } catch (error) {
    if (error.code !== 'ENOENT') console.error('[store] load failed:', error.message);
    schedulePersist();
  }
}

function purgeDemoDataIfDisabled() {
  if (DEMO_MODE) return;
  const demoUserIds = new Set([...users.values()]
    .filter((user) => user.id === DEMO_RECIPIENT_ID || userIdentities(user).some((identity) => identity.provider === 'telegram' && identity.providerUserId === DEMO_RECIPIENT_ID))
    .map((user) => user.id));
  const demoLinkIds = new Set([...publicLinks.values()].filter((link) => demoUserIds.has(link.userId)).map((link) => link.id));
  const demoLinkSlugs = new Set([...publicLinks.values()].filter((link) => demoUserIds.has(link.userId)).map((link) => link.slug));
  for (const slug of demoLinkSlugs) publicLinks.delete(slug);
  for (const [id, message] of messages) if (demoLinkIds.has(message.publicLinkId) || String(id).startsWith('demo-') || demoUserIds.has(message.userId)) messages.delete(id);
  for (const userId of demoUserIds) {
    users.delete(userId);
    retentionSettings.delete(userId);
  }
  schedulePersist();
  console.warn(`[store] removed ${demoUserIds.size} demo account(s) because DEMO_MODE=false`);
}

const fallbackDailyMessages = {
  ru: ['Небольшое напоминание: вы уже справились со многим. Берегите себя сегодня 🤍'],
  en: ['A little reminder: you have already made it through so much. Be kind to yourself today 🤍']
};
let dailyMessages = { ru: [], en: [] };

async function loadDailyMessages() {
  const files = { ru: DAILY_RU_FILE, en: DAILY_EN_FILE };
  for (const [language, filePath] of Object.entries(files)) {
    try {
      const content = await readFile(filePath, 'utf8');
      const messagesFromFile = content.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
      dailyMessages[language] = messagesFromFile.length ? messagesFromFile : fallbackDailyMessages[language];
      console.log(`[daily] loaded ${dailyMessages[language].length} ${language} messages from ${filePath}`);
    } catch (error) {
      dailyMessages[language] = fallbackDailyMessages[language];
      console.warn(`[daily] could not read ${filePath}: ${error.message}`);
    }
  }
}

function randomMessage(language = 'ru') {
  const messagesForLanguage = dailyMessages[language === 'en' ? 'en' : 'ru'];
  return messagesForLanguage[Math.floor(Math.random() * messagesForLanguage.length)] || fallbackDailyMessages.ru[0];
}

function dailyAnonymousText(language, text) {
  return language === 'en'
    ? `💌 <b>Anonymous message of the day</b>\n\n${escapeTelegramHtml(text)}\n\n<b>Sender:</b> Anonymous`
    : `💌 <b>Анонимное послание дня</b>\n\n${escapeTelegramHtml(text)}\n\n<b>Отправитель:</b> Аноним`;
}

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
    'Access-Control-Allow-Origin': CORS_ORIGIN,
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
  if (!token) return null;
  const userId = sessions.get(token);
  if (userId) return users.get(userId) || null;
  const user = [...users.values()].find((candidate) => candidate.webSessionToken === token);
  if (user) sessions.set(token, user.id);
  return user || null;
}

function senderFingerprint(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  const address = forwarded || req.socket.remoteAddress || 'unknown';
  const agent = String(req.headers['user-agent'] || 'unknown');
  return createHash('sha256').update(`${address}|${agent}`).digest('hex');
}

function isSenderBlocked(userId, fingerprint) {
  return Boolean(fingerprint && blockedSenders.get(userId)?.has(fingerprint));
}

function blockSender(userId, fingerprint) {
  if (!fingerprint) return;
  if (!blockedSenders.has(userId)) blockedSenders.set(userId, new Set());
  blockedSenders.get(userId).add(fingerprint);
  schedulePersist();
}

function verifyTelegramWebAppInitData(initData) {
  if (!TELEGRAM_BOT_TOKEN || !initData) return null;
  const params = new URLSearchParams(initData);
  const receivedHash = params.get('hash');
  const authDate = Number(params.get('auth_date'));
  if (!receivedHash || !authDate || Date.now() / 1000 - authDate > 24 * 60 * 60) return null;
  const dataCheckString = [...params.entries()].filter(([key]) => key !== 'hash').sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => `${key}=${value}`).join('\n');
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
  const identities = userIdentities(user);
  return identities.find((identity) => identity.provider === provider && !isTelegramBotIdentity(identity));
}

function slugify(value, fallback) {
  return String(value || '').toLowerCase().replace(/[^a-zа-яё0-9_-]+/gi, '-').replace(/^-|-$/g, '') || fallback;
}

function isShortReferralSlug(value) {
  return /^[a-z0-9][a-z0-9_-]{0,31}$/i.test(String(value || '')) && encodeURIComponent(`ref_${value}`).length <= 64;
}

function compactReferralSlug(value, fallback) {
  const candidate = slugify(value, '');
  return isShortReferralSlug(candidate) ? candidate : fallback;
}

function demoSlug() {
  const fallback = `demo-${DEMO_RECIPIENT_ID.replace(/[^a-z0-9]/gi, '').slice(0, 8).toLowerCase() || 'user'}`;
  const configured = compactReferralSlug(DEFAULT_RECIPIENT_SLUG, fallback);
  return isTelegramBotUsername(configured) ? fallback : configured;
}

function ensurePublicLink(user, requestedSlug = null) {
  const existing = [...publicLinks.values()].find((link) => link.userId === user.id && !link.isAlias);
  const identityUsername = userIdentities(user).find((identity) => identity.username && !isTelegramBotUsername(identity.username))?.username;
  const username = user.username && !isTelegramBotUsername(user.username) ? user.username : identityUsername;
  const fallback = `u-${user.id.replace(/[^a-z0-9]/gi, '').slice(0, 10).toLowerCase() || 'user'}`;
  const preferred = user.id === DEMO_RECIPIENT_ID ? demoSlug() : compactReferralSlug(username, fallback);
  const requested = requestedSlug ? compactReferralSlug(requestedSlug, preferred) : null;
  const hasRealUsername = Boolean(username && !isTelegramBotUsername(username));
  const reservedOrLong = existing && (!isShortReferralSlug(existing.slug) || isTelegramBotUsername(existing.slug) || existing.slug === DEFAULT_RECIPIENT_SLUG);
  const fallbackSlugNeedsRepair = existing && hasRealUsername && /^u-[a-z0-9]+$/i.test(existing.slug) && existing.slug !== preferred;
  const needsRepair = existing && !requestedSlug && (reservedOrLong || fallbackSlugNeedsRepair) && existing.slug !== preferred;
  if (existing && !requestedSlug && !needsRepair) return existing;

  const base = requested || (needsRepair ? preferred : existing?.slug || preferred);
  let slug = base;
  let suffix = 2;
  while (publicLinks.has(slug) && publicLinks.get(slug).userId !== user.id) slug = `${base}-${suffix++}`;
  const link = existing || { id: randomUUID(), userId: user.id, slug, createdAt: new Date().toISOString(), isActive: true };
  if (existing?.slug && existing.slug !== slug) {
    publicLinks.set(existing.slug, { ...existing, isAlias: true, canonicalSlug: slug });
  }
  link.slug = slug;
  delete link.isAlias;
  delete link.canonicalSlug;
  publicLinks.set(slug, link);
  schedulePersist();
  return link;
}

function resolvePublicLink(slug) {
  const normalizedSlug = String(slug || '').trim().toLowerCase();
  if (!normalizedSlug) return null;
  // A verified Telegram identity wins over a same-named legacy link. This is
  // important for direct @username recipient selection after old migrations.
  const owner = [...users.values()].find((candidate) => {
    if (normalizeTelegramUsername(candidate.username) === normalizedSlug && !isTelegramBotUsername(candidate.username)) return true;
    return userIdentities(candidate).some((identity) => identity.provider === 'telegram'
      && normalizeTelegramUsername(identity.username) === normalizedSlug
      && !isTelegramBotIdentity(identity));
  });
  if (owner) return ensurePublicLink(owner, normalizedSlug);
  return publicLinks.get(normalizedSlug) || null;
}

function ensureTelegramRecipientLink(username) {
  const normalizedUsername = normalizeTelegramUsername(username);
  if (!/^[a-z0-9_]{5,32}$/i.test(normalizedUsername) || isTelegramBotUsername(normalizedUsername)) return null;
  const existing = resolvePublicLink(normalizedUsername);
  if (existing) return existing;
  const user = {
    id: randomUUID(),
    displayName: `@${normalizedUsername}`,
    username: normalizedUsername,
    createdAt: new Date().toISOString(),
    vipUntil: null,
    revealCredits: 0,
    balanceRub: 0,
    language: 'ru',
    dailyEnabled: true,
    telegramUserbotOnly: true,
    identities: [{ provider: 'telegram', providerUserId: null, username: normalizedUsername, userbotOnly: true }]
  };
  users.set(user.id, user);
  retentionSettings.set(user.id, { dailyEnabled: true });
  const link = ensurePublicLink(user, normalizedUsername);
  schedulePersist();
  return link;
}

function ensureWebSession(user) {
  if (!user.webSessionToken) user.webSessionToken = randomUUID();
  sessions.set(user.webSessionToken, user.id);
  return user.webSessionToken;
}

function userForClient(user) {
  if (!user) return null;
  const { webSessionToken, ...safeUser } = user;
  return safeUser;
}

function completeAuth(provider, providerUserId, profile = {}) {
  const providerId = String(providerUserId);
  const profileUsername = normalizeTelegramUsername(profile.username);
  // Match the raw provider ID before applying the bot-identity filter. This repairs
  // legacy records whose real user identity still carried the bot username.
  const existingById = [...users.values()].find((candidate) => userIdentities(candidate).some((identity) => identity.provider === provider && String(identity.providerUserId) === providerId));
  const existingByUsername = provider === 'telegram' && profileUsername
    ? [...users.values()].find((candidate) => {
      const identities = userIdentities(candidate).filter((identity) => identity.provider === 'telegram');
      const hasDifferentVerifiedIdentity = identities.some((identity) => !isTelegramBotIdentity(identity)
        && /^\d+$/.test(String(identity.providerUserId || ''))
        && String(identity.providerUserId) !== providerId);
      if (hasDifferentVerifiedIdentity) return false;
      return normalizeTelegramUsername(candidate.username) === profileUsername
        || identities.some((identity) => normalizeTelegramUsername(identity.username) === profileUsername);
    })
    : null;
  const existing = existingById || existingByUsername;
  const user = existing || {
    id: randomUUID(),
    displayName: profile.displayName || 'Новый пользователь',
    username: profile.username || null,
    createdAt: new Date().toISOString(),
    vipUntil: null,
    revealCredits: 0,
    balanceRub: 0,
    language: profile.language || 'ru',
    dailyEnabled: true,
    identities: []
  };
  const identity = userIdentities(user).find((candidate) => candidate.provider === provider && String(candidate.providerUserId) === providerId) || identityFor(user, provider);
  if (identity) Object.assign(identity, { providerUserId: providerId, username: profile.username || identity.username || null });
  else userIdentities(user).push({ provider, providerUserId: providerId, username: profile.username || null });
  if (profile.displayName) user.displayName = profile.displayName;
  if (profile.username) user.username = profile.username;
  if (profile.language) user.language = profile.language;
  if (profile.photoUrl) user.photoUrl = profile.photoUrl;
  if (!Number.isFinite(Number(user.balanceRub))) user.balanceRub = 0;
  users.set(user.id, user);
  ensurePublicLink(user);
  if (!retentionSettings.has(user.id)) retentionSettings.set(user.id, { dailyEnabled: user.dailyEnabled !== false });
  const token = ensureWebSession(user);
  schedulePersist();
  return { user, token };
}

function issueWebAuthToken(user) {
  const token = randomUUID();
  webAuthTokens.set(token, { userId: user.id, expiresAt: Date.now() + 10 * 60 * 1000 });
  return token;
}

function consumeWebAuthToken(token) {
  const record = token && webAuthTokens.get(String(token));
  if (!record || record.expiresAt <= Date.now()) {
    if (token) webAuthTokens.delete(String(token));
    return null;
  }
  webAuthTokens.delete(String(token));
  const user = users.get(record.userId);
  if (!user) return null;
  return { user: userForClient(user), token: ensureWebSession(user) };
}

// Demo data is seeded after persisted state has loaded, and only in DEMO_MODE.
// Production must never create the demo account or its messages.
function seedDemoData() {
  if (!DEMO_MODE) return;
  const demoAccount = [...users.values()].find((user) => user.id === DEMO_RECIPIENT_ID || userIdentities(user).some((identity) => identity.provider === 'telegram' && identity.providerUserId === DEMO_RECIPIENT_ID))
    || completeAuth('telegram', DEMO_RECIPIENT_ID, { displayName: DEMO_RECIPIENT_NAME, username: demoSlug() }).user;
  const demoLink = ensurePublicLink(demoAccount, demoSlug());
  if ([...messages.keys()].some((id) => String(id).startsWith('demo-'))) return;
  for (const [text, hoursAgo, mood] of [
    ['Ты очень классно справляешься. Просто хотела, чтобы ты это знала 🤍', 2, 'pink'],
    ['Кажется, ты мне нравишься. Давно хотел сказать.', 8, 'yellow'],
    ['Спасибо, что однажды поддержала меня. Я этого не забыл.', 72, 'lilac']
  ]) {
    const id = `demo-${messages.size + 1}`;
    messages.set(id, { id, publicLinkId: demoLink.id, body: text, text, source: 'telegram', senderAvailable: false, unread: hoursAgo < 24, saved: false, createdAt: new Date(Date.now() - hoursAgo * 60 * 60 * 1000).toISOString(), time: hoursAgo < 24 ? 'сегодня, 12:44' : hoursAgo < 48 ? 'вчера, 20:18' : '12 марта, 09:02', mood });
  }
  schedulePersist();
}

function buildWebAppUrl(query = {}) {
  const url = new URL(WEB_APP_URL);
  url.searchParams.set('app', '1');
  Object.entries(query).forEach(([key, value]) => url.searchParams.set(key, value));
  return url.toString();
}

function telegramAppKeyboard() {
  return { inline_keyboard: [[{ text: 'Открыть мой ящик 💌', web_app: { url: buildWebAppUrl() } }]] };
}

function vkAppKeyboard(appUrl = buildWebAppUrl(), label = 'Открыть мой ящик 💌') {
  return { inline: true, buttons: [[{ action: { type: 'open_link', label, link: appUrl } }]] };
}

async function telegramRequest(method, body = {}, timeoutMs = 15000) {
  if (!TELEGRAM_BOT_TOKEN) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/${method}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: controller.signal });
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.description || `Telegram API ${response.status}`);
    return result.result;
  } finally {
    clearTimeout(timeout);
  }
}

async function resolveTelegramBotIdentity() {
  if (!TELEGRAM_BOT_TOKEN || telegramBotUserId) return telegramBotUserId;
  if (!telegramBotIdentityPromise) {
    telegramBotIdentityPromise = telegramRequest('getMe').then((me) => {
      telegramBotUserId = me?.id ? String(me.id) : null;
      if (me?.username) TELEGRAM_BOT_USERNAME = String(me.username).replace(/^@+/, '');
      return telegramBotUserId;
    }).catch((error) => {
      telegramBotIdentityPromise = null;
      console.error('[telegram] getMe failed:', error.message);
      return null;
    });
  }
  return telegramBotIdentityPromise;
}

async function sendTelegramMessage(chatId, text, options = true) {
  if (telegramBotUserId && String(chatId) === String(telegramBotUserId)) return { skipped: true, reason: 'bot_cannot_message_itself' };
  if (!TELEGRAM_BOT_TOKEN || !chatId) return { skipped: true, reason: 'TELEGRAM_BOT_TOKEN is not configured' };
  const payload = { chat_id: chatId, text, parse_mode: 'HTML' };
  if (options === true) payload.reply_markup = telegramAppKeyboard();
  if (options?.reply_markup) payload.reply_markup = options.reply_markup;
  try {
    await telegramRequest('sendMessage', payload);
    return { sent: true };
  } catch (error) {
    console.error('[telegram] sendMessage failed:', error.message);
    return { sent: false, error: error.message };
  }
}

async function sendTelegramMedia(chatId, media, caption = '', options = true) {
  if (telegramBotUserId && String(chatId) === String(telegramBotUserId)) return { skipped: true, reason: 'bot_cannot_message_itself' };
  if (!TELEGRAM_BOT_TOKEN || !chatId || !media?.fileId) return { skipped: true, reason: 'telegram media is not configured' };
  const methods = { photo: ['sendPhoto', 'photo'], video: ['sendVideo', 'video'], voice: ['sendVoice', 'voice'], video_note: ['sendVideoNote', 'video_note'], sticker: ['sendSticker', 'sticker'], document: ['sendDocument', 'document'], audio: ['sendAudio', 'audio'], animation: ['sendAnimation', 'animation'] };
  const [method, field] = methods[media.kind] || methods.document;
  const payload = { chat_id: chatId, [field]: media.fileId };
  if (caption && !['sticker', 'video_note'].includes(media.kind)) {
    payload.caption = caption;
    payload.parse_mode = 'HTML';
  }
  if (options?.reply_markup) payload.reply_markup = options.reply_markup;
  try {
    await telegramRequest(method, payload);
    return { sent: true, media: true };
  } catch (error) {
    console.error(`[telegram] ${method} failed:`, error.message);
    return { sent: false, error: error.message };
  }
}

async function sendTelegramSticker(chatId, stickerId = TELEGRAM_STICKER_ID, options = false) {
  if (telegramBotUserId && String(chatId) === String(telegramBotUserId)) return { skipped: true, reason: 'bot_cannot_message_itself' };
  if (!TELEGRAM_BOT_TOKEN || !chatId || !stickerId) return { skipped: true, reason: 'sticker is not configured' };
  const payload = { chat_id: chatId, sticker: stickerId };
  if (options?.reply_markup) payload.reply_markup = options.reply_markup;
  try {
    await telegramRequest('sendSticker', payload);
    return { sent: true };
  } catch (error) {
    console.error('[telegram] sendSticker failed:', error.message);
    return { sent: false, error: error.message };
  }
}

async function sendTelegramPhoto(chatId, caption, options = true) {
  if (telegramBotUserId && String(chatId) === String(telegramBotUserId)) return { skipped: true, reason: 'bot_cannot_message_itself' };
  // Upload the local file instead of giving Telegram a URL. This works even when
  // the production site has a CDN, auth, redirect, or an unavailable /assets URL.
  if (!USE_START_BANNER || !TELEGRAM_BOT_TOKEN || !chatId) return sendTelegramMessage(chatId, caption, options);
  try {
    const image = await readFile(START_BANNER_FILE);
    const form = new FormData();
    form.append('chat_id', String(chatId));
    form.append('photo', new Blob([image], { type: 'image/png' }), 'start-banner.png');
    form.append('caption', caption);
    form.append('parse_mode', 'HTML');
    const replyMarkup = options === true ? telegramAppKeyboard() : options?.reply_markup;
    if (replyMarkup) form.append('reply_markup', JSON.stringify(replyMarkup));
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    try {
      const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto`, { method: 'POST', body: form, signal: controller.signal });
      const result = await response.json();
      if (!response.ok || !result.ok) throw new Error(result.description || `Telegram API ${response.status}`);
      return { sent: true };
    } finally {
      clearTimeout(timeout);
    }
  } catch (error) {
    console.error('[telegram] sendPhoto failed, falling back to text:', error.message);
    return sendTelegramMessage(chatId, caption, options);
  }
}

async function sendVkMessage(userId, text, withApp = true, appUrl = buildWebAppUrl(), appLabel = 'Открыть мой ящик 💌') {
  if (!VK_GROUP_TOKEN || !userId) return { skipped: true, reason: 'VK_GROUP_TOKEN is not configured' };
  const payload = { user_id: String(userId), random_id: String(Date.now()), message: text, access_token: VK_GROUP_TOKEN, v: VK_API_VERSION };
  if (withApp) payload.keyboard = JSON.stringify(vkAppKeyboard(appUrl, appLabel));
  const params = new URLSearchParams(payload);
  const response = await fetch(`https://api.vk.com/method/messages.send?${params}`);
  return { sent: response.ok, status: response.status };
}

function isTelegramBotUsername(value) {
  const username = normalizeTelegramUsername(value);
  return Boolean(username && (username === normalizeTelegramUsername(TELEGRAM_BOT_USERNAME) || LEGACY_TELEGRAM_BOT_USERNAMES.has(username)));
}

function isTelegramBotIdentity(identity) {
  if (identity?.provider !== 'telegram') return false;
  const sameId = telegramBotUserId && identity.providerUserId != null
    && String(identity.providerUserId) === String(telegramBotUserId);
  return Boolean(sameId || isTelegramBotUsername(identity.username));
}

function telegramUsernameForDisplay(user) {
  if (!user) return '';
  const identity = userIdentities(user).find((candidate) => candidate.provider === 'telegram' && !isTelegramBotIdentity(candidate));
  const username = identity?.username || user?.username || '';
  return username && !isTelegramBotUsername(username) ? normalizeTelegramUsername(username) : '';
}

async function sendTelegramIdentity(identity, text, options = true) {
  await resolveTelegramBotIdentity();
  if (isTelegramBotIdentity(identity)) return { skipped: true, reason: 'bot_identity_ignored' };
  return sendTelegramMessage(identity.providerUserId, text, options);
}

async function notifyUser(user, text) {
  const deliveries = [];
  for (const identity of userIdentities(user)) {
    if (identity.provider === 'telegram') deliveries.push(sendTelegramIdentity(identity, text));
    else deliveries.push(sendVkMessage(identity.providerUserId, text));
  }
  return Promise.allSettled(deliveries);
}

function newMessageKeyboard(messageId) {
  return {
    inline_keyboard: [
      [{ text: '↩ Ответить', web_app: { url: buildWebAppUrl({ replyMessageId: messageId }) } }],
      [{ text: '🔎 Узнать отправителя · 7 ₽', url: telegramBotStartUrl(`reveal_${messageId}`) }, { text: '🚫 Заблокировать', callback_data: `block:${messageId}` }],
      [{ text: '💌 Открыть мой ящик', web_app: { url: buildWebAppUrl() } }]
    ]
  };
}

function messageForOwner(message, user) {
  const revealed = Array.isArray(message.revealedFor) && message.revealedFor.includes(user.id);
  const result = {
    id: message.id,
    publicLinkId: message.publicLinkId,
    body: message.body,
    text: message.text,
    caption: message.caption || '',
    media: message.media || null,
    source: message.source,
    senderAvailable: Boolean(message.senderAvailable),
    unread: Boolean(message.unread),
    saved: Boolean(message.saved),
    createdAt: message.createdAt,
    time: message.time,
    mood: message.mood,
    reply: message.reply || null,
    replyDelivery: message.replyDelivery || null,
    blocked: Boolean(message.sender?.fingerprint && isSenderBlocked(user.id, message.sender.fingerprint))
  };
  if (message.source === 'daily-anonymous') {
    result.sender = { provider: null, providerUserId: null, username: null, displayName: 'Аноним' };
  } else if (revealed && message.sender) {
    result.sender = {
      provider: message.sender.provider,
      providerUserId: message.sender.providerUserId,
      username: message.sender.username || null,
      displayName: message.sender.displayName || null
    };
  }
  return result;
}

function telegramMediaFromMessage(message) {
  if (message?.photo?.length) return { kind: 'photo', fileId: message.photo.at(-1).file_id };
  if (message?.video?.file_id) return { kind: 'video', fileId: message.video.file_id };
  if (message?.voice?.file_id) return { kind: 'voice', fileId: message.voice.file_id };
  if (message?.video_note?.file_id) return { kind: 'video_note', fileId: message.video_note.file_id };
  if (message?.sticker?.file_id) return { kind: 'sticker', fileId: message.sticker.file_id, emoji: message.sticker.emoji || '', stickerSetName: message.sticker.set_name || '' };
  if (message?.audio?.file_id) return { kind: 'audio', fileId: message.audio.file_id };
  if (message?.animation?.file_id) return { kind: 'animation', fileId: message.animation.file_id };
  if (message?.document?.file_id) return { kind: 'document', fileId: message.document.file_id };
  return null;
}

function telegramMediaLabel(media) {
  return ({ photo: '📷 Фото', video: '🎬 Видео', voice: '🔊 Голосовое', video_note: '📹 Видеосообщение', sticker: '✨ Стикер', audio: '🎵 Аудио', animation: '🎞 GIF', document: '📎 Файл' })[media?.kind] || '📎 Медиа';
}

function telegramBotStartUrl(startParameter = 'menu') {
  const username = TELEGRAM_BOT_USERNAME || 'poslaniya_robot';
  return `https://t.me/${username}?start=${encodeURIComponent(startParameter)}`;
}

function anonymousMessageSignature() {
  const username = TELEGRAM_BOT_USERNAME || 'poslaniya_robot';
  return `Послание отправлено через Послания 💌 t.me/${username}`;
}

async function notifyNewMessage(user, message) {
  const messageSignature = `\n\n<i>${escapeTelegramHtml(anonymousMessageSignature())}</i>`;
  const botText = message.media
    ? `${message.caption ? `💌 <b>Новое анонимное послание</b>\n\n${escapeTelegramHtml(message.caption)}` : '💌 <b>Новое анонимное послание</b>'}${messageSignature}`
    : `💌 <b>Новое анонимное послание</b>\n\nТекст послания:\n«${escapeTelegramHtml(message.text)}»${messageSignature}`;
  const deliveries = [];
  const recipientUsername = telegramUsernameForDisplay(user);
  const recipientHasBot = await telegramBotChatAvailable(user);
  let telegramDeliveredByUserbot = false;
  // Users who already opened the bot must stay on the Bot API path. The
  // userbot is reserved for recipients who are not registered in the bot.
  if (!recipientHasBot && recipientUsername && telegramUserbot.isReady) {
    const userbotResult = await telegramUserbot.sendAnonymousMessage({
      username: recipientUsername,
      text: message.caption || (message.media ? '' : message.text),
      media: message.media || null,
      signature: anonymousMessageSignature(),
      botUrl: telegramBotStartUrl('menu'),
      revealUrl: telegramBotStartUrl(`reveal_${message.id}`)
    });
    if (userbotResult.sent) {
      telegramDeliveredByUserbot = true;
      deliveries.push(Promise.resolve(userbotResult));
    }
  }
  for (const identity of userIdentities(user)) {
    if (identity.provider === 'telegram') {
      if (telegramDeliveredByUserbot || isTelegramBotIdentity(identity) || !identity.providerUserId) continue;
      deliveries.push((async () => {
        await resolveTelegramBotIdentity();
        if (isTelegramBotIdentity(identity)) return { skipped: true, reason: 'bot_identity_ignored' };
        await sendTelegramSticker(identity.providerUserId, TELEGRAM_RECEIVED_STICKER_ID);
        if (message.media) return sendTelegramMedia(identity.providerUserId, message.media, botText, { reply_markup: newMessageKeyboard(message.id) });
        return sendTelegramMessage(identity.providerUserId, botText, { reply_markup: newMessageKeyboard(message.id) });
      })());
    } else {
      deliveries.push(sendVkMessage(identity.providerUserId, botText.replace(/<[^>]+>/g, ''), true, buildWebAppUrl({ payment: 'reveal', messageId: message.id }), '🔎 Узнать отправителя · 7 ₽'));
    }
  }
  const results = await Promise.allSettled(deliveries);
  if (!deliveries.length) console.warn(`[telegram] no delivery identity for owner ${user?.id || 'unknown'}; message=${message?.id || 'unknown'}`);
  if (results.some((result) => result.status === 'rejected' || result.value?.sent === false)) {
    console.warn(`[telegram] owner notification had delivery failures; owner=${user?.id || 'unknown'} message=${message?.id || 'unknown'}`);
  }
  return results;
}

function revealRewardText(language = 'ru') {
  return language === 'en'
    ? '🙈 Sorry — this was a playful daily teaser from Poslaniya, so there is no real sender to reveal. As a thank-you, we gifted you VIP for 7 days. Real messages will appear in your inbox 💌'
    : '🙈 Извините — это было игровое послание дня от «Посланий», поэтому настоящего отправителя здесь нет. В качестве извинения дарим вам VIP на 7 дней. Настоящие сообщения появятся в вашем ящике 💌';
}

async function giftVipAfterReveal(user) {
  const start = user.vipUntil && new Date(user.vipUntil).getTime() > Date.now() ? new Date(user.vipUntil).getTime() : Date.now();
  user.vipUntil = new Date(start + 7 * 24 * 60 * 60 * 1000).toISOString();
  schedulePersist();
  await notifyUser(user, revealRewardText(user.language || 'ru'));
}

async function configureTelegramBot() {
  if (!TELEGRAM_BOT_TOKEN) return;
  await resolveTelegramBotIdentity();
  if (!TELEGRAM_BOT_USERNAME) console.warn('[telegram] bot has no username; direct Telegram links will be unavailable');
  if (!WEB_APP_URL.startsWith('https://')) return;
  const headers = { 'Content-Type': 'application/json' };
  const menuPayload = { menu_button: { type: 'web_app', text: 'Мой ящик 💌', web_app: { url: buildWebAppUrl() } } };
  const commandsPayload = { commands: [{ command: 'start', description: 'Открыть Послания' }, { command: 'app', description: 'Открыть мой ящик' }, { command: 'link', description: 'Моя персональная ссылка' }, { command: 'daily', description: 'Послание дня' }, { command: 'message', description: 'Написать послание' }, { command: 'help', description: 'Помощь' }, { command: 'settings', description: 'Настройки уведомлений' }] };
  await Promise.all([
    fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setChatMenuButton`, { method: 'POST', headers, body: JSON.stringify(menuPayload) }),
    fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setMyCommands`, { method: 'POST', headers, body: JSON.stringify(commandsPayload) })
  ]).catch((error) => console.error('[telegram] bot setup failed:', error.message));
}

const botCopy = {
  ru: {
    chooseLanguage: 'Выберите язык. Я буду присылать послания на выбранном языке:',
    welcome: 'Добро пожаловать в «Послания» 💌',
    menuHint: 'Ваш сайт, боты и Web App синхронизированы.',
    openApp: 'Открыть мой ящик',
    myLink: 'Моя ссылка',
    instructions: 'Как поставить ссылку',
    daily: 'Послание дня',
    vip: 'VIP — 20 ₽ / 7 дней',
    reveal: 'Открыть за 7 ₽',
    topup: 'Пополнить баланс',
    gift: 'Анонимный подарок',
    settings: 'Настройки',
    help: 'Помощь',
    language: 'Язык',
    dailyOn: 'Ежедневные послания включены',
    dailyOff: 'Ежедневные послания выключены',
    paymentTitle: 'Выберите способ оплаты',
    stub: 'Этот способ пока заглушка. Подключим позже.',
    admin: 'Панель администратора',
    broadcastAsk: 'Отправьте следующим сообщением текст или медиа для рассылки. Для отмены: /cancel',
    broadcastDone: 'Рассылка завершена',
    noAccess: 'Доступно только администратору.'
  },
  en: {
    chooseLanguage: 'Choose your language. I will send messages in this language:',
    welcome: 'Welcome to “Messages” 💌',
    menuHint: 'Your website, bots and Web App are synchronized.',
    openApp: 'Open my inbox',
    myLink: 'My link',
    instructions: 'How to add the link',
    daily: 'Message of the day',
    vip: 'VIP — 20 RUB / 7 days',
    reveal: 'Unlock for 7 RUB',
    topup: 'Top up balance',
    gift: 'Anonymous gift',
    settings: 'Settings',
    help: 'Help',
    language: 'Language',
    dailyOn: 'Daily messages enabled',
    dailyOff: 'Daily messages disabled',
    paymentTitle: 'Choose a payment method',
    stub: 'This payment method is a placeholder for now.',
    admin: 'Admin panel',
    broadcastAsk: 'Send text or media in the next message. Cancel with /cancel',
    broadcastDone: 'Broadcast finished',
    noAccess: 'Admin access only.'
  }
};

function botText(language, key) {
  return botCopy[language === 'en' ? 'en' : 'ru'][key];
}

function platformLinks(user = null) {
  const site = new URL(WEB_APP_URL).origin;
  const slug = user ? ensurePublicLink(user).slug : (DEMO_MODE ? demoSlug() : '');
  return {
    telegram: `https://t.me/${TELEGRAM_BOT_USERNAME}`,
    // Use the regular bot deep link: Telegram opens the bot and delivers /start ref_<slug>.
    telegramReferral: `https://t.me/${TELEGRAM_BOT_USERNAME}?start=ref_${encodeURIComponent(slug)}`,
    vk: `https://vk.me/${VK_GROUP_ID}`,
    vkReferral: `https://vk.me/${VK_GROUP_ID}?ref=ref_${encodeURIComponent(slug)}`,
    site,
    siteReferral: `${site}/?ref=${encodeURIComponent(slug)}`
  };
}

function escapeTelegramHtml(value) {
  return String(value).replace(/[&<>\"]/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '\"': '&quot;' }[character]));
}

function profileInstructions(language = 'ru', user = null, channel = 'telegram') {
  const links = platformLinks(user);
  const isVk = channel === 'vk';
  const platform = isVk ? 'ВКонтакте' : 'Telegram';
  const referralLink = isVk ? links.vkReferral : links.telegramReferral;
  if (isVk) {
    if (language === 'en') return `📌 Personal profile link: VK\n\nAdd this personal referral link to your profile:\n${referralLink}\n\n🌐 Personal website link:\n${links.siteReferral}\n\nReady-to-post text:\nSend me an anonymous message 💌\nLeave it here:\n${links.siteReferral}`;
    return `📌 Персональная ссылка в профиль: ВКонтакте\n\nДобавьте в профиль именно эту реферальную ссылку:\n${referralLink}\n\n🌐 Персональная ссылка на сайт:\n${links.siteReferral}\n\nГотовый текст для профиля:\nНапиши мне анонимно 💌\nОставь послание здесь:\n${links.siteReferral}`;
  }
  const safeReferral = escapeTelegramHtml(referralLink);
  const safeSiteReferral = escapeTelegramHtml(links.siteReferral);
  if (language === 'en') {
    const englishPlatform = isVk ? 'VK' : 'Telegram';
    return `<b>📌 Personal profile link: ${englishPlatform}</b>\n\nAdd this personal referral link to your profile:\n<a href="${safeReferral}">${safeReferral}</a>\n\n<b>🌐 Personal website link</b>\n<a href="${safeSiteReferral}">${safeSiteReferral}</a>\n\n<b>Ready-to-post text:</b>\nSend me an anonymous message 💌\nLeave it here:\n${safeSiteReferral}\n\nThe Telegram link opens the bot and accepts the message directly in chat.`;
  }
    return `<b>📌 Персональная ссылка в профиль: ${platform}</b>\n\nДобавьте в профиль именно эту реферальную ссылку:\n<a href="${safeReferral}">${safeReferral}</a>\n\n<b>🌐 Персональная ссылка на сайт</b>\n<a href="${safeSiteReferral}">${safeSiteReferral}</a>\n\n<b>Готовый текст для профиля:</b>\nНапиши мне анонимно 💌\nОставь послание здесь:\n${safeSiteReferral}\n\nTelegram-ссылка открывает бот и принимает послание прямо в чате.`;
}

function languageKeyboard() {
  return { inline_keyboard: [[{ text: '🇷🇺 Русский', callback_data: 'lang:ru' }, { text: '🇬🇧 English', callback_data: 'lang:en' }]] };
}

function botMenuKeyboard(language, recipientSlug = null, authToken = null) {
  const appUrl = buildWebAppUrl({
    ...(recipientSlug ? { ref: recipientSlug } : {}),
    ...(authToken ? { auth: authToken } : {})
  });
  return { inline_keyboard: [
    [{ text: `💌 ${botText(language, 'openApp')}`, web_app: { url: appUrl } }],
    [{ text: `🔗 ${botText(language, 'myLink')}`, callback_data: 'menu:link' }, { text: `✦ ${botText(language, 'daily')}`, callback_data: 'menu:daily' }],
    [{ text: `♛ ${botText(language, 'vip')}`, callback_data: 'pay:choose:vip' }, { text: `? ${botText(language, 'reveal')}`, callback_data: 'pay:choose:reveal' }],
    [{ text: `💳 ${botText(language, 'topup')}`, callback_data: 'topup:menu' }],
    [{ text: '✍️ Написать послание', callback_data: 'message:choose' }],
    [{ text: `🎁 ${botText(language, 'gift')}`, callback_data: 'gift:menu' }],
    [{ text: `📌 ${botText(language, 'instructions')}`, callback_data: 'menu:instructions' }],
    [{ text: `⚙ ${botText(language, 'settings')}`, callback_data: 'menu:settings' }, { text: `? ${botText(language, 'help')}`, callback_data: 'menu:help' }]
  ] };
}

const paymentProviderLabels = {
  yoomoney: 'Карта / ЮMoney',
  xrocket: 'xRocket',
  cryptobot: 'CryptoBot',
  sbp: 'СБП — по чеку',
  balance: 'Внутренний баланс'
};

function paymentKeyboard(language, plan, messageId = null, user = null) {
  const suffix = `${plan}:${messageId || '-'}`;
  const rows = [];
  if (paymentMethodIsConfigured('yoomoney')) rows.push([{ text: `💳 ${paymentProviderLabels.yoomoney}`, callback_data: `pay:method:yoomoney:${suffix}` }]);
  const cryptoRows = [];
  if (paymentMethodIsConfigured('xrocket')) cryptoRows.push({ text: `🚀 ${paymentProviderLabels.xrocket}`, callback_data: `pay:method:xrocket:${suffix}` });
  if (paymentMethodIsConfigured('cryptobot')) cryptoRows.push({ text: `₿ ${paymentProviderLabels.cryptobot}`, callback_data: `pay:method:cryptobot:${suffix}` });
  if (cryptoRows.length) rows.push(cryptoRows);
  if (paymentMethodIsConfigured('sbp')) rows.push([{ text: `🏦 ${paymentProviderLabels.sbp}`, callback_data: `pay:method:sbp:${suffix}` }]);
  const amount = plan === 'reveal' ? 7 : 20;
  if (user && Number(user.balanceRub || 0) >= amount) rows.push([{ text: `💰 Заплатить с баланса (${user.balanceRub} ₽)`, callback_data: `pay:method:balance:${suffix}` }]);
  rows.push([{ text: `💌 ${botText(language, 'openApp')}`, web_app: { url: buildWebAppUrl({ payment: plan, ...(messageId ? { messageId } : {}) }) } }]);
  return { inline_keyboard: rows };
}

function xrocketAuthHeader() {
  const token = String(XROCKET_API_TOKEN || '').trim().replace(/^Bearer\s+/i, '').replace(/^['"]|['"]$/g, '');
  return token ? `Bearer ${token}` : '';
}

function paymentMethodIsConfigured(provider) {
  // A YooMoney quickpay link alone cannot confirm an incoming transfer.
  // Require an OAuth token with operation-history scope so the balance is
  // credited automatically instead of leaving an unverified payment pending.
  if (provider === 'yoomoney') return Boolean((YUMONEY_PAYMENT_URL || YUMONEY_RECEIVER) && YUMONEY_TOKEN);
  if (provider === 'xrocket') return Boolean(XROCKET_API_TOKEN);
  if (provider === 'cryptobot') return Boolean(CRYPTOBOT_API_TOKEN);
  return provider === 'sbp' && sbpDetailsConfigured();
}

function paymentProviderList() {
  return Object.entries(paymentProviderLabels).filter(([id]) => id !== 'balance').map(([id, label]) => ({ id, label, configured: paymentMethodIsConfigured(id) }));
}

function paymentDescription(payment) {
  if (payment.purpose === 'balance') return `Пополнение баланса «Послания» на ${payment.amount} ₽`;
  if (payment.plan === 'vip') return 'VIP доступ «Послания» на 7 дней';
  return 'Раскрытие отправителя послания';
}

function createPaymentRecord(user, { provider, purpose, plan = null, amount, messageId = null }) {
  const payment = {
    id: `pay-${randomUUID()}`,
    provider,
    purpose,
    plan,
    amount,
    currency: 'RUB',
    userId: user?.id || null,
    telegramChatId: user ? (identityFor(user, 'telegram')?.providerUserId || null) : null,
    messageId: messageId || null,
    status: provider === 'sbp' ? 'manual_pending' : 'pending',
    createdAt: new Date().toISOString()
  };
  payments.set(payment.id, payment);
  schedulePersist();
  return payment;
}

function yoomoneyPaymentUrl(payment) {
  const baseUrl = YUMONEY_PAYMENT_URL || (YUMONEY_RECEIVER ? 'https://yoomoney.ru/quickpay/confirm.xml' : '');
  if (!baseUrl) return '';
  try {
    const url = new URL(baseUrl);
    if (YUMONEY_RECEIVER) url.searchParams.set('receiver', YUMONEY_RECEIVER);
    url.searchParams.set('quickpay-form', url.searchParams.get('quickpay-form') || 'shop');
    url.searchParams.set('targets', paymentDescription(payment));
    // successURL is intentionally omitted: the server confirms the payment
    // through YooMoney operation-history polling, not a browser redirect.
    url.searchParams.set('label', payment.id);
    url.searchParams.set('sum', String(payment.amount));
    url.searchParams.set('currency', payment.currency || 'RUB');
    return url.toString();
  } catch {
    return baseUrl;
  }
}

function announceCryptoBotWebhook() {
  if (!CRYPTOBOT_API_TOKEN) return;
  console.log(`[payments] CryptoBot webhook URL: ${new URL(WEB_APP_URL).origin}/webhooks/payments/cryptobot (set it in @CryptoBot → My Apps → Webhooks)`);
}

async function createCryptoBotInvoice(payment) {
  const response = await fetch(`${CRYPTOBOT_API_URL.replace(/\/$/, '')}/createInvoice`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Crypto-Pay-API-Token': CRYPTOBOT_API_TOKEN },
    body: JSON.stringify({
      currency_type: 'fiat',
      fiat: 'RUB',
      amount: String(payment.amount),
      description: paymentDescription(payment),
      payload: payment.id,
      expires_in: 3600
    })
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok) throw new Error(payload.error?.name || payload.error?.description || 'CryptoBot invoice failed');
  const result = payload.result || {};
  return { url: result.bot_invoice_url || result.pay_url, externalId: result.invoice_id };
}

async function getXRocketRate(baseCurrency, assetCurrency) {
  if (XROCKET_RUB_ASSET_RATE > 0 && baseCurrency === 'RUB') return XROCKET_RUB_ASSET_RATE;
  const url = new URL(`${XROCKET_API_URL.replace(/\/$/, '')}/api/v1/rates`);
  url.searchParams.set('base', baseCurrency);
  url.searchParams.set('assets', assetCurrency);
  const response = await fetch(url, { headers: { Accept: 'application/json' } });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || payload.message || `xRocket rates API ${response.status}`);
  const rates = Array.isArray(payload) ? payload : payload.rates || payload.data || payload.items || [];
  const rateEntry = rates.find?.((entry) => String(entry?.currency || entry?.asset || entry?.code || '').toUpperCase() === assetCurrency)
    || (payload && typeof payload === 'object' && !Array.isArray(payload)
      ? (String(payload.currency || '').toUpperCase() === assetCurrency ? payload : payload[assetCurrency])
      : null);
  const rate = Number(typeof rateEntry === 'object' ? (rateEntry.rate ?? rateEntry.value ?? rateEntry.price) : rateEntry);
  if (!Number.isFinite(rate) || rate <= 0) throw new Error(`xRocket rate for ${assetCurrency} in ${baseCurrency} was not returned`);
  return rate;
}

async function resolveXRocketInvoicePrice(payment) {
  const configuredCurrency = XROCKET_PRICE_CURRENCY;
  if (configuredCurrency !== 'RUB') {
    const rate = await getXRocketRate('RUB', configuredCurrency);
    return { currency: configuredCurrency, amount: Number((Number(payment.amount) * rate).toFixed(8)) };
  }
  const fallbackCurrency = XROCKET_FALLBACK_PRICE_CURRENCY === 'RUB' ? 'USDT' : XROCKET_FALLBACK_PRICE_CURRENCY;
  const rate = await getXRocketRate('RUB', fallbackCurrency);
  return { currency: fallbackCurrency, amount: Number((Number(payment.amount) * rate).toFixed(8)) };
}

async function createXRocketPaymentLink(payment) {
  const invoicePrice = await resolveXRocketInvoicePrice(payment);
  const response = await fetch(`${XROCKET_API_URL.replace(/\/$/, '')}/api/v1/invoices`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', Authorization: xrocketAuthHeader() },
    body: JSON.stringify({
      priceAmount: String(invoicePrice.amount),
      priceCurrency: invoicePrice.currency,
      ...(XROCKET_PAYOUT_CURRENCY && XROCKET_PAYOUT_CURRENCY.toUpperCase() !== 'RUB' ? { payoutCurrency: XROCKET_PAYOUT_CURRENCY.toUpperCase() } : {}),
      clientInvoiceId: payment.id,
      description: paymentDescription(payment),
      expiresIn: 3600000,
      callback: {
        callbackUrl: `${new URL(WEB_APP_URL).origin}/webhooks/payments/xrocket`,
        payload: { paymentId: payment.id }
      },
      url: { successUrl: `${new URL(WEB_APP_URL).origin}/?payment=success`, cancelUrl: `${new URL(WEB_APP_URL).origin}/?payment=cancel` }
    })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 || String(payload.title || payload.error || '').toLowerCase() === 'unauthorized') {
      throw new Error('xRocket API отклонил токен. Нужен токен приложения из раздела Pay API, а не токен бота; для testnet используйте XROCKET_TESTNET=true.');
    }
    throw new Error(payload.detail || payload.message || payload.title || `xRocket payment link failed (${response.status})`);
  }
  const result = payload.result || payload.data || payload;
  return {
    url: result.links?.webLink || result.links?.telegramBotLink || result.pay_url || result.payment_url || result.url,
    externalId: result.id || result.invoice_id,
    priceAmount: invoicePrice.amount,
    priceCurrency: invoicePrice.currency
  };
}

async function createPaymentCheckout(user, { provider, purpose, plan = null, amount, messageId = null }) {
  if (provider === 'balance') {
    if (!user) throw new Error('Balance payment requires authorization');
    if (Number(user.balanceRub || 0) < amount) throw new Error('Недостаточно средств на балансе');
    const payment = createPaymentRecord(user, { provider, purpose, plan, amount, messageId });
    user.balanceRub = Number(user.balanceRub || 0) - amount;
    applyPaidPayment(payment);
    return payment;
  }
  const payment = createPaymentRecord(user, { provider, purpose, plan, amount, messageId });
  try {
    if (provider === 'yoomoney') {
      if (!YUMONEY_PAYMENT_URL && !YUMONEY_RECEIVER) throw new Error('YUMONEY_RECEIVER or YUMONEY_PAYMENT_URL is not configured');
      if (!YUMONEY_TOKEN) throw new Error('YUMONEY_TOKEN with operation-history scope is not configured');
      payment.paymentUrl = yoomoneyPaymentUrl(payment);
    } else if (provider === 'cryptobot') {
      if (!CRYPTOBOT_API_TOKEN) throw new Error('CRYPTOBOT_API_TOKEN is not configured');
      const invoice = await createCryptoBotInvoice(payment);
      if (!invoice.url) throw new Error('CryptoBot did not return a payment URL');
      payment.paymentUrl = invoice.url;
      payment.externalId = invoice.externalId || null;
    } else if (provider === 'xrocket') {
      if (!xrocketAuthHeader()) throw new Error('XROCKET_API_TOKEN is not configured');
      const paymentLink = await createXRocketPaymentLink(payment);
      if (!paymentLink.url) throw new Error('xRocket did not return a payment URL');
      payment.paymentUrl = paymentLink.url;
      payment.externalId = paymentLink.externalId || null;
      payment.providerAmount = paymentLink.priceAmount;
      payment.providerCurrency = paymentLink.priceCurrency;
    } else if (provider === 'sbp') {
      if (!sbpDetailsConfigured()) throw new Error('SBP_PAYMENT_DETAILS is not configured');
      payment.instructions = SBP_PAYMENT_DETAILS;
      payment.botUrl = sbpBotUrl(payment);
    } else {
      throw new Error('Unsupported payment provider');
    }
    if (provider !== 'sbp') payment.status = 'pending';
    schedulePersist();
    return payment;
  } catch (error) {
    payment.status = 'failed';
    payment.error = error.message;
    schedulePersist();
    throw error;
  }
}

function applyPaidPayment(payment) {
  if (!payment || payment.status === 'paid') return false;
  payment.status = 'paid';
  payment.paidAt = new Date().toISOString();
  const user = payment.userId && users.get(payment.userId);
  if (user) {
    if (payment.purpose === 'balance') user.balanceRub = (Number(user.balanceRub) || 0) + Number(payment.amount);
    if (payment.plan === 'vip') user.vipUntil = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    if (payment.plan === 'reveal') {
      user.revealCredits = (user.revealCredits || 0) + 1;
      const message = payment.messageId && messages.get(payment.messageId);
      const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user.id);
      if (message && ownerLink && message.senderAvailable) {
        message.revealedFor = Array.isArray(message.revealedFor) ? message.revealedFor : [];
        if (!message.revealedFor.includes(user.id)) message.revealedFor.push(user.id);
      }
    }
  }
  schedulePersist();
  return true;
}

async function reconcileExternalPayment(payment) {
  if (!payment || payment.status !== 'pending') return payment;
  if (payment.provider !== 'yoomoney' && !payment.externalId) return payment;
  try {
    if (payment.provider === 'yoomoney' && YUMONEY_TOKEN) {
      const url = new URL(`${YUMONEY_API_URL.replace(/\/$/, '')}/operation-history`);
      const form = new URLSearchParams({ records: '100', label: payment.id });
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${YUMONEY_TOKEN}`
        },
        body: form
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error || `YooMoney operation-history ${response.status}`);
      const operation = (Array.isArray(payload.operations) ? payload.operations : []).find((candidate) => {
        const direction = String(candidate.direction || '').toLowerCase();
        return String(candidate.label || '') === String(payment.id)
          && String(candidate.status || '').toLowerCase() === 'success'
          && (!direction || direction === 'in' || direction === 'incoming')
          && Number(candidate.amount) === Number(payment.amount);
      });
      if (operation) applyPaidPayment(payment);
    } else if (payment.provider === 'cryptobot' && CRYPTOBOT_API_TOKEN) {
      const response = await fetch(`${CRYPTOBOT_API_URL.replace(/\/$/, '')}/getInvoices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Crypto-Pay-API-Token': CRYPTOBOT_API_TOKEN },
        // Crypto Pay expects invoice_ids as an array of numeric invoice IDs.
        body: JSON.stringify({ invoice_ids: [Number(payment.externalId)] })
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok || payload.ok === false) {
        throw new Error(payload.error?.name || payload.error?.description || `CryptoBot getInvoices ${response.status}`);
      }
      const items = Array.isArray(payload.result?.items)
        ? payload.result.items
        : (Array.isArray(payload.result) ? payload.result : []);
      // Do not fall back to the first item: crediting a different invoice
      // would be worse than leaving this payment pending.
      const invoice = items.find((candidate) => String(candidate.invoice_id ?? candidate.id) === String(payment.externalId)) || null;
      const status = String(invoice?.status || '').toLowerCase();
      // Crypto Pay documents the invoice lifecycle as active, paid and
      // expired. Only paid (plus the harmless completed alias used by some
      // compatible gateways) is allowed to credit an internal balance.
      if (['paid', 'completed'].includes(status)) applyPaidPayment(payment);
      if (['expired', 'failed', 'cancelled'].includes(status)) {
        payment.status = status;
        schedulePersist();
      }
    } else if (payment.provider === 'xrocket' && xrocketAuthHeader()) {
      // The current xRocket Pay API reads an invoice by query parameter
      // GET /api/v1/invoice?invoiceId=..., not /invoices/:id.
      const url = new URL(`${XROCKET_API_URL.replace(/\/$/, '')}/api/v1/invoice`);
      url.searchParams.set('invoiceId', String(payment.externalId));
      const response = await fetch(url, {
        headers: { Accept: 'application/json', Authorization: xrocketAuthHeader() }
      });
      const payload = await response.json().catch(() => ({}));
      const invoice = payload.result || payload.data || payload;
      const status = String(invoice.status || '').toLowerCase();
      const reportedAmount = invoice.priceAmount ?? invoice.price_amount;
      const expectedAmount = payment.providerAmount ?? payment.amount;
      if (['paid', 'completed'].includes(status) && (reportedAmount === undefined || Number(reportedAmount) === Number(expectedAmount))) applyPaidPayment(payment);
      if (['expired', 'failed', 'cancelled'].includes(status)) {
        payment.status = status;
        schedulePersist();
      }
    }
  } catch (error) {
    console.warn(`[payments] reconciliation failed for ${payment.id}:`, error.message);
  }
  return payment;
}

let paymentReconciliationRunning = false;

async function runPendingPaymentReconciliation() {
  if (paymentReconciliationRunning) return { checked: 0, paid: 0 };
  paymentReconciliationRunning = true;
  try {
    const pending = [...payments.values()]
      .filter((payment) => payment.status === 'pending'
        && ['cryptobot', 'xrocket', 'yoomoney'].includes(payment.provider))
      .sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')))
      .slice(0, 100);
    let paid = 0;
    for (const payment of pending) {
      const before = payment.status;
      await reconcileExternalPayment(payment);
      if (before !== 'paid' && payment.status === 'paid') paid += 1;
    }
    if (paid) console.log(`[payments] background reconciliation credited ${paid} payment(s)`);
    return { checked: pending.length, paid };
  } finally {
    paymentReconciliationRunning = false;
  }
}

function topupAmountKeyboard() {
  return { inline_keyboard: [
    [{ text: '100 ₽', callback_data: 'topup:amount:100' }, { text: '300 ₽', callback_data: 'topup:amount:300' }, { text: '500 ₽', callback_data: 'topup:amount:500' }],
    [{ text: 'Открыть Web App и выбрать сумму', web_app: { url: buildWebAppUrl({ payment: 'balance' }) } }]
  ] };
}

function topupMethodKeyboard(amount) {
  const rows = [];
  if (paymentMethodIsConfigured('yoomoney')) rows.push([{ text: `💳 ${paymentProviderLabels.yoomoney}`, callback_data: `topup:method:yoomoney:${amount}` }]);
  const cryptoRows = [];
  if (paymentMethodIsConfigured('xrocket')) cryptoRows.push({ text: `🚀 ${paymentProviderLabels.xrocket}`, callback_data: `topup:method:xrocket:${amount}` });
  if (paymentMethodIsConfigured('cryptobot')) cryptoRows.push({ text: `₿ ${paymentProviderLabels.cryptobot}`, callback_data: `topup:method:cryptobot:${amount}` });
  if (cryptoRows.length) rows.push(cryptoRows);
  if (paymentMethodIsConfigured('sbp')) rows.push([{ text: `🏦 ${paymentProviderLabels.sbp}`, callback_data: `topup:method:sbp:${amount}` }]);
  if (!rows.length) rows.push([{ text: 'Открыть Web App и выбрать способ оплаты', web_app: { url: buildWebAppUrl({ payment: 'balance' }) } }]);
  return { inline_keyboard: rows };
}

async function sendPaymentResult(chatId, payment, language = 'ru') {
  if (payment.status === 'paid') {
    return sendTelegramMessage(chatId, `✅ Оплата на ${payment.amount} ₽ списана с внутреннего баланса.`, { reply_markup: botMenuKeyboard(language) });
  }
  if (payment.paymentUrl) {
    return sendTelegramMessage(chatId, `💳 <b>${escapeTelegramHtml(paymentDescription(payment))}</b>\n\nОткройте ссылку для оплаты. После подтверждения платёж будет зачислен автоматически.`, { reply_markup: { inline_keyboard: [[{ text: `Оплатить через ${paymentProviderLabels[payment.provider]}`, url: payment.paymentUrl }], [{ text: '← Меню', callback_data: 'menu:home' }]] } });
  }
  if (payment.provider === 'sbp') {
    const botUrl = sbpBotUrl(payment) || payment.botUrl;
    const details = sbpInstructions(payment);
    const keyboard = [{ text: '← Меню', callback_data: 'menu:home' }];
    if (botUrl && sbpDetailsConfigured()) keyboard.unshift({ text: 'Открыть бота и отправить чек', url: botUrl });
    const nextStep = sbpDetailsConfigured()
      ? 'После оплаты нажмите «Открыть бота и отправить чек», затем отправьте фото или документ чека. Баланс пополнится после подтверждения оплаты.'
      : 'СБП временно недоступна: реквизиты ещё не настроены.';
    return sendTelegramMessage(chatId, `🏦 <b>Оплата через СБП</b>\n\n${escapeTelegramHtml(details)}\n\n${nextStep}`, { reply_markup: { inline_keyboard: [keyboard] } });
  }
  return sendTelegramMessage(chatId, 'Платёж создан, но ссылка оплаты пока не настроена.', { reply_markup: botMenuKeyboard(language) });
}

async function mystarsRequest(path, options = {}) {
  if (!MYSTARS_API_KEY) throw new Error('MYSTARS_API_KEY is not configured');
  const headers = { Accept: 'application/json', 'Content-Type': 'application/json', 'X-Api-Key': MYSTARS_API_KEY, ...(options.headers || {}) };
  const response = await fetch(`${MYSTARS_API_URL.replace(/\/$/, '')}${path}`, { ...options, headers });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.detail || payload.message || payload.error || `MyStars API ${response.status}`);
  return payload;
}

function normalizeTelegramUsername(value) {
  return String(value || '').trim().replace(/^@+/, '').toLowerCase();
}

function validateGiftRequest(body) {
  const type = body.type === 'star_gift' ? 'star_gift' : body.type === 'premium' ? 'premium' : body.type === 'stars' ? 'stars' : null;
  const username = normalizeTelegramUsername(body.username || body.recipient?.username);
  const offerKey = String(body.offer_key || body.offerKey || '').trim() || null;
  if (!type) throw new Error('type must be star_gift, stars or premium');
  if (!/^[a-z0-9_]{5,32}$/i.test(username)) throw new Error('valid Telegram username is required');
  if (type === 'star_gift') {
    const giftId = String(body.gift_id || body.giftId || '').trim();
    if (!/^\d{1,24}$/.test(giftId)) throw new Error('Telegram gift is required');
    return { type, username, giftId, offerKey };
  }
  if (type === 'stars') {
    const quantity = Number(body.quantity);
    if (!Number.isInteger(quantity) || quantity < 50 || quantity > 1_000_000) throw new Error('Stars quantity must be between 50 and 1000000');
    return { type, username, quantity, offerKey, payment_currency: body.payment_currency === 'usdt_ton' ? 'usdt_ton' : MYSTARS_PAYMENT_CURRENCY };
  }
  const months = Number(body.months);
  if (![3, 6, 12].includes(months)) throw new Error('Premium months must be 3, 6 or 12');
  return { type, username, months, offerKey, payment_currency: body.payment_currency === 'usdt_ton' ? 'usdt_ton' : MYSTARS_PAYMENT_CURRENCY };
}

function giftOfferKey(offer) {
  const snapshot = {
    type: offer?.type || null,
    giftId: offer?.giftId || null,
    giftStars: Number(offer?.giftStars || 0),
    costStars: Number(offer?.costStars || 0),
    priceCurrency: String(offer?.priceCurrency || '').toUpperCase(),
    priceAmount: Number(offer?.priceAmount || 0),
    option: offer?.option ? {
      currency: String(offer.option.currency || '').toUpperCase(),
      stars: Number(offer.option.stars || 0),
      amount: Number(offer.option.amount || 0)
    } : null
  };
  return createHash('sha256').update(JSON.stringify(snapshot)).digest('hex');
}

async function getMyStarsQuote(gift) {
  const params = new URLSearchParams({ type: gift.type, payment_currency: gift.payment_currency });
  if (gift.type === 'stars') params.set('quantity', String(gift.quantity));
  else params.set('months', String(gift.months));
  return mystarsRequest(`/v1/pricing?${params}`);
}

async function checkMyStarsRecipient(gift) {
  return mystarsRequest('/v1/recipients/check', { method: 'POST', body: JSON.stringify({ type: gift.type, recipient: { username: gift.username } }) });
}

function giftDescription(order) {
  if (order.type === 'star_gift') return `${order.giftTitle || 'Telegram-подарок'} · ${order.quantity} Stars`;
  return order.type === 'stars' ? `${order.quantity} Telegram Stars` : `Telegram Premium на ${order.months} мес.`;
}

function mystarsBalanceBasePrice(gift) {
  if (gift.type === 'stars' || gift.type === 'star_gift') return Number(gift.quantity || gift.stars) * MYSTARS_BALANCE_STARS_RUB_PER_UNIT;
  const prices = { 3: MYSTARS_BALANCE_PREMIUM_3_RUB, 6: MYSTARS_BALANCE_PREMIUM_6_RUB, 12: MYSTARS_BALANCE_PREMIUM_12_RUB };
  return prices[gift.months] || 0;
}

function mystarsBalancePrice(gift) {
  const basePrice = mystarsBalanceBasePrice(gift);
  const markup = Number.isFinite(MYSTARS_BALANCE_MARKUP_PERCENT) ? MYSTARS_BALANCE_MARKUP_PERCENT : 10;
  if (!Number.isFinite(basePrice) || basePrice <= 0 || markup < 0) return null;
  return { basePrice, markupPercent: markup, amount: Math.ceil(basePrice * (1 + markup / 100)) };
}

function userbotGiftBalancePrice(offer, gift = null) {
  const currency = String(offer?.priceCurrency || '').toUpperCase();
  const nativeRub = currency === 'RUB' && Number(offer?.priceAmount) > 0 ? Number(offer.priceAmount) / 100 : 0;
  if (nativeRub > 0) {
    const markup = Number.isFinite(MYSTARS_BALANCE_MARKUP_PERCENT) ? MYSTARS_BALANCE_MARKUP_PERCENT : 10;
    return { basePrice: nativeRub, markupPercent: markup, amount: Math.ceil(nativeRub * (1 + markup / 100)) };
  }
  // Premium has an XTR price from Telegram, while the service price can be
  // configured per subscription period. Prefer that period price instead of
  // silently requiring a Stars-to-RUB unit rate.
  if (offer?.type === 'premium' && gift?.months) {
    const premiumPrice = mystarsBalancePrice({ type: 'premium', months: gift.months });
    if (premiumPrice) return premiumPrice;
  }
  return mystarsBalancePrice({ type: 'stars', quantity: offer?.costStars });
}

async function notifyMystarsAdmins(order) {
  const payment = order.payment || {};
  const adminIds = TELEGRAM_ADMIN_IDS.split(',').map((id) => id.trim()).filter(Boolean);
  if (!adminIds.length) return;
  const balanceLine = order.paymentMethod === 'balance' ? `\nОплата пользователя: <b>${escapeTelegramHtml(String(order.balancePriceRub))} ₽ списано с баланса</b>\nНаценка сервиса: <b>${escapeTelegramHtml(String(order.balanceMarkupPercent))}%</b>` : '\nОплата пользователя: администратор подтверждает оплату отдельно';
  const topupLine = order.userbotTopupQuantity ? `\nПополнение userbot: <b>${escapeTelegramHtml(String(order.userbotTopupQuantity))} Stars</b>` : '';
  const details = `🎁 <b>Новый анонимный подарок</b>\n\nПолучатель: <code>@${escapeTelegramHtml(order.username)}</code>\nТовар: <b>${escapeTelegramHtml(giftDescription(order))}</b>${topupLine}${balanceLine}\nMyStars order: <code>${escapeTelegramHtml(String(order.remoteOrderId || order.id))}</code>\n\nОплатить MyStars вручную:\nСумма: <code>${escapeTelegramHtml(String(payment.amount || '—'))} ${escapeTelegramHtml(String(payment.currency || ''))}</code>\nАдрес: <code>${escapeTelegramHtml(String(payment.pay_to_address || '—'))}</code>\nMemo: <code>${escapeTelegramHtml(String(payment.memo || '—'))}</code>`;
  for (const adminId of adminIds) {
    await sendTelegramMessage(adminId, details, { reply_markup: { inline_keyboard: [[{ text: '🔄 Проверить оплату', callback_data: `mystars:check:${order.id}` }], [{ text: '❌ Отменить заказ', callback_data: `mystars:cancel:${order.id}` }]] } });
  }
}

async function notifyGiftRecipient(order, knownUser = null) {
  if (order.notificationSentAt) return { sent: true, channel: order.notificationChannel };
  const botLink = `https://t.me/${TELEGRAM_BOT_USERNAME}?start=gift_${encodeURIComponent(order.id)}`;
  const text = `🎁 <b>Вам анонимно подарили подарок!</b>\n\nВам отправили: <b>${escapeTelegramHtml(giftDescription(order))}</b>\n\nОтправитель скрыт. Откройте «Послания», чтобы получать анонимные сообщения и узнать, кто отправляет подарки.`;
  const markup = { inline_keyboard: [[{ text: '💌 Открыть «Послания»', url: botLink }], [{ text: '🔎 Узнать кто · 7 ₽', callback_data: 'pay:choose:reveal' }, { text: '♛ Тарифы', callback_data: 'pay:choose:vip' }]] };
  // Do not wake or load the userbot for recipients who already started the
  // bot. Bot API delivery is sufficient and avoids unnecessary MTProto work.
  const recipient = knownUser || [...users.values()].find((candidate) => identityFor(candidate, 'telegram')?.username?.toLowerCase() === order.username);
  if (!(await telegramBotChatAvailable(recipient))) {
    const userbotResult = await telegramUserbot.notify({
      username: order.username,
      text,
      botUrl: botLink,
      orderId: order.id,
      gift: giftDescription(order)
    });
    if (userbotResult.sent) {
      order.notificationSentAt = new Date().toISOString();
      order.notificationChannel = 'userbot';
      order.notificationStatus = 'sent';
      schedulePersist();
      return { sent: true, channel: 'userbot' };
    }
  }

  // If the user has already opened the bot, or the userbot is unavailable,
  // retain the direct Bot API fallback.
  if (recipient && telegramChatId(recipient)) {
    const result = await sendTelegramMessage(telegramChatId(recipient), text, { reply_markup: markup });
    if (result.sent) {
      order.notificationSentAt = new Date().toISOString();
      order.notificationChannel = 'telegram-bot';
      order.notificationStatus = 'sent';
      schedulePersist();
      return { sent: true, channel: 'telegram-bot' };
    }
  }

  order.notificationStatus = 'pending_userbot';
  schedulePersist();
  return { sent: false, channel: null };
}

async function refundGiftBalance(order) {
  if (!order || order.balanceRefundedAt || !order.balancePriceRub) return false;
  const user = order.userId && users.get(order.userId);
  if (!user) return false;
  user.balanceRub = Number(user.balanceRub || 0) + Number(order.balancePriceRub);
  order.balanceRefundedAt = new Date().toISOString();
  schedulePersist();
  return true;
}

async function deliverUserbotGift(order, selectedOffer = null) {
  if (order.giftDeliveryStatus === 'delivered') return order;
  if (!telegramUserbot.isReady) throw new Error('Telegram userbot is not ready to send the gift');
  const gift = {
    type: order.type,
    username: order.username,
    giftId: order.giftId,
    quantity: order.quantity,
    months: order.months
  };
  const offer = selectedOffer || await telegramUserbot.getGiftOffer(gift);
  if (order.giftOfferKey && order.giftOfferKey !== giftOfferKey(offer)) {
    throw new Error('Цена или выбранная опция Telegram изменилась. Повторите проверку.');
  }
  const requiredStars = Number(order.giftStarsCost || offer.costStars || order.quantity || 0);
  const availableStars = await telegramUserbot.getStarsBalance();
  if (availableStars < requiredStars) {
    order.giftDeliveryStatus = 'waiting_userbot_stars';
    order.notificationStatus = 'waiting_userbot_stars';
    schedulePersist();
    throw new Error(`Telegram userbot has ${availableStars} Stars; ${requiredStars} are required`);
  }
  await telegramUserbot.sendGift({
    gift,
    offer,
    message: order.giftMessage || telegramUserbotGiftPromo()
  });
  order.giftDeliveryStatus = 'delivered';
  order.deliveredAt = new Date().toISOString();
  order.notificationStatus = 'sent';
  schedulePersist();
  return order;
}

async function syncMyStarsOrder(order) {
  const remote = await mystarsRequest(`/v1/orders/${encodeURIComponent(order.remoteOrderId)}`);
  order.remoteStatus = remote.status;
  order.remoteOrder = remote;
  if (remote.status === 'delivered' && !order.deliveredAt) {
    if (order.deliveryMode === 'userbot_gift') {
      try { await deliverUserbotGift(order); }
      catch (error) {
        order.lastDeliveryError = error.message;
        order.notificationStatus = 'userbot_gift_failed';
        console.error(`[mystars] Star Gift delivery failed for ${order.id}:`, error.message);
      }
    } else {
      order.deliveredAt = new Date().toISOString();
      await notifyGiftRecipient(order);
    }
  }
  if (['failed', 'reversed', 'expired', 'cancelled'].includes(remote.status)) {
    order.failedAt = order.failedAt || new Date().toISOString();
    if (order.paymentMethod === 'balance') await refundGiftBalance(order);
  }
  schedulePersist();
  return order;
}

function mystarsOrderForUser(order, user) {
  return {
    id: order.id,
    username: order.username,
    type: order.type,
    quantity: order.quantity,
    months: order.months,
    giftId: order.giftId || null,
    giftTitle: order.giftTitle || null,
    status: order.giftDeliveryStatus || order.remoteStatus,
    deliveredAt: order.deliveredAt || null,
    notificationStatus: order.notificationStatus || null,
    createdAt: order.createdAt
  };
}

function mystarsQuoteKey(gift, quote) {
  const snapshot = {
    type: gift.type,
    username: gift.username,
    quantity: gift.quantity || null,
    months: gift.months || null,
    payment_currency: gift.payment_currency || null,
    quote
  };
  return createHash('sha256').update(JSON.stringify(snapshot)).digest('hex');
}

async function createMystarsGiftOrder(user, gift) {
  const balancePrice = mystarsBalancePrice(gift);
  if (!balancePrice) throw new Error('Gift prices are not configured');
  if (Number(user.balanceRub || 0) < balancePrice.amount) {
    throw new Error(`Недостаточно средств на балансе: нужно ${balancePrice.amount} ₽`);
  }

  const quote = await getMyStarsQuote(gift);
  const recipient = await checkMyStarsRecipient(gift);
  if (!recipient?.eligible) {
    throw new Error(recipient?.telegram_message || recipient?.reason || 'Получатель не может принять этот подарок');
  }
  if (gift.offerKey && gift.offerKey !== mystarsQuoteKey(gift, quote)) {
    throw new Error('Цена или параметры подарка изменились. Повторите проверку.');
  }

  const localId = `gift-${randomUUID()}`;
  const body = {
    type: gift.type,
    recipient: { username: gift.username },
    payment_currency: gift.payment_currency,
    callback_url: `${new URL(WEB_APP_URL).origin}/webhooks/mystars`
  };
  if (gift.type === 'stars') body.quantity = gift.quantity;
  else body.months = gift.months;
  const remote = await mystarsRequest('/v1/orders', {
    method: 'POST',
    headers: { 'Idempotency-Key': localId },
    body: JSON.stringify(body)
  });

  user.balanceRub = Number(user.balanceRub || 0) - balancePrice.amount;
  const order = {
    id: localId,
    userId: user.id,
    username: gift.username,
    type: gift.type,
    quantity: gift.quantity || null,
    months: gift.months || null,
    payment_currency: gift.payment_currency,
    paymentMethod: 'balance',
    balancePriceRub: balancePrice.amount,
    balanceMarkupPercent: balancePrice.markupPercent,
    quote,
    remoteOrderId: remote.order_id || remote.id,
    remoteStatus: remote.status || 'awaiting_delivery',
    remoteOrder: remote,
    payment: remote.payment || null,
    createdAt: new Date().toISOString(),
    notificationStatus: 'waiting_delivery',
    deliveryMode: 'mystars_direct'
  };
  mystarsOrders.set(order.id, order);
  schedulePersist();
  await notifyMystarsAdmins(order);
  if (order.remoteStatus === 'delivered') await syncMyStarsOrder(order);
  return order;
}

async function createUserbotGiftOrder(user, gift) {
  if (!telegramUserbot.isReady) throw new Error('Telegram userbot is not configured for gifts');
  const offer = await telegramUserbot.getGiftOffer(gift);
  if (gift.offerKey && gift.offerKey !== giftOfferKey(offer)) throw new Error('Цена или выбранная опция Telegram изменилась. Повторите проверку.');
  const balancePrice = userbotGiftBalancePrice(offer, gift);
  if (!balancePrice) throw new Error('Gift prices are not configured');
  if (Number(user.balanceRub || 0) < balancePrice.amount) throw new Error(`Недостаточно средств на балансе: нужно ${balancePrice.amount} ₽`);

  const localId = `gift-${randomUUID()}`;
  const order = {
    id: localId,
    userId: user.id,
    username: gift.username,
    type: gift.type,
    giftId: gift.giftId || null,
    giftTitle: offer.title,
    quantity: gift.type === 'stars' ? gift.quantity : (gift.type === 'star_gift' ? offer.giftStars : null),
    months: gift.months || null,
    giftStarsCost: offer.costStars,
    giftOfferKey: giftOfferKey(offer),
    paymentMethod: 'balance',
    balancePriceRub: balancePrice.amount,
    balanceMarkupPercent: balancePrice.markupPercent,
    giftMessage: telegramUserbotGiftPromo(),
    deliveryMode: 'userbot_gift',
    createdAt: new Date().toISOString(),
    notificationStatus: 'processing'
  };

  const availableStars = await telegramUserbot.getStarsBalance();
  if (availableStars < offer.costStars && gift.type !== 'star_gift') {
    throw new Error(`Telegram userbot has ${availableStars} Stars; direct ${gift.type === 'premium' ? 'Premium' : 'Stars'} delivery requires ${offer.costStars} Stars`);
  }
  if (availableStars >= offer.costStars) {
    user.balanceRub = Number(user.balanceRub || 0) - balancePrice.amount;
    mystarsOrders.set(order.id, order);
    schedulePersist();
    try {
      await deliverUserbotGift(order, offer);
    } catch (error) {
      order.lastDeliveryError = error.message;
      order.notificationStatus = 'userbot_gift_failed';
      await refundGiftBalance(order);
      throw error;
    }
    return order;
  }

  const userbotUsername = await telegramUserbot.getUsername();
  const topupQuantity = Math.max(50, Math.ceil((offer.costStars - availableStars) / 50) * 50);
  const topupGift = { type: 'stars', username: userbotUsername, quantity: topupQuantity, payment_currency: MYSTARS_PAYMENT_CURRENCY };
  const [quote, recipient] = await Promise.all([getMyStarsQuote(topupGift), checkMyStarsRecipient(topupGift)]);
  if (!recipient.eligible) throw new Error('The Telegram userbot account cannot receive Stars');
  const remote = await mystarsRequest('/v1/orders', {
    method: 'POST',
    headers: { 'Idempotency-Key': `${localId}:userbot-topup` },
    body: JSON.stringify({
      type: 'stars',
      recipient: { username: userbotUsername },
      quantity: topupQuantity,
      payment_currency: MYSTARS_PAYMENT_CURRENCY,
      callback_url: `${new URL(WEB_APP_URL).origin}/webhooks/mystars`
    })
  });
  order.userbotUsername = userbotUsername;
  order.userbotStarsBefore = availableStars;
  order.userbotTopupQuantity = topupQuantity;
  order.quote = quote;
  order.remoteOrderId = remote.order_id || remote.id;
  order.remoteStatus = remote.status || 'awaiting_payment';
  order.remoteOrder = remote;
  order.payment = remote.payment || null;
  order.notificationStatus = 'waiting_userbot_topup';
  user.balanceRub = Number(user.balanceRub || 0) - balancePrice.amount;
  mystarsOrders.set(order.id, order);
  schedulePersist();
  await notifyMystarsAdmins(order);
  return order;
}

function userInboxMessages(user) {
  const linkIds = new Set([...publicLinks.values()].filter((link) => link.userId === user.id).map((link) => link.id));
  return [...messages.values()]
    .filter((message) => linkIds.has(message.publicLinkId))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

async function sendRevealPicker(user, chatId) {
  const inbox = userInboxMessages(user).slice(0, 10);
  if (!inbox.length) {
    return sendTelegramMessage(chatId, '🔎 Пока нет посланий, для которых можно открыть отправителя. Сначала поделитесь своей персональной ссылкой.', { reply_markup: botMenuKeyboard(user.language) });
  }
  const lines = inbox.map((message, index) => `${index + 1}. «${escapeTelegramHtml(String(message.text).slice(0, 90))}${String(message.text).length > 90 ? '…' : ''}»`).join('\n');
  const keyboard = inbox.map((message, index) => [{ text: `🔓 ${index + 1}. Открыть за 7 ₽`, callback_data: `pay:choose:reveal:${message.id}` }]);
  keyboard.push([{ text: `💌 ${botText(user.language, 'openApp')}`, web_app: { url: buildWebAppUrl() } }]);
  return sendTelegramMessage(chatId, `<b>🔎 Выберите послание</b>\n\nВыберите сообщение, для которого хотите проверить отправителя:\n\n${lines}\n\nСтоимость проверки — 7 ₽ за одно послание.`, { reply_markup: { inline_keyboard: keyboard } });
}

function dailyKeyboard(language) {
  return { inline_keyboard: [
    [{ text: `🔓 ${botText(language, 'reveal')}`, callback_data: 'pay:choose:reveal' }, { text: `♛ ${botText(language, 'vip')}`, callback_data: 'pay:choose:vip' }],
    [{ text: `💌 ${botText(language, 'openApp')}`, web_app: { url: buildWebAppUrl() } }]
  ] };
}

function isTelegramAdmin(chatId) {
  const admins = new Set(TELEGRAM_ADMIN_IDS.split(',').map((id) => id.trim()).filter(Boolean));
  return admins.has(String(chatId));
}

function getTelegramUser(message, telegramUser = message.from) {
  const chatId = message.chat?.id || telegramUser?.id;
  const providerId = String(telegramUser?.id || chatId);
  const user = completeAuth('telegram', providerId, {
    displayName: [telegramUser?.first_name, telegramUser?.last_name].filter(Boolean).join(' ') || 'Telegram user',
    username: telegramUser?.username || null,
    language: null
  }).user;
  const identity = userIdentities(user).find((candidate) => candidate.provider === 'telegram' && String(candidate.providerUserId) === providerId);
  if (identity) identity.botStartedAt = identity.botStartedAt || new Date().toISOString();
  schedulePersist();
  return user;
}

function telegramChatId(user) {
  return identityFor(user, 'telegram')?.providerUserId;
}

function telegramBotIdentityFor(user) {
  if (!user) return null;
  return userIdentities(user).find((identity) => identity.provider === 'telegram'
    && !isTelegramBotIdentity(identity)
    && identity.botStartedAt);
}

function recipientHasStartedTelegramBot(user) {
  return Boolean(telegramBotIdentityFor(user));
}

async function telegramBotChatAvailable(user) {
  if (!user || !TELEGRAM_BOT_TOKEN) return false;
  if (recipientHasStartedTelegramBot(user)) return true;
  const chatId = telegramChatId(user);
  if (!chatId) return false;
  try {
    await telegramRequest('getChat', { chat_id: chatId });
    const identity = identityFor(user, 'telegram');
    if (identity) identity.botStartedAt = identity.botStartedAt || new Date().toISOString();
    schedulePersist();
    return true;
  } catch {
    return false;
  }
}

async function sendBotMenu(user, chatId, text = null, { withBanner = false, recipientSlug = user.activeRecipientSlug || null } = {}) {
  const language = user.language || 'ru';
  const caption = text || `${botText(language, 'welcome')}\n\n${botText(language, 'menuHint')}`;
  const authToken = issueWebAuthToken(user);
  const options = { reply_markup: botMenuKeyboard(language, recipientSlug, authToken) };
  return withBanner ? sendTelegramPhoto(chatId, caption, options) : sendTelegramMessage(chatId, caption, options);
}

async function sendStartLanguage(chatId, language = 'ru', user = null) {
  const caption = language === 'en'
    ? '💌 Welcome to Poslaniya\n\nAnonymous messages, warm words and honest thoughts in one place.\n\nChoose your language:'
    : '💌 Добро пожаловать в «Послания»\n\nАнонимные сообщения, тёплые слова и честные мысли в одном месте.\n\nВыберите язык:';
  const keyboard = languageKeyboard();
  if (user) keyboard.inline_keyboard.push([{ text: `💌 ${botText(language, 'openApp')}`, web_app: { url: buildWebAppUrl({ auth: issueWebAuthToken(user) }) } }]);
  return sendTelegramPhoto(chatId, caption, { reply_markup: keyboard });
}

async function answerCallback(callbackId, text = '') {
  if (!TELEGRAM_BOT_TOKEN) return;
  await telegramRequest('answerCallbackQuery', { callback_query_id: callbackId, text }).catch(() => {});
}

async function sendAdminPanel(chatId) {
  return sendTelegramMessage(chatId, botText('ru', 'admin'), { reply_markup: { inline_keyboard: [[{ text: '📥 Заказы пополнения', callback_data: 'admin:topups' }], [{ text: 'Статистика', callback_data: 'admin:stats' }], [{ text: 'Создать рассылку', callback_data: 'admin:broadcast' }], [{ text: 'Пользователи', callback_data: 'admin:users' }]] } });
}

function paymentStatusLabel(status) {
  return ({ manual_pending: 'ожидает чек', pending: 'ожидает оплату', paid: 'оплачен', failed: 'ошибка', rejected: 'отклонён' })[status] || status || 'unknown';
}

async function sendAdminTopups(chatId) {
  const topups = [...payments.values()]
    .filter((payment) => payment.purpose === 'balance')
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 20);
  if (!topups.length) {
    return sendTelegramMessage(chatId, '📥 <b>Заказы пополнения</b>\n\nПока заказов нет.', { reply_markup: { inline_keyboard: [[{ text: '← Админ-панель', callback_data: 'admin:home' }]] } });
  }
  const lines = topups.map((payment, index) => {
    const user = payment.userId ? users.get(payment.userId) : null;
    const username = telegramUsernameForDisplay(user);
    const owner = username ? `@${username}` : String(payment.userId || 'без пользователя').slice(-12);
    const errorLine = payment.error ? `\n   Ошибка: ${escapeTelegramHtml(payment.error)}` : '';
    return `${index + 1}. <code>${escapeTelegramHtml(payment.id.slice(-8))}</code> — <b>${escapeTelegramHtml(String(payment.amount))} ₽</b>\n   ${escapeTelegramHtml(paymentProviderLabels[payment.provider] || payment.provider)} · ${escapeTelegramHtml(paymentStatusLabel(payment.status))} · ${escapeTelegramHtml(owner)}${errorLine}`;
  }).join('\n');
  const keyboard = [];
  for (const payment of topups) {
    if (payment.provider === 'sbp' && payment.status === 'manual_pending' && payment.receipt) {
      keyboard.push([{ text: `✅ Одобрить ${payment.amount} ₽`, callback_data: `sbp:approve:${payment.id}` }, { text: `❌ Отклонить ${payment.amount} ₽`, callback_data: `sbp:reject:${payment.id}` }]);
    }
  }
  keyboard.push([{ text: '🔄 Обновить', callback_data: 'admin:topups' }, { text: '← Админ-панель', callback_data: 'admin:home' }]);
  return sendTelegramMessage(chatId, `📥 <b>Заказы пополнения</b>\n\n${lines}`, { reply_markup: { inline_keyboard: keyboard } });
}

async function sendAdminBroadcast(chatId, message) {
  const recipients = [...users.values()].filter((user) => telegramChatId(user) && telegramChatId(user) !== String(chatId));
  let delivered = 0;
  for (const user of recipients) {
    try {
      await telegramRequest('copyMessage', { chat_id: telegramChatId(user), from_chat_id: chatId, message_id: message.message_id, reply_markup: dailyKeyboard(user.language || 'ru') });
      delivered += 1;
    } catch (error) {
      console.error('[admin broadcast] failed:', error.message);
    }
  }
  return delivered;
}

const adminBroadcastMode = new Set();

function isBotOnlyTelegramUser(user) {
  if (!user) return false;
  const identities = userIdentities(user).filter((identity) => identity.provider === 'telegram');
  return identities.length > 0 && identities.every((identity) => isTelegramBotIdentity(identity));
}

function telegramIdentityMatches(user, providerId, username = '') {
  const normalizedUsername = normalizeTelegramUsername(username);
  return userIdentities(user).some((identity) => {
    if (identity.provider !== 'telegram') return false;
    const sameId = providerId && String(identity.providerUserId) === String(providerId)
      && (!telegramBotUserId || String(providerId) !== String(telegramBotUserId));
    const sameUsername = normalizedUsername && normalizeTelegramUsername(identity.username) === normalizedUsername;
    return Boolean(sameId || (sameUsername && !isTelegramBotIdentity(identity)));
  });
}

function sbpPaymentBelongsToUser(payment, user, message) {
  if (!payment || !user) return false;
  const chatId = message?.chat?.id || message?.from?.id;
  if (payment.sbpChatId && chatId && String(payment.sbpChatId) === String(chatId)) return true;
  if (payment.telegramChatId && chatId && String(payment.telegramChatId) === String(chatId)) return true;
  if (payment.userId === user.id) return true;
  const paymentUser = users.get(payment.userId);
  if (isBotOnlyTelegramUser(paymentUser)) return Boolean(chatId && (!telegramBotUserId || String(chatId) !== String(telegramBotUserId)));
  return telegramIdentityMatches(paymentUser, message?.from?.id || chatId, message?.from?.username || user.username);
}

function pendingSbpPaymentForUser(user, chatId = null) {
  return [...payments.values()]
    .filter((payment) => payment.provider === 'sbp'
      && payment.status === 'manual_pending'
      && payment.userId === user.id
      && (!payment.sbpChatId || !chatId || String(payment.sbpChatId) === String(chatId)))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0] || null;
}

async function notifySbpAdmins(payment, message) {
  const adminIds = TELEGRAM_ADMIN_IDS.split(',').map((id) => id.trim()).filter(Boolean);
  for (const adminId of adminIds) {
    await sendTelegramMessage(adminId, `🏦 <b>Новая проверка СБП</b>\n\nПлатёж: <code>${escapeTelegramHtml(payment.id)}</code>\nСумма: <b>${payment.amount} ₽</b>\nПользователь: <code>${escapeTelegramHtml(String(payment.userId || 'unknown'))}</code>`, { reply_markup: { inline_keyboard: [[{ text: '✅ Одобрить', callback_data: `sbp:approve:${payment.id}` }, { text: '❌ Отклонить', callback_data: `sbp:reject:${payment.id}` }]] } });
    try {
      await telegramRequest('copyMessage', { chat_id: adminId, from_chat_id: message.chat.id, message_id: message.message_id });
    } catch (error) {
      console.error('[sbp] receipt copy failed:', error.message);
    }
  }
}

async function handleTelegramCallback(callback) {
  const chatId = callback.message?.chat?.id;
  const data = callback.data || '';
  const user = callback.message && callback.from?.id ? getTelegramUser(callback.message, callback.from) : null;
  if (!user || !chatId) return answerCallback(callback.id);
  if (data.startsWith('mystars:')) {
    if (!isTelegramAdmin(chatId)) return answerCallback(callback.id, botText(user.language, 'noAccess'));
    const [, action, orderId] = data.split(':');
    const order = mystarsOrders.get(orderId);
    if (!order) return answerCallback(callback.id, 'Заказ не найден');
    try {
      if (action === 'cancel') {
        const remote = await mystarsRequest(`/v1/orders/${encodeURIComponent(order.remoteOrderId)}/cancel`, { method: 'POST' });
        order.remoteStatus = remote.status || 'cancelled';
        order.remoteOrder = remote;
        schedulePersist();
        await answerCallback(callback.id, 'Заказ отменён');
        return sendTelegramMessage(chatId, `❌ Заказ ${escapeTelegramHtml(order.id)} отменён.`);
      }
      const synced = await syncMyStarsOrder(order);
      await answerCallback(callback.id, `Статус: ${synced.remoteStatus}`);
      return sendTelegramMessage(chatId, `🔄 ${escapeTelegramHtml(giftDescription(order))} для @${escapeTelegramHtml(order.username)}\nСтатус MyStars: <b>${escapeTelegramHtml(synced.remoteStatus || 'unknown')}</b>${synced.notificationStatus === 'pending_userbot' ? '\n\nПолучатель ещё не уведомлён: не настроен userbot или пользователь не найден.' : ''}`);
    } catch (error) {
      await answerCallback(callback.id, 'Не удалось обновить статус');
      return sendTelegramMessage(chatId, `MyStars: ${escapeTelegramHtml(error.message)}`);
    }
  }
  if (data.startsWith('sbp:')) {
    if (!isTelegramAdmin(chatId)) return answerCallback(callback.id, botText(user.language, 'noAccess'));
    const [, action, paymentId] = data.split(':');
    const payment = payments.get(paymentId);
    if (!payment || payment.provider !== 'sbp' || payment.status !== 'manual_pending' || !payment.receipt) return answerCallback(callback.id, 'Заявка уже обработана или чек не найден');
    if (action === 'approve') {
      applyPaidPayment(payment);
      await answerCallback(callback.id, 'Пополнение одобрено');
      if (payment.userId && users.has(payment.userId)) await notifyUser(users.get(payment.userId), payment.purpose === 'balance'
        ? `✅ Пополнение на ${payment.amount} ₽ подтверждено.`
        : `✅ Оплата на ${payment.amount} ₽ подтверждена.`);
      return sendTelegramMessage(chatId, `✅ Платёж ${escapeTelegramHtml(payment.id)} одобрен.`);
    }
    if (action === 'reject') {
      payment.status = 'failed';
      payment.rejectedAt = new Date().toISOString();
      schedulePersist();
      await answerCallback(callback.id, 'Платёж отклонён');
      if (payment.userId && users.has(payment.userId)) await notifyUser(users.get(payment.userId), `❌ Не удалось подтвердить пополнение на ${payment.amount} ₽.`);
      return sendTelegramMessage(chatId, `❌ Платёж ${escapeTelegramHtml(payment.id)} отклонён.`);
    }
  }
  if (data.startsWith('lang:')) {
    user.language = data.slice(5) === 'en' ? 'en' : 'ru';
    schedulePersist();
    await answerCallback(callback.id, user.language === 'en' ? 'English selected' : 'Язык выбран');
    return sendBotMenu(user, chatId);
  }
  if (data === 'message:choose') {
    user.awaitingMessageRecipient = true;
    delete user.awaitingDirectMessageSlug;
    schedulePersist();
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, '✍️ Кому отправить послание? Напишите Telegram @username получателя.', { reply_markup: { force_reply: true, input_field_placeholder: '@username получателя', selective: true } });
  }
  if (data === 'menu:link') {
    const link = ensurePublicLink(user);
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, `${botText(user.language, 'myLink')}:\n${new URL(WEB_APP_URL).origin}/?ref=${encodeURIComponent(link.slug)}\n\n${profileInstructions(user.language, user, 'telegram')}`,  { reply_markup: { inline_keyboard: [[{ text: `💌 ${botText(user.language, 'openApp')}`, web_app: { url: buildWebAppUrl({ ref: link.slug }) } }], [{ text: '← Меню', callback_data: 'menu:home' }]] } });
  }
  if (data === 'menu:instructions') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, profileInstructions(user.language, user, 'telegram'), { reply_markup: { inline_keyboard: [[{ text: `🔗 ${botText(user.language, 'myLink')}`, callback_data: 'menu:link' }], [{ text: '← Меню', callback_data: 'menu:home' }]] } });
  }
  if (data === 'menu:daily') {
    const text = randomMessage(user.language);
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, dailyAnonymousText(user.language, text), { reply_markup: dailyKeyboard(user.language) });
  }
  if (data === 'menu:settings') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, `${botText(user.language, 'settings')}\n\n${botText(user.language, 'daily')}: ${user.dailyEnabled === false ? 'OFF' : 'ON'}`, { reply_markup: { inline_keyboard: [[{ text: user.dailyEnabled === false ? '▶ Включить daily' : '⏸ Выключить daily', callback_data: 'menu:toggle_daily' }], [{ text: botText(user.language, 'language'), callback_data: 'menu:language' }], [{ text: '← Меню', callback_data: 'menu:home' }]] } });
  }
  if (data === 'menu:toggle_daily') {
    user.dailyEnabled = user.dailyEnabled === false;
    retentionSettings.set(user.id, { dailyEnabled: user.dailyEnabled, updatedAt: new Date().toISOString() });
    schedulePersist();
    await answerCallback(callback.id, user.dailyEnabled ? botText(user.language, 'dailyOn') : botText(user.language, 'dailyOff'));
    return sendBotMenu(user, chatId, user.dailyEnabled ? botText(user.language, 'dailyOn') : botText(user.language, 'dailyOff'));
  }
  if (data === 'menu:language') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, botText(user.language, 'chooseLanguage'), { reply_markup: languageKeyboard() });
  }
  if (data === 'menu:help') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, '💌 Отправьте свою ссылку друзьям. Новые сообщения появятся в ящике и в боте.\n\n✍️ Нажмите «Написать послание» или используйте /message, чтобы выбрать получателя. Можно отправить текст и медиа.\n\nVIP: 20 ₽ / 7 дней. Раскрытие отправителя: 7 ₽.', { reply_markup: botMenuKeyboard(user.language) });
  }
  if (data === 'menu:home' || data === 'app') {
    if (data === 'menu:home' && (user.awaitingDirectMessageSlug || user.awaitingMessageRecipient)) {
      delete user.awaitingDirectMessageSlug;
      delete user.awaitingMessageRecipient;
      schedulePersist();
    }
    await answerCallback(callback.id);
    return sendBotMenu(user, chatId);
  }
  if (data.startsWith('block:')) {
    const messageId = data.slice('block:'.length);
    const message = messages.get(messageId);
    const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user.id);
    if (!ownerLink) return answerCallback(callback.id, 'Послание не найдено');
    if (!message.sender?.fingerprint) return answerCallback(callback.id, 'Для этого послания нет данных для блокировки');
    blockSender(user.id, message.sender.fingerprint);
    await answerCallback(callback.id, 'Отправитель заблокирован');
    return sendTelegramMessage(chatId, '🚫 Отправитель заблокирован. Новые послания с этого устройства больше не будут приниматься.', { reply_markup: botMenuKeyboard(user.language) });
  }
  if (data === 'gift:menu') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, `🎁 <b>${botText(user.language, 'gift')}</b>\n\nВыберите получателя по @username и отправьте ему анонимно Telegram Stars или Premium.`, { reply_markup: { inline_keyboard: [[{ text: 'Открыть форму подарка', web_app: { url: buildWebAppUrl({ payment: 'gift' }) } }]] } });
  }
  if (data === 'topup:menu') {
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, `💳 <b>${botText(user.language, 'topup')}</b>\n\nВыберите сумму пополнения баланса:`, { reply_markup: topupAmountKeyboard() });
  }
  if (data.startsWith('topup:amount:')) {
    const amount = Number(data.split(':')[2]);
    if (!Number.isInteger(amount) || amount < 10 || amount > 100000) return answerCallback(callback.id, 'Некорректная сумма');
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, `Выберите способ оплаты для пополнения на <b>${amount} ₽</b>:`, { reply_markup: topupMethodKeyboard(amount) });
  }
  if (data.startsWith('topup:method:')) {
    const [, , provider, amountText] = data.split(':');
    const amount = Number(amountText);
    if (!paymentProviderLabels[provider] || !Number.isInteger(amount) || amount < 10 || amount > 100000) return answerCallback(callback.id, 'Некорректный платёж');
    try {
      const payment = await createPaymentCheckout(user, { provider, purpose: 'balance', amount });
      await answerCallback(callback.id, 'Платёж создан');
      return sendPaymentResult(chatId, payment, user.language || 'ru');
    } catch (error) {
      await answerCallback(callback.id, 'Способ оплаты пока не настроен');
      return sendTelegramMessage(chatId, `Не удалось создать платёж: ${escapeTelegramHtml(error.message)}`, { reply_markup: topupAmountKeyboard() });
    }
  }
  if (data === 'pay:choose:reveal') {
    await answerCallback(callback.id);
    return sendRevealPicker(user, chatId);
  }
  if (data.startsWith('pay:choose:')) {
    const [, , plan] = data.split(':');
    if (!['vip', 'reveal'].includes(plan)) return answerCallback(callback.id);
    const messageId = data.split(':')[3] || null;
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, botText(user.language, 'paymentTitle'), { reply_markup: paymentKeyboard(user.language, plan, messageId === '-' ? null : messageId, user) });
  }
  if (data.startsWith('pay:method:')) {
    const [, , provider, plan, messageId = '-'] = data.split(':');
    if (!paymentProviderLabels[provider] || !['vip', 'reveal'].includes(plan)) return answerCallback(callback.id, 'Некорректный платёж');
    try {
      const payment = await createPaymentCheckout(user, { provider, purpose: 'plan', plan, amount: plan === 'vip' ? 20 : 7, messageId: messageId === '-' ? null : messageId });
      await answerCallback(callback.id, 'Платёж создан');
      return sendPaymentResult(chatId, payment, user.language || 'ru');
    } catch (error) {
      await answerCallback(callback.id, 'Способ оплаты пока не настроен');
      return sendTelegramMessage(chatId, `Не удалось создать платёж: ${escapeTelegramHtml(error.message)}`, { reply_markup: paymentKeyboard(user.language, plan, messageId === '-' ? null : messageId, user) });
    }
  }
  if (data === 'admin:topups') {
    if (!isTelegramAdmin(chatId)) return answerCallback(callback.id, botText(user.language, 'noAccess'));
    await answerCallback(callback.id);
    return sendAdminTopups(chatId);
  }
  if (data === 'admin:stats' || data === 'admin:users' || data === 'admin:broadcast') {
    if (!isTelegramAdmin(chatId)) return answerCallback(callback.id, botText(user.language, 'noAccess'));
    if (data === 'admin:broadcast') {
      adminBroadcastMode.add(String(chatId));
      await answerCallback(callback.id);
      return sendTelegramMessage(chatId, botCopy.ru.broadcastAsk);
    }
    const botUsers = [...users.values()].filter((candidate) => telegramChatId(candidate));
    const activeDaily = botUsers.filter((candidate) => candidate.dailyEnabled !== false).length;
    await answerCallback(callback.id);
    return sendTelegramMessage(chatId, data === 'admin:stats' ? `📊 Статистика\n\nПользователей бота: ${botUsers.length}\nАктивные daily: ${activeDaily}\nПосланий в общей базе: ${messages.size}\nПерсональных ссылок: ${publicLinks.size}` : `Пользователей бота: ${botUsers.length}`, { reply_markup: { inline_keyboard: [[{ text: '← Админ-панель', callback_data: 'admin:home' }]] } });
  }
  if (data === 'admin:home') {
    if (!isTelegramAdmin(chatId)) return answerCallback(callback.id, botText(user.language, 'noAccess'));
    await answerCallback(callback.id);
    return sendAdminPanel(chatId);
  }
  return answerCallback(callback.id);
}

function isAllowedTelegramGroup(chatId) {
  return TELEGRAM_GROUPS_ENABLED && (!TELEGRAM_GROUP_CHAT_IDS.length || TELEGRAM_GROUP_CHAT_IDS.includes(String(chatId)));
}

function telegramCommand(text) {
  const match = String(text || '').trim().match(/^\/(start|app|link|daily|help)(?:@[^\s]+)?(?:\s|$)/i);
  return match?.[1].toLowerCase() || null;
}

async function handleTelegramGroupMember(update) {
  const change = update.my_chat_member;
  const chat = change?.chat;
  const status = change?.new_chat_member?.status;
  const previousStatus = change?.old_chat_member?.status;
  if (!chat || !['group', 'supergroup'].includes(chat.type) || !isAllowedTelegramGroup(chat.id)) return;
  const joined = ['member', 'administrator'].includes(status) && !['member', 'administrator'].includes(previousStatus);
  if (!joined) return;
  return sendTelegramMessage(chat.id, `💌 <b>Послания здесь!</b>\n\nЯ помогу участникам делиться анонимными посланиями и открывать свой ящик. Используйте /app, /link, /daily или /help.`, { reply_markup: { inline_keyboard: [[{ text: 'Открыть Web App 💌', web_app: { url: buildWebAppUrl() } }]] } });
}

async function handleTelegramGroupMessage(message) {
  const chatId = message.chat.id;
  if (!isAllowedTelegramGroup(chatId)) return;
  const command = telegramCommand(message.text);
  if (!command) return;
  const user = getTelegramUser(message);
  if (command === 'daily') {
    return sendTelegramMessage(chatId, `🎲 <b>${botText(user.language || 'ru', 'daily')}</b>\n\n${randomMessage(user.language || 'ru')}`, { reply_markup: { inline_keyboard: [[{ text: 'Открыть Web App 💌', web_app: { url: buildWebAppUrl() } }]] } });
  }
  if (command === 'link') {
    const link = ensurePublicLink(user);
    return sendTelegramMessage(chatId, `🔗 Ваша персональная ссылка:\n<a href="${escapeTelegramHtml(`${new URL(WEB_APP_URL).origin}/?ref=${encodeURIComponent(link.slug)}`)}">${escapeTelegramHtml(`${new URL(WEB_APP_URL).origin}/?ref=${encodeURIComponent(link.slug)}`)}</a>`, { reply_markup: { inline_keyboard: [[{ text: 'Открыть мой ящик 💌', web_app: { url: buildWebAppUrl({ ref: link.slug }) } }]] } });
  }
  if (command === 'help') {
    return sendTelegramMessage(chatId, '💌 Команды группы:\n/start — приветствие\n/app — открыть Web App\n/link — получить персональную ссылку\n/daily — послание дня\n/help — эта справка', { reply_markup: { inline_keyboard: [[{ text: 'Открыть Web App 💌', web_app: { url: buildWebAppUrl() } }]] } });
  }
  return sendTelegramMessage(chatId, '💌 Откройте свой ящик в Web App.', { reply_markup: { inline_keyboard: [[{ text: 'Открыть Web App 💌', web_app: { url: buildWebAppUrl() } }]] } });
}

function directMessagePrompt(recipientSlug) {
  const link = resolvePublicLink(recipientSlug);
  const owner = link && users.get(link.userId);
  const ownerName = owner?.displayName || telegramUsernameForDisplay(owner) || `@${recipientSlug}`;
  return `💌 Сейчас ты можешь написать послание человеку.\n\n✍️ <b>Напиши сюда всё, что хочешь ему передать,</b> и когда <b>${escapeTelegramHtml(ownerName)}</b> зайдёт в бот — он получит ваше сообщение, но не будет знать от кого.\n\nОтправить можно фото, видео, 💬 текст, 🔊 голосовые, 📷 видеосообщения (кружки), а также ✨ стикеры.`;
}

async function deliverDirectTelegramMessage(user, recipientSlug, incomingMessage) {
  const link = resolvePublicLink(recipientSlug);
  const cleanText = String(incomingMessage?.text || incomingMessage?.caption || '').trim();
  const media = telegramMediaFromMessage(incomingMessage);
  if (!link || !link.isActive) return { ok: false, reason: 'link_not_found' };
  if (cleanText.length > 500 || (cleanText.length < 3 && !media)) return { ok: false, reason: 'message_length' };
  const providerUserId = telegramChatId(user);
  const messageText = cleanText || telegramMediaLabel(media);
  const message = {
    id: randomUUID(),
    publicLinkId: link.id,
    body: messageText,
    text: messageText,
    caption: cleanText,
    media,
    source: 'telegram-bot',
    senderAvailable: true,
    sender: { fingerprint: `telegram:${providerUserId}`, provider: 'telegram', providerUserId, displayName: user.displayName, username: user.username },
    unread: true,
    saved: false,
    createdAt: new Date().toISOString(),
    time: 'только что',
    mood: 'pink'
  };
  messages.set(message.id, message);
  schedulePersist();
  const owner = users.get(link.userId);
  if (owner) await notifyNewMessage(owner, message);
  return { ok: true, message };
}

async function handleTelegramUpdate(update) {
  if (update.my_chat_member) return handleTelegramGroupMember(update);
  if (update.callback_query) return handleTelegramCallback(update.callback_query);
  const message = update.message;
  if (!message?.chat) return;
  if (['group', 'supergroup'].includes(message.chat.type)) return handleTelegramGroupMessage(message);
  const chatId = message.chat.id;
  const text = message.text || '';
  const user = getTelegramUser(message);
  const revealStartMatch = text.match(/^\/start(?:@[a-z0-9_]+)?\s+reveal_([a-f0-9-]+)$/i);
  if (revealStartMatch) {
    const messageId = revealStartMatch[1];
    const targetMessage = messages.get(messageId);
    const ownerLink = targetMessage && [...publicLinks.values()].find((candidate) => candidate.id === targetMessage.publicLinkId && candidate.userId === user.id);
    if (!targetMessage || !ownerLink || !targetMessage.senderAvailable) {
      return sendTelegramMessage(chatId, '🔎 Для этого послания отправителя нельзя определить.', { reply_markup: botMenuKeyboard(user.language || 'ru') });
    }
    return sendTelegramMessage(chatId, '🔎 <b>Узнать отправителя</b>\n\nВыберите способ оплаты — после подтверждения покажем доступные данные отправителя.\n\nСтоимость: <b>7 ₽</b>.', { reply_markup: paymentKeyboard(user.language || 'ru', 'reveal', messageId, user) });
  }
  const giftStartMatch = text.match(/^\/start\s+gift_(gift-[a-f0-9-]+)$/i);
  if (giftStartMatch) {
    const order = mystarsOrders.get(giftStartMatch[1]);
    const username = normalizeTelegramUsername(message.from?.username || user.username);
    if (!order || (username && username !== order.username)) return sendTelegramMessage(chatId, 'Подарок не найден или ссылка предназначена другому пользователю.');
    try { if (MYSTARS_API_KEY && order.remoteStatus !== 'delivered') await syncMyStarsOrder(order); } catch (error) { console.error('[mystars] gift start sync failed:', error.message); }
    await notifyGiftRecipient(order, user);
    return sendTelegramMessage(chatId, '💌 Добро пожаловать в «Послания»! Здесь можно получать анонимные послания и узнать отправителя за 7 ₽.', { reply_markup: botMenuKeyboard(user.language || 'ru') });
  }
  const sbpStartMatch = text.match(/^\/start(?:@[a-z0-9_]+)?\s+sbp_(pay-[a-f0-9-]+)$/i);
  if (sbpStartMatch) {
    const payment = payments.get(sbpStartMatch[1]);
    if (!payment || payment.provider !== 'sbp' || payment.status !== 'manual_pending' || !sbpPaymentBelongsToUser(payment, user, message)) {
      return sendTelegramMessage(chatId, 'Заявка на СБП не найдена или уже обработана.');
    }
    // Repair legacy records where the Web App and bot created two user rows for
    // the same Telegram account, without allowing another Telegram account to claim it.
    if (payment.userId !== user.id) payment.userId = user.id;
    payment.sbpChatId = String(chatId);
    schedulePersist();
    return sendTelegramMessage(chatId, `Заявка ${escapeTelegramHtml(payment.id)} найдена. Отправьте сюда фото или документ чека после оплаты.`, { reply_markup: { inline_keyboard: [[{ text: '← Меню', callback_data: 'menu:home' }]] } });
  }
  const receipt = message.photo?.at(-1) || message.document;
  if (receipt && !user.awaitingDirectMessageSlug) {
    const payment = pendingSbpPaymentForUser(user, chatId);
    if (!payment) return sendTelegramMessage(chatId, 'Сначала создайте заявку на оплату через СБП в меню «Пополнить баланс».');
    if (payment.receipt) return sendTelegramMessage(chatId, 'Чек по этой заявке уже отправлен. Ожидайте подтверждения оплаты.');
    payment.sbpChatId = String(chatId);
    payment.receipt = { type: message.photo ? 'photo' : 'document', fileId: receipt.file_id, messageId: message.message_id, receivedAt: new Date().toISOString() };
    schedulePersist();
    await notifySbpAdmins(payment, message);
    return sendTelegramMessage(chatId, '✅ Чек отправлен. После подтверждения оплаты баланс будет обновлён.');
  }
  const authMatch = text.match(/^\/start\s+auth_([a-z0-9]+)$/i);
  if (authMatch && pendingAuth.has(authMatch[1])) {
    const auth = pendingAuth.get(authMatch[1]);
    if (auth.provider === 'telegram' && Date.now() - auth.createdAt < 10 * 60 * 1000) {
      authResults.set(authMatch[1], completeAuth('telegram', message.from?.id || chatId, { displayName: user.displayName, username: user.username, language: user.language }));
      pendingAuth.delete(authMatch[1]);
      await sendTelegramMessage(chatId, 'Готово! Авторизация подтверждена. Вернитесь на сайт 💌');
    }
    return;
  }
  if (text === '/cancel' && (user.awaitingDirectMessageSlug || user.awaitingMessageRecipient)) {
    delete user.awaitingDirectMessageSlug;
    delete user.awaitingMessageRecipient;
    schedulePersist();
    return sendBotMenu(user, chatId, 'Ввод послания отменён.');
  }
  if (text === '/message') {
    user.awaitingMessageRecipient = true;
    delete user.awaitingDirectMessageSlug;
    schedulePersist();
    return sendTelegramMessage(chatId, '✍️ Кому отправить послание? Напишите Telegram @username получателя.', { reply_markup: { force_reply: true, input_field_placeholder: '@username получателя', selective: true } });
  }
  const referralMatch = text.match(/^\/start(?:@[a-z0-9_]+)?\s+ref[_-]([^\s]+)$/i);
  if (referralMatch) {
    const referralSlug = referralMatch[1].toLowerCase().replace(/[^a-zа-яё0-9_-]/gi, '');
    if (!referralSlug || !resolvePublicLink(referralSlug)) return sendBotMenu(user, chatId);
    user.activeRecipientSlug = referralSlug;
    user.awaitingDirectMessageSlug = referralSlug;
    delete user.awaitingMessageRecipient;
    schedulePersist();
    return sendTelegramMessage(chatId, directMessagePrompt(referralSlug), { reply_markup: { force_reply: true, input_field_placeholder: 'Текст или медиа послания…', selective: true } });
  }
  if (user.awaitingMessageRecipient && text && !text.startsWith('/')) {
    const requestedRecipient = text.trim().replace(/^@+/, '').toLowerCase();
    // A Telegram username is a valid recipient even when that person has never
    // opened this bot and therefore has no local publicLinks record yet. Keep a
    // local placeholder so the message can be stored and delivered by userbot;
    // completeAuth will attach the real Telegram ID when the recipient starts the bot.
    const recipientLink = resolvePublicLink(requestedRecipient) || ensureTelegramRecipientLink(requestedRecipient);
    if (!recipientLink) return sendTelegramMessage(chatId, 'Не нашёл такого получателя. Напишите его публичный Telegram @username или отмените ввод командой /cancel.');
    user.activeRecipientSlug = recipientLink.slug;
    user.awaitingDirectMessageSlug = recipientLink.slug;
    delete user.awaitingMessageRecipient;
    schedulePersist();
    return sendTelegramMessage(chatId, directMessagePrompt(recipientLink.slug), { reply_markup: { force_reply: true, input_field_placeholder: 'Текст или медиа послания…', selective: true } });
  }
  if (user.awaitingDirectMessageSlug && (text || telegramMediaFromMessage(message))) {
    const directResult = await deliverDirectTelegramMessage(user, user.awaitingDirectMessageSlug, message);
    if (directResult.ok) {
      delete user.awaitingDirectMessageSlug;
      schedulePersist();
      return sendTelegramMessage(chatId, '✅ Послание отправлено анонимно.', { reply_markup: botMenuKeyboard(user.language || 'ru') });
    }
    if (directResult.reason === 'message_length') return sendTelegramMessage(chatId, 'Послание должно содержать от 3 до 500 символов или прикрепите фото, видео, голосовое, кружок или стикер. Попробуйте ещё раз.');
    delete user.awaitingDirectMessageSlug;
    schedulePersist();
    return sendTelegramMessage(chatId, 'Не удалось найти получателя. Откройте актуальную персональную ссылку ещё раз.');
  }
  if (isTelegramAdmin(chatId) && adminBroadcastMode.has(String(chatId)) && text !== '/cancel' && !text.startsWith('/')) {
    adminBroadcastMode.delete(String(chatId));
    const delivered = await sendAdminBroadcast(chatId, message);
    return sendTelegramMessage(chatId, `${botCopy.ru.broadcastDone}: ${delivered}`);
  }
  if (text === '/cancel' && isTelegramAdmin(chatId)) {
    adminBroadcastMode.delete(String(chatId));
    return sendTelegramMessage(chatId, 'Отменено.');
  }
  if (text === '/id') return sendTelegramMessage(chatId, `Telegram ID: ${chatId}`);
  if (text === '/topup' || text === '/balance') return sendTelegramMessage(chatId, `💳 <b>${botText(user.language, 'topup')}</b>\n\nБаланс: <b>${Number(user.balanceRub || 0)} ₽</b>\n\nВыберите сумму:`, { reply_markup: topupAmountKeyboard() });
  if (text === '/admin') return isTelegramAdmin(chatId) ? sendAdminPanel(chatId) : sendTelegramMessage(chatId, botText(user.language, 'noAccess'));
  if (text === '/stats' && isTelegramAdmin(chatId)) {
    const botUsers = [...users.values()].filter((candidate) => telegramChatId(candidate));
    return sendTelegramMessage(chatId, `📊 Статистика\n\nПользователей бота: ${botUsers.length}\nАктивные daily: ${botUsers.filter((candidate) => candidate.dailyEnabled !== false).length}\nПосланий в общей базе: ${messages.size}\nПерсональных ссылок: ${publicLinks.size}`);
  }
  if (text === '/broadcast' && isTelegramAdmin(chatId)) {
    adminBroadcastMode.add(String(chatId));
    return sendTelegramMessage(chatId, botCopy.ru.broadcastAsk);
  }
  if (text === '/start' && !user.language) return sendStartLanguage(chatId, 'ru', user);
  if (text === '/start' || text === '/app') return sendBotMenu(user, chatId, null, { withBanner: text === '/start' });
  if (text === '/settings') return handleTelegramCallback({ id: `settings-${update.update_id}`, data: 'menu:settings', message });
  return sendBotMenu(user, chatId);
}

function addDailyAnonymousMessage(user, text) {
  const link = ensurePublicLink(user);
  const message = {
    id: `daily-${randomUUID()}`,
    publicLinkId: link.id,
    body: text,
    text,
    source: 'daily-anonymous',
    senderAvailable: false,
    sender: { provider: null, providerUserId: null, displayName: 'Аноним', username: null },
    unread: true,
    saved: false,
    createdAt: new Date().toISOString(),
    time: 'сегодня',
    mood: 'lilac'
  };
  messages.set(message.id, message);
  return message;
}

async function runDailyRetentionBroadcast() {
  const dailyDate = new Date().toISOString().slice(0, 10);
  const targets = [...users.values()].filter((user) => user.dailyEnabled !== false && userIdentities(user).length && user.lastDailyMessageDate !== dailyDate);
  let delivered = 0;
  let usersDelivered = 0;
  for (const user of targets) {
    const language = user.language || 'ru';
    const text = randomMessage(language);
    const notification = dailyAnonymousText(language, text);
    let userDelivered = false;
    for (const identity of userIdentities(user)) {
      try {
        if (identity.provider === 'telegram' && isTelegramBotIdentity(identity)) continue;
        const result = identity.provider === 'telegram'
          ? await sendTelegramMessage(identity.providerUserId, notification, { reply_markup: dailyKeyboard(language) })
          : await sendVkMessage(identity.providerUserId, notification.replace(/<[^>]+>/g, ''));
        if (result.sent) {
          delivered += 1;
          userDelivered = true;
        }
      } catch (error) {
        console.error(`[retention] delivery failed for ${user.id}:`, error.message);
      }
    }
    if (userDelivered) {
      addDailyAnonymousMessage(user, text);
      user.lastDailyMessageDate = dailyDate;
      usersDelivered += 1;
    }
  }
  if (usersDelivered) schedulePersist();
  console.log(`[retention] ${new Date().toISOString()} targets=${targets.length} usersDelivered=${usersDelivered} deliveries=${delivered}`);
  return { targets: targets.length, usersDelivered, delivered };
}

function publicConfig() {
  const site = new URL(WEB_APP_URL).origin;
  return {
    siteUrl: site,
    webAppUrl: buildWebAppUrl(),
    telegramUsername: TELEGRAM_BOT_USERNAME,
    telegramUrl: `https://t.me/${TELEGRAM_BOT_USERNAME}`,
    vkGroupId: VK_GROUP_ID,
    vkUrl: `https://vk.me/${VK_GROUP_ID}`,
    defaultRecipientSlug: DEMO_MODE ? demoSlug() : '',
    demoMode: DEMO_MODE,
    paymentMethods: paymentProviderList()
  };
}

async function handleApi(req, res, url) {
  if (req.method === 'OPTIONS') return json(res, 204, {});
  if (req.method === 'GET' && url.pathname === '/api/v1/config') {
    return json(res, 200, publicConfig());
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/plans') {
    return json(res, 200, { plans: [{ id: 'vip', amount: 20, currency: 'RUB', durationDays: 7 }, { id: 'reveal', amount: 7, currency: 'RUB', durationDays: 0 }] });
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/payments/methods') {
    return json(res, 200, { currency: 'RUB', methods: paymentProviderList() });
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/gifts/catalog') {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    try { return json(res, 200, { gifts: await telegramUserbot.getStarGifts() }); }
    catch (error) { return json(res, 503, { error: 'telegram_gifts_unavailable', message: error.message }); }
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/gifts/quote') {
    try {
      const gift = validateGiftRequest(await readBody(req));
      if (gift.type !== 'star_gift') {
        const quote = await getMyStarsQuote(gift);
        const recipient = await checkMyStarsRecipient(gift);
        if (!recipient?.eligible) throw new Error(recipient?.telegram_message || recipient?.reason || 'Получатель не может принять этот подарок');
        const balancePrice = mystarsBalancePrice(gift);
        const title = gift.type === 'stars' ? `${gift.quantity} Telegram Stars` : `Telegram Premium на ${gift.months} мес.`;
        const stars = gift.type === 'stars' ? gift.quantity : 0;
        return json(res, 200, {
          gift: { ...gift, title, stars },
          quote: {
            title,
            stars,
            currency: gift.type === 'stars' ? 'XTR' : null,
            amount: balancePrice?.amount || null,
            option: null
          },
          offerKey: mystarsQuoteKey(gift, quote),
          recipient: { eligible: true, username: gift.username },
          balancePayment: balancePrice ? { amount: balancePrice.amount } : null
        });
      }

      const offer = await telegramUserbot.getGiftOffer(gift);
      const balancePrice = userbotGiftBalancePrice(offer, gift);
      const stars = Number(offer.costStars || offer.giftStars || 0);
      return json(res, 200, {
        gift: { ...gift, title: offer.title, stars },
        quote: {
          title: offer.title,
          stars,
          currency: offer.priceCurrency || 'XTR',
          amount: Number(offer.priceAmount || stars),
          option: offer.option ? { currency: offer.option.currency, stars: Number(offer.option.stars), amount: Number(offer.option.amount) } : null
        },
        offerKey: giftOfferKey(offer),
        recipient: { eligible: true, username: offer.recipient?.username || gift.username },
        balancePayment: balancePrice ? { amount: balancePrice.amount } : null
      });
    } catch (error) {
      const validation = error.message.includes('required') || error.message.includes('between') || error.message.includes('must be');
      const internalPaymentError = /mystars|my\s*stars|api key|payment api/i.test(error.message);
      const message = internalPaymentError ? 'Не удалось проверить цену и получателя. Попробуйте ещё раз позже.' : error.message;
      return json(res, validation ? 422 : 503, { error: 'gift_quote_failed', message });
    }
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/gifts/orders') {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    let gift = null;
    try {
      const body = await readBody(req);
      gift = validateGiftRequest(body);
      const order = gift.type === 'star_gift'
        ? await createUserbotGiftOrder(user, gift)
        : await createMystarsGiftOrder(user, gift);
      return json(res, 201, mystarsOrderForUser(order, user));
    } catch (error) {
      const insufficient = error.message.startsWith('Недостаточно средств');
      const balancePrice = gift ? mystarsBalancePrice(gift) : null;
      const changed = error.message.includes('изменилась') || error.message.includes('изменились');
      const status = insufficient ? 402 : changed ? 409 : error.message.includes('required') || error.message.includes('between') || error.message.includes('must be') || error.message.includes('cannot receive') || error.message.includes('not configured') ? 422 : 503;
      const internalPaymentError = /mystars|my\s*stars|pay_to_address|memo|payment api/i.test(error.message);
      const message = internalPaymentError ? 'Не удалось подготовить подарок. Попробуйте ещё раз позже.' : error.message;
      return json(res, status, { error: insufficient ? 'insufficient_balance' : 'gift_order_failed', message, ...(insufficient ? { balance: Number(user.balanceRub || 0), required: balancePrice?.amount || null } : {}) });
    }
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/gifts/orders') {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    return json(res, 200, { orders: [...mystarsOrders.values()].filter((order) => order.userId === user.id).map((order) => mystarsOrderForUser(order, user)) });
  }
  const giftOrderMatch = url.pathname.match(/^\/api\/v1\/gifts\/orders\/([^/]+)\/refresh$/);
  if (req.method === 'POST' && giftOrderMatch) {
    const user = getUserFromRequest(req);
    const order = mystarsOrders.get(decodeURIComponent(giftOrderMatch[1]));
    if (!user || !order || order.userId !== user.id) return json(res, 404, { error: 'gift_order_not_found' });
    try { await syncMyStarsOrder(order); return json(res, 200, mystarsOrderForUser(order, user)); }
    catch (error) { return json(res, 503, { error: 'mystars_status_failed', message: error.message }); }
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/auth/telegram/token') {
    const body = await readBody(req);
    const result = consumeWebAuthToken(body.token);
    return result ? json(res, 200, result) : json(res, 401, { error: 'auth_token_expired' });
  }
  if (req.method === 'POST' && /^\/api\/v1\/auth\/(telegram|vk)\/start$/.test(url.pathname)) {
    const provider = url.pathname.split('/')[4];
    const challenge = createAuthChallenge(provider);
    return json(res, 200, { ...challenge, expiresIn: 600 });
  }
  if (req.method === 'GET' && /^\/api\/v1\/auth\/(telegram|vk)\/status$/.test(url.pathname)) {
    const challenge = url.searchParams.get('challenge');
    const pending = challenge && pendingAuth.get(challenge);
    if (challenge && authResults.has(challenge)) {
      const result = authResults.get(challenge);
      return json(res, 200, { status: 'authorized', token: result.token, user: userForClient(result.user) });
    }
    if (pending && Date.now() - pending.createdAt < 10 * 60 * 1000) return json(res, 200, { status: 'pending', expiresIn: Math.max(0, 600 - Math.floor((Date.now() - pending.createdAt) / 1000)) });
    return json(res, 404, { status: 'expired' });
  }
  if (req.method === 'POST' && /^\/api\/v1\/auth\/(telegram|vk)\/complete$/.test(url.pathname)) {
    const provider = url.pathname.split('/')[4];
    const body = await readBody(req);
    const authorized = body.challenge && authResults.get(body.challenge);
    if (authorized) return json(res, 200, { token: authorized.token, user: userForClient(authorized.user) });
    // `demo: true` makes the UI preview useful without bot credentials. Disable this
    // fallback in production with DEMO_MODE=false; real users complete via webhook.
    if (body.demo !== true || !DEMO_MODE) return json(res, 409, { error: 'waiting_for_bot_confirmation' });
    const result = completeAuth(provider, body.providerUserId || (provider === 'telegram' ? 'demo_recipient' : 'demo_vk_recipient'), { displayName: provider === 'telegram' ? 'Аня' : (body.displayName || 'VK user'), username: provider === 'telegram' ? 'anya' : null });
    return json(res, 200, { token: result.token, user: userForClient(result.user) });
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/auth/telegram/webapp') {
    const body = await readBody(req);
    const telegramUser = verifyTelegramWebAppInitData(body.initData || req.headers['x-telegram-init-data']);
    if (!telegramUser?.id) return json(res, 401, { error: 'invalid_telegram_webapp_data' });
    const result = completeAuth('telegram', telegramUser.id, { displayName: [telegramUser.first_name, telegramUser.last_name].filter(Boolean).join(' ') || 'Telegram user', username: telegramUser.username || null, photoUrl: telegramUser.photo_url || null });
    return json(res, 200, { token: result.token, user: userForClient(result.user) });
  }
  if (req.method === 'GET' && url.pathname === '/api/v1/me') {
    const user = getUserFromRequest(req);
    return user ? json(res, 200, { user: userForClient(user), retention: retentionSettings.get(user.id), link: ensurePublicLink(user) }) : json(res, 401, { error: 'unauthorized' });
  }
  if (req.method === 'GET' && /^\/api\/v1\/inbox$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    const linkIds = new Set([...publicLinks.values()].filter((link) => link.userId === user.id).map((link) => link.id));
    const inbox = [...messages.values()]
      .filter((message) => linkIds.has(message.publicLinkId))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((message) => messageForOwner(message, user));
    return json(res, 200, { messages: inbox });
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/links') {
    const user = getUserFromRequest(req);
    if (!user) return json(res, 401, { error: 'unauthorized' });
    const body = await readBody(req);
    const link = ensurePublicLink(user, body.slug);
    return json(res, 200, { link: `${new URL(WEB_APP_URL).origin}/?ref=${encodeURIComponent(link.slug)}`, slug: link.slug });
  }
  const publicLinkMatch = url.pathname.match(/^\/api\/v1\/links\/([^/]+)$/);
  if (req.method === 'GET' && publicLinkMatch) {
    const link = resolvePublicLink(decodeURIComponent(publicLinkMatch[1]));
    if (!link || !link.isActive) return json(res, 404, { error: 'link_not_found' });
    const owner = users.get(link.userId);
    return json(res, 200, { slug: link.slug, displayName: owner?.displayName || 'Получатель', welcomeText: 'Оставьте анонимное послание' });
  }
  const publicMessageMatch = url.pathname.match(/^\/api\/v1\/links\/([^/]+)\/messages$/);
  if (req.method === 'POST' && publicMessageMatch) {
    const link = resolvePublicLink(decodeURIComponent(publicMessageMatch[1]));
    const body = await readBody(req);
    const cleanText = String(body.text || '').trim();
    if (!link || !link.isActive) return json(res, 404, { error: 'link_not_found' });
    if (cleanText.length < 3 || cleanText.length > 500) return json(res, 422, { error: 'message_length' });
    const fingerprint = senderFingerprint(req);
    if (isSenderBlocked(link.userId, fingerprint)) return json(res, 403, { error: 'sender_blocked' });
    const telegramUser = verifyTelegramWebAppInitData(req.headers['x-telegram-init-data'] || body.initData);
    const sender = {
      fingerprint,
      provider: telegramUser?.id ? 'telegram' : null,
      providerUserId: telegramUser?.id ? String(telegramUser.id) : null,
      displayName: telegramUser?.first_name ? [telegramUser.first_name, telegramUser.last_name].filter(Boolean).join(' ') : null,
      username: telegramUser?.username || null
    };
    const message = {
      id: randomUUID(), publicLinkId: link.id, body: cleanText, text: cleanText,
      source: telegramUser?.id ? 'telegram-webapp' : (body.channel || 'web'),
      senderAvailable: Boolean(telegramUser?.id), sender, unread: true, saved: false,
      createdAt: new Date().toISOString(), time: 'только что', mood: 'pink'
    };
    messages.set(message.id, message);
    schedulePersist();
    const owner = users.get(link.userId);
    if (owner) await notifyNewMessage(owner, message);
    return json(res, 200, { message: 'Послание отправлено', id: message.id, delivery: telegramUser?.id ? 'reply_available' : 'anonymous_web' });
  }
  if (req.method === 'POST' && /^\/api\/v1\/messages\/[^/]+\/(read|save)$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    const messageId = url.pathname.split('/')[4];
    const action = url.pathname.split('/')[5];
    const message = messages.get(messageId);
    const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user?.id);
    if (!ownerLink) return json(res, 404, { error: 'message_not_found' });
    if (action === 'read') message.unread = false;
    if (action === 'save') message.saved = true;
    schedulePersist();
    return json(res, 200, { ok: true, message: messageForOwner(message, user) });
  }
  if (req.method === 'POST' && /^\/api\/v1\/messages\/[^/]+\/(reply|block)$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    const messageId = url.pathname.split('/')[4];
    const action = url.pathname.split('/')[5];
    const message = messages.get(messageId);
    const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user?.id);
    if (!ownerLink) return json(res, 404, { error: 'message_not_found' });
    if (action === 'block') {
      if (!message.sender?.fingerprint) return json(res, 422, { error: 'sender_fingerprint_unavailable' });
      blockSender(user.id, message.sender.fingerprint);
      return json(res, 200, { ok: true, blocked: true, message: messageForOwner(message, user) });
    }
    const body = await readBody(req);
    const replyText = String(body.text || '').trim();
    if (replyText.length < 1 || replyText.length > 500) return json(res, 422, { error: 'reply_length' });
    message.reply = { text: replyText, createdAt: new Date().toISOString() };
    if (message.sender?.provider === 'telegram' && message.sender.providerUserId) {
      const deliveryText = `💌 <b>Ответ на ваше анонимное послание</b>\n\n${escapeTelegramHtml(replyText)}`;
      const stickerResult = await sendTelegramSticker(message.sender.providerUserId, TELEGRAM_SENT_STICKER_ID);
      const messageResult = await sendTelegramMessage(message.sender.providerUserId, deliveryText);
      message.replyDelivery = { status: messageResult.sent ? 'delivered' : 'failed', channel: 'telegram', sticker: stickerResult.sent === true, updatedAt: new Date().toISOString() };
    } else {
      message.replyDelivery = { status: 'unavailable', reason: 'anonymous_web_sender_has_no_delivery_channel', updatedAt: new Date().toISOString() };
    }
    schedulePersist();
    return json(res, 200, { ok: true, message: messageForOwner(message, user) });
  }
  if (req.method === 'POST' && /^\/api\/v1\/messages\/[^/]+\/reveal$/.test(url.pathname)) {
    const user = getUserFromRequest(req);
    const messageId = url.pathname.split('/')[4];
    const message = messages.get(messageId);
    const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user?.id);
    if (!ownerLink) return json(res, 404, { error: 'message_not_found' });
    const revealed = Array.isArray(message.revealedFor) && message.revealedFor.includes(user.id);
    return json(res, 200, {
      messageId, status: revealed ? 'revealed' : 'pending', amount: 7, currency: 'RUB',
      sender: revealed ? messageForOwner(message, user).sender || null : null,
      reason: revealed ? null : (message.senderAvailable ? 'payment_confirmation_required' : 'sender_consent_or_bot_identity_required')
    });
  }
  if (req.method === 'PUT' && url.pathname === '/api/v1/retention/settings') {
    const user = getUserFromRequest(req);
    const body = await readBody(req);
    // The preview sends no bearer token, so keep the anonymous demo setting separate.
    const userId = user?.id || 'demo';
    const settings = { dailyEnabled: Boolean(body.dailyEnabled), updatedAt: new Date().toISOString() };
    if (user) user.dailyEnabled = settings.dailyEnabled;
    retentionSettings.set(userId, settings);
    schedulePersist();
    return json(res, 200, settings);
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/retention/broadcast') {
    const result = await runDailyRetentionBroadcast();
    return json(res, 200, result);
  }
  const paymentStatusMatch = url.pathname.match(/^\/api\/v1\/payments\/([^/]+)$/);
  if (req.method === 'GET' && paymentStatusMatch) {
    const user = getUserFromRequest(req);
    const payment = payments.get(decodeURIComponent(paymentStatusMatch[1]));
    if (!payment || (payment.userId && payment.userId !== user?.id)) return json(res, 404, { error: 'payment_not_found' });
    await reconcileExternalPayment(payment);
    return json(res, 200, { id: payment.id, status: payment.status, provider: payment.provider, purpose: payment.purpose, amount: payment.amount, currency: payment.currency, paidAt: payment.paidAt || null, error: payment.error || null });
  }
  if (req.method === 'POST' && url.pathname === '/api/v1/payments/checkout') {
    const body = await readBody(req);
    const user = getUserFromRequest(req);
    const purpose = body.purpose === 'balance' ? 'balance' : 'plan';
    const plan = body.plan === 'reveal' ? 'reveal' : body.plan === 'vip' ? 'vip' : null;
    if ((purpose === 'balance' || body.provider === 'balance') && !user) return json(res, 401, { error: 'unauthorized' });
    if (purpose === 'plan' && !plan) return json(res, 422, { error: 'invalid_plan' });
    const amount = purpose === 'balance' ? Number(body.amount) : (plan === 'reveal' ? 7 : 20);
    if (!Number.isInteger(amount) || amount < 1 || amount > 100000) return json(res, 422, { error: 'invalid_amount' });
    const provider = String(body.provider || 'yoomoney').toLowerCase();
    if (!paymentProviderLabels[provider]) return json(res, 422, { error: 'invalid_payment_provider' });
    if (provider === 'balance' && Number(user.balanceRub || 0) < amount) return json(res, 402, { error: 'insufficient_balance', balance: Number(user.balanceRub || 0), required: amount });
    if (purpose === 'plan' && body.messageId && user) {
      const message = messages.get(body.messageId);
      const ownerLink = message && [...publicLinks.values()].find((link) => link.id === message.publicLinkId && link.userId === user.id);
      if (!ownerLink) return json(res, 404, { error: 'message_not_found' });
    }
    try {
      const payment = await createPaymentCheckout(user, { provider, purpose, plan, amount, messageId: body.messageId || null });
      return json(res, 200, {
        invoiceId: payment.id, id: payment.id, plan, purpose, amount, currency: payment.currency,
        status: payment.status, provider, paymentUrl: payment.paymentUrl || null,
        instructions: payment.instructions || null, botUrl: payment.botUrl || null,
        balance: user?.balanceRub || 0
      });
    } catch (error) {
      const safeMessage = /token|secret|authorization|configured/i.test(error.message)
        ? 'Способ оплаты временно недоступен. Выберите другой способ оплаты.'
        : error.message;
      return json(res, 503, { error: 'payment_provider_unavailable', provider, message: safeMessage });
    }
  }
  if (req.method === 'POST' && url.pathname === '/webhooks/mystars') {
    const body = await readBody(req);
    const remoteOrderId = body.order_id || body.orderId || body.id;
    const order = [...mystarsOrders.values()].find((candidate) => candidate.remoteOrderId === remoteOrderId);
    if (!order) return json(res, 200, { ok: true, processed: false });
    try { await syncMyStarsOrder(order); return json(res, 200, { ok: true, processed: true, status: order.remoteStatus }); }
    catch (error) { console.error('[mystars] webhook reconciliation failed:', error.message); return json(res, 200, { ok: true, processed: false }); }
  }
  if (req.method === 'POST' && (url.pathname === '/webhooks/payments/cryptobot' || url.pathname === '/webhooks/cryptobot' || url.pathname === '/webhooks/payments/xrocket' || url.pathname === '/webhooks/xrocket' || url.pathname === '/webhooks/payments/yoomoney' || url.pathname === '/webhooks/yoomoney')) {
    const provider = url.pathname.includes('cryptobot') ? 'cryptobot' : url.pathname.includes('xrocket') ? 'xrocket' : 'yoomoney';
    const raw = await readRawBody(req);
    let body = {};
    try { body = raw.length ? JSON.parse(raw.toString('utf8')) : {}; } catch { return json(res, 400, { error: 'invalid_json' }); }
    if (provider === 'cryptobot') {
      // Crypto Pay has no separate webhook secret. Its signature key is the
      // SHA-256 digest of the app token, and the signed string is the compact
      // JSON representation of the update.
      if (!CRYPTOBOT_API_TOKEN) return json(res, 503, { error: 'cryptobot_api_token_missing' });
      const signature = String(req.headers['crypto-pay-api-signature'] || '');
      const signatureKey = createHash('sha256').update(CRYPTOBOT_API_TOKEN).digest();
      const expected = createHmac('sha256', signatureKey).update(JSON.stringify(body)).digest('hex');
      if (!signature || signature !== expected) return json(res, 401, { error: 'invalid_cryptobot_signature' });
    }
    if (provider === 'xrocket' && XROCKET_WEBHOOK_SECRET) {
      const timestamp = String(req.headers['signature-timestamp'] || '');
      const version = String(req.headers['signature-version'] || '');
      const signature = String(req.headers.signature || '');
      const expected = createHmac('sha256', XROCKET_WEBHOOK_SECRET).update(`${timestamp}.${raw.toString('utf8')}`).digest('hex');
      if (version !== 'v1' || !timestamp || !signature || signature !== expected) return json(res, 401, { error: 'invalid_xrocket_signature' });
    }
    const event = body.update_type || body.status || body.event || body.type || body.name || body.data?.event || body.data?.type || '';
    const payload = body.payload || body.data || body.invoice || body;
    const invoice = body.data?.invoice || body.invoice || payload.invoice || {};
    const paymentData = body.data?.payment || payload.payment || {};
    const nestedPayload = payload && typeof payload.payload === 'object' ? payload.payload : {};
    const payloadPaymentId = typeof payload?.payload === 'string' ? payload.payload : null;
    const paymentId = invoice.clientInvoiceId || invoice.client_invoice_id
      || paymentData.clientInvoiceId || paymentData.client_invoice_id
      || body.clientInvoiceId || body.client_invoice_id
      || nestedPayload.paymentId || nestedPayload.payment_id || payloadPaymentId
      || payload.payment_id || payload.paymentId || payload.clientInvoiceId || payload.client_invoice_id
      || payload.label || payload.metadata?.paymentId;
    let payment = paymentId && payments.get(String(paymentId));
    const externalId = invoice.id || invoice.invoice_id || payload.invoice_id || payload.invoiceId || body.invoice_id || body.invoiceId;
    if (!payment && externalId) payment = [...payments.values()].find((candidate) => candidate.externalId && String(candidate.externalId) === String(externalId));
    const normalizedEvent = String(event || '').toLowerCase();
    const normalizedPayloadStatus = String(payload.status || invoice.status || paymentData.status || body.status || '').toLowerCase();
    const paid = provider === 'cryptobot'
      ? ['invoice_paid', 'paid', 'invoice.completed', 'invoice_paid_successfully'].includes(normalizedEvent) || normalizedPayloadStatus === 'paid'
      : provider === 'yoomoney'
        ? ['paid', 'success', 'completed'].includes(normalizedEvent) || payload.paid === true
        : provider === 'xrocket'
          ? ['paid', 'completed'].includes(normalizedPayloadStatus) || (normalizedEvent === 'invoice_status_changed' && normalizedPayloadStatus === 'paid') || (normalizedEvent === 'payment_status_changed' && normalizedPayloadStatus === 'paid')
          : ['paid', 'success', 'completed'].includes(normalizedEvent) || payload.paid === true;
    const reportedAmount = provider === 'xrocket'
      ? (invoice.priceAmount ?? invoice.price_amount ?? payload.priceAmount ?? payload.price_amount)
      : (payload.amount ?? payload.invoice_amount ?? payload.sum);
    const expectedProviderAmount = payment?.providerAmount ?? payment?.amount;
    const amountMatches = reportedAmount === undefined || Number(reportedAmount) === Number(expectedProviderAmount);
    if (payment && payment.provider === provider && paid && amountMatches) applyPaidPayment(payment);
    return json(res, 200, { ok: true, processed: Boolean(payment && paid && amountMatches) });
  }
  if (req.method === 'POST' && url.pathname.startsWith('/webhooks/cloudpayments/')) {
    const raw = await readRawBody(req);
    const signature = req.headers['x-content-hmac'];
    if (CLOUDPAYMENTS_API_SECRET) {
      const expected = createHmac('sha256', CLOUDPAYMENTS_API_SECRET).update(raw).digest('base64');
      if (!signature || signature !== expected) return json(res, 401, { code: 13, error: 'invalid_signature' });
    }
    let body = {};
    try { body = raw.length ? JSON.parse(raw.toString('utf8')) : {}; } catch { return json(res, 400, { code: 12, error: 'invalid_json' }); }
    const event = url.pathname.split('/').pop();
    const invoiceId = body.InvoiceId || body.invoiceId;
    const payment = invoiceId && payments.get(invoiceId);
    if (payment) {
      if (event === 'pay') {
        const applied = applyPaidPayment(payment);
        // Daily teaser messages have no real sender. We are transparent about that
        // and turn the 7 RUB purchase into a 7-day VIP apology reward.
        if (applied && payment.plan === 'reveal' && !payment.messageId && payment.userId && users.has(payment.userId)) await giftVipAfterReveal(users.get(payment.userId));
      } else {
        payment.status = event === 'fail' ? 'failed' : event;
        schedulePersist();
      }
    }
    console.log(`[cloudpayments] event=${event} invoice=${invoiceId || 'unknown'}`);
    return json(res, 200, { code: 0 });
  }
  if (req.method === 'POST' && url.pathname.startsWith('/webhooks/telegram')) {
    if (TELEGRAM_WEBHOOK_SECRET && req.headers['x-telegram-bot-api-secret-token'] !== TELEGRAM_WEBHOOK_SECRET) return json(res, 403, { error: 'invalid_telegram_secret' });
    const body = await readBody(req);
    await handleTelegramUpdate(body);
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
      const user = completeAuth('vk', object.from_id || object.peer_id, { displayName: 'VK user' }).user;
      const intro = text === '/settings'
        ? `Настройки уведомлений и ежедневных посланий доступны в приложении:\n\n${profileInstructions(user.language || 'ru', user, 'vk')}`
        : `Добро пожаловать в «Послания» 💌\n\nОткройте общий ящик в приложении:\n\n${profileInstructions(user.language || 'ru', user, 'vk')}`;
      await sendVkMessage(object.from_id || object.peer_id, intro, true, buildWebAppUrl({ ref: ensurePublicLink(user).slug }));
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

function escapeHtml(value) {
  return String(value).replace(/[&<>\"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '\"': '&quot;', "'": '&#039;' }[character]));
}

function renderIndexTemplate(content) {
  const links = platformLinks();
  const replacements = {
    __TELEGRAM_URL__: links.telegram,
    __TELEGRAM_REFERRAL_URL__: links.telegramReferral,
    __VK_URL__: links.vk,
    __VK_REFERRAL_URL__: links.vkReferral,
    __SITE_URL__: links.site,
    __SITE_REFERRAL_URL__: links.siteReferral
  };
  return Object.entries(replacements).reduce((html, [token, value]) => html.replaceAll(token, escapeHtml(value)), content);
}

async function serveStatic(req, res, url) {
  const requested = url.pathname === '/' ? 'index.html' : url.pathname.replace(/^\//, '');
  const rootPath = normalize(WEB_ROOT).replace(/[\\/]$/, '');
  const filePath = normalize(join(rootPath, requested));
  if (!(filePath === rootPath || filePath.startsWith(rootPath + sep))) return res.writeHead(403).end('Forbidden');
  try {
    let content = await readFile(filePath);
    if (requested === 'index.html') content = Buffer.from(renderIndexTemplate(content.toString('utf8')));
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

const telegramBot = createTelegramBot({
  token: TELEGRAM_BOT_TOKEN,
  onUpdate: handleTelegramUpdate,
  onError: (label, error) => console.error(label, error?.message || error)
});

const telegramUserbot = createTelegramUserbot({
  enabled: TELEGRAM_USERBOT_ENABLED,
  apiId: TELEGRAM_USERBOT_API_ID,
  apiHash: TELEGRAM_USERBOT_API_HASH,
  session: TELEGRAM_USERBOT_SESSION,
  appUrl: new URL(WEB_APP_URL).origin,
  botUsername: TELEGRAM_BOT_USERNAME,
  botToken: TELEGRAM_BOT_TOKEN
});

async function bootstrap() {
  await loadDailyMessages();
  await telegramUserbot.start();
  await loadState();
  seedDemoData();
  setInterval(runDailyRetentionBroadcast, RETENTION_INTERVAL_MS).unref();
  setInterval(runPendingPaymentReconciliation, PAYMENT_RECONCILE_INTERVAL_MS).unref();
  // Reconcile once shortly after boot as well, so a payment made while the
  // process was restarting is credited without waiting for the first interval.
  setTimeout(() => { void runPendingPaymentReconciliation(); }, 1000).unref();
  server.listen(PORT, '0.0.0.0', async () => {
    console.log(`Послания listening on http://0.0.0.0:${PORT}`);
    console.log(`Telegram Web App: ${WEB_APP_URL}`);
    console.log(`Daily anonymous messages: every ${Math.round(RETENTION_INTERVAL_MS / 1000)}s, all active users unless disabled`);
    console.log(`External payment reconciliation: every ${Math.round(PAYMENT_RECONCILE_INTERVAL_MS / 1000)}s for pending YooMoney, CryptoBot and xRocket payments`);
    await configureTelegramBot();
    announceCryptoBotWebhook();
    if (TELEGRAM_MODE === 'polling') telegramBot.start();
    else console.log(`[telegram] mode=${TELEGRAM_MODE}; polling is disabled`);
  });
}

async function shutdown(signal) {
  console.log(`[shutdown] ${signal}`);
  await telegramUserbot.stop();
  devStore?.close();
  process.exit(0);
}

process.on('SIGTERM', () => { void shutdown('SIGTERM'); });
process.on('SIGINT', () => { void shutdown('SIGINT'); });
bootstrap();
