import { Api, TelegramClient } from 'telegram';
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
  let self = null;
  let giftsCache = { expiresAt: 0, gifts: [] };

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
        self = await client.getMe();
        console.log(`[userbot] authorized and ready as @${self?.username || self?.id || 'user'}`);
        return true;
      } catch (error) {
        ready = false;
        self = null;
        console.error('[userbot] start failed:', error.message);
        return false;
      }
    })();
    return startPromise;
  }

  function normalizeGift(gift) {
    const attributes = gift?.sticker?.attributes || [];
    const emoji = attributes.find((attribute) => attribute?.alt)?.alt || '';
    const giftId = String(gift.id);
    return {
      id: giftId,
      title: emoji ? `Подарок ${emoji}` : `Telegram-подарок #${giftId}`,
      emoji,
      stars: Number(gift.stars || 0),
      limited: Boolean(gift.limited),
      soldOut: Boolean(gift.soldOut),
      availabilityRemains: gift.availabilityRemains == null ? null : Number(gift.availabilityRemains),
      availabilityTotal: gift.availabilityTotal == null ? null : Number(gift.availabilityTotal),
      convertStars: Number(gift.convertStars || 0),
      upgradeStars: Number(gift.upgradeStars || 0)
    };
  }

  async function getStarGifts({ refresh = false } = {}) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (!refresh && giftsCache.expiresAt > Date.now()) return giftsCache.gifts;
    const result = await client.invoke(new Api.payments.GetStarGifts({ hash: 0 }));
    const rawGifts = Array.isArray(result?.gifts) ? result.gifts : [];
    const gifts = rawGifts.map(normalizeGift).filter((gift) => gift.id && gift.stars > 0 && !gift.soldOut);
    giftsCache = { expiresAt: Date.now() + 5 * 60 * 1000, gifts };
    return gifts;
  }

  async function getStarsBalance() {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    const status = await client.invoke(new Api.payments.GetStarsStatus({ peer: new Api.InputPeerSelf() }));
    return Number(status?.balance?.amount || 0);
  }

  async function getUsername() {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (!self) self = await client.getMe();
    const username = String(self?.username || '').replace(/^@+/, '');
    if (!username) throw new Error('Telegram userbot account has no public username');
    return username;
  }

  async function inputUserFor(username) {
    const peer = await client.getInputEntity(String(username).replace(/^@+/, ''));
    if (peer?.className !== 'InputPeerUser') throw new Error('Telegram recipient must be a user account');
    return { peer, user: new Api.InputUser({ userId: peer.userId, accessHash: peer.accessHash }) };
  }

  async function getGiftOffer(gift) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (gift.type === 'star_gift') {
      const selected = (await getStarGifts()).find((candidate) => candidate.id === String(gift.giftId));
      if (!selected) throw new Error('Selected Telegram gift is no longer available');
      return { type: gift.type, title: selected.title, giftId: selected.id, stars: selected.stars };
    }
    const { user } = await inputUserFor(gift.username);
    if (gift.type === 'stars') {
      const options = await client.invoke(new Api.payments.GetStarsGiftOptions({ userId: user }));
      const option = (options || []).find((candidate) => Number(candidate.stars) === Number(gift.quantity));
      if (!option) throw new Error('This Stars gift option is not available for the recipient');
      return { type: gift.type, title: `${gift.quantity} Telegram Stars`, stars: Number(option.amount || option.stars), option };
    }
    const options = await client.invoke(new Api.payments.GetPremiumGiftCodeOptions({}));
    const option = (options || []).find((candidate) => Number(candidate.months) === Number(gift.months));
    if (!option) throw new Error('This Premium gift option is not available');
    return { type: gift.type, title: `Telegram Premium на ${gift.months} мес.`, stars: Number(option.amount), option };
  }

  async function sendStarsForm(invoice) {
    const form = await client.invoke(new Api.payments.GetPaymentForm({ invoice }));
    if (form?.formId == null) throw new Error('Telegram did not return a Stars payment form');
    return client.invoke(new Api.payments.SendStarsForm({ formId: form.formId, invoice }));
  }

  async function sendStarGift({ username, giftId, message, hideName = true }) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    const peer = await client.getInputEntity(String(username).replace(/^@+/, ''));
    const invoice = new Api.InputInvoiceStarGift({
      hideName,
      peer,
      giftId: String(giftId),
      message: new Api.TextWithEntities({ text: String(message || ''), entities: [] })
    });
    return sendStarsForm(invoice);
  }

  async function sendGift({ gift, message }) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (gift.type === 'star_gift') return sendStarGift({ username: gift.username, giftId: gift.giftId, message, hideName: true });
    const { peer, user } = await inputUserFor(gift.username);
    const offer = await getGiftOffer(gift);
    let invoice;
    if (gift.type === 'stars') {
      const purpose = new Api.InputStorePaymentStarsGift({ userId: user, stars: String(gift.quantity), currency: offer.option.currency, amount: offer.option.amount });
      invoice = new Api.InputInvoiceStars({ purpose });
    } else {
      const purpose = new Api.InputStorePaymentPremiumGiftCode({
        users: [user],
        currency: offer.option.currency,
        amount: offer.option.amount,
        message: new Api.TextWithEntities({ text: String(message || ''), entities: [] })
      });
      invoice = new Api.InputInvoicePremiumGiftCode({ purpose, option: offer.option });
    }
    const result = await sendStarsForm(invoice);
    if (gift.type === 'stars') await client.sendMessage(peer, { message: String(message || '') });
    return result;
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
    self = null;
    giftsCache = { expiresAt: 0, gifts: [] };
    if (client) {
      try { await client.disconnect(); } catch (error) { console.error('[userbot] stop failed:', error.message); }
    }
    client = null;
  }

  return {
    start,
    stop,
    notify,
    getStarGifts,
    getGiftOffer,
    getStarsBalance,
    getUsername,
    sendStarGift,
    sendGift,
    get isReady() { return ready; }
  };
}
