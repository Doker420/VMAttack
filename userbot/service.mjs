import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';

/**
 * Optional Telegram userbot transport.
 *
 * The main application remains the only production entrypoint: node server.mjs.
 * This module is started and stopped by server.mjs when
 * TELEGRAM_USERBOT_ENABLED=true and a previously authorized StringSession is set.
 */
export function createTelegramUserbot({ enabled, apiId, apiHash, session, appUrl, botUsername }) {
  let client = null;
  let ready = false;
  let startPromise = null;

  async function start() {
    if (!enabled) {
      console.log('[userbot] disabled by TELEGRAM_USERBOT_ENABLED=false');
      return false;
    }
    if (!apiId || !apiHash || !session) {
      console.warn('[userbot] enabled but API_ID, API_HASH or SESSION is missing; run `node userbot/setup.mjs` first');
      return false;
    }
    if (startPromise) return startPromise;
    startPromise = (async () => {
      try {
        client = new TelegramClient(new StringSession(session), Number(apiId), apiHash, { connectionRetries: 5 });
        await client.connect();
        ready = await client.checkAuthorization();
        if (!ready) {
          console.warn('[userbot] session is not authorized; run `node userbot/setup.mjs` again');
          return false;
        }
        console.log('[userbot] authorized and ready');
        return true;
      } catch (error) {
        ready = false;
        console.error('[userbot] start failed:', error.message);
        return false;
      }
    })();
    return startPromise;
  }

  async function notify({ username, text, botUrl, orderId, gift }) {
    if (!ready || !client) return { sent: false, reason: 'userbot_not_ready' };
    try {
      const entity = await client.getEntity(username.replace(/^@+/, ''));
      const plainText = String(text || '').replace(/<[^>]+>/g, '');
      const message = `${plainText}\n\nОткрыть бота: ${botUrl}\nУзнать кто отправляет подарки: ${appUrl}/?app=1&payment=reveal\nТарифы: ${appUrl}/#pricing\n\nЗаказ: ${orderId}\nПодарок: ${gift}`;
      await client.sendMessage(entity, { message });
      return { sent: true, channel: 'userbot' };
    } catch (error) {
      console.error(`[userbot] notification to @${username} failed:`, error.message);
      return { sent: false, reason: error.message };
    }
  }

  async function stop() {
    ready = false;
    startPromise = null;
    if (client) {
      try { await client.disconnect(); } catch (error) { console.error('[userbot] stop failed:', error.message); }
    }
    client = null;
  }

  return { start, stop, notify, get isReady() { return ready; } };
}
