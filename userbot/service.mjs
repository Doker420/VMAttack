import { Api, TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';

/**
 * Optional Telegram userbot transport.
 *
 * The main application remains the only production entrypoint: node server.mjs.
 * This module is started and stopped by server.mjs when
 * TELEGRAM_USERBOT_ENABLED=true and a previously authorized StringSession is set.
 */
export function createTelegramUserbot({ enabled, apiId, apiHash, session, appUrl, botUsername, botToken }) {
  let client = null;
  let ready = false;
  let startPromise = null;
  let self = null;
  let giftsCache = { expiresAt: 0, gifts: [] };
  let giftsRequest = null;
  let starsBalanceRequest = null;
  let giftSendTail = Promise.resolve();

  async function withTimeout(promise, milliseconds, label) {
    let timer;
    try {
      return await Promise.race([
        promise,
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${label} timed out`)), milliseconds); })
      ]);
    } finally {
      clearTimeout(timer);
    }
  }

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
    if (giftsRequest) return giftsRequest;
    giftsRequest = (async () => {
      const result = await withTimeout(client.invoke(new Api.payments.GetStarGifts({ hash: 0 })), 10000, 'Telegram gift catalog');
      const rawGifts = Array.isArray(result?.gifts) ? result.gifts : [];
      const gifts = rawGifts.map(normalizeGift).filter((gift) => gift.id && gift.stars > 0 && !gift.soldOut);
      giftsCache = { expiresAt: Date.now() + 5 * 60 * 1000, gifts };
      return gifts;
    })();
    try {
      return await giftsRequest;
    } finally {
      giftsRequest = null;
    }
  }

  async function getStarsBalance() {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (starsBalanceRequest) return starsBalanceRequest;
    starsBalanceRequest = (async () => {
      const status = await withTimeout(client.invoke(new Api.payments.GetStarsStatus({ peer: new Api.InputPeerSelf() })), 10000, 'Telegram Stars balance');
      return Number(status?.balance?.amount || 0);
    })();
    try {
      return await starsBalanceRequest;
    } finally {
      starsBalanceRequest = null;
    }
  }

  async function getUsername() {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (!self) self = await client.getMe();
    const username = String(self?.username || '').replace(/^@+/, '');
    if (!username) throw new Error('Telegram userbot account has no public username');
    return username;
  }

  async function inputUserFor(username) {
    const normalizedUsername = String(username).replace(/^@+/, '').trim();
    const peer = await client.getInputEntity(normalizedUsername);
    if (peer?.className !== 'InputPeerUser') throw new Error('Telegram recipient must be a user account');
    return {
      peer,
      user: new Api.InputUser({ userId: peer.userId, accessHash: peer.accessHash }),
      username: normalizedUsername
    };
  }

  async function downloadBotFile(fileId) {
    if (!botToken) throw new Error('Telegram bot token is required to relay media through the userbot');
    const fileResponse = await fetch(`https://api.telegram.org/bot${botToken}/getFile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ file_id: fileId }),
      signal: AbortSignal.timeout(15000)
    });
    const filePayload = await fileResponse.json().catch(() => ({}));
    const filePath = filePayload.result?.file_path;
    if (!fileResponse.ok || !filePayload.ok || !filePath) throw new Error(filePayload.description || 'Telegram Bot API could not resolve the media file');
    const mediaResponse = await fetch(`https://api.telegram.org/file/bot${botToken}/${filePath}`, { signal: AbortSignal.timeout(30000) });
    if (!mediaResponse.ok) throw new Error(`Telegram Bot API media download failed (${mediaResponse.status})`);
    const buffer = Buffer.from(await mediaResponse.arrayBuffer());
    return { buffer, fileName: filePath.split('/').pop() || 'telegram-media.bin' };
  }

  async function sendAnonymousMessage({ username, text = '', media = null, signature = '', botUrl = '', revealUrl = '' }) {
    if (!ready || !client) return { sent: false, reason: 'userbot_not_ready' };
    try {
      const entity = await client.getEntity(String(username).replace(/^@+/, ''));
      const footer = [signature, revealUrl ? `🔎 Узнать кто отправил: ${revealUrl}` : '', botUrl ? `💌 Открыть «Послания»: ${botUrl}` : '']
        .filter(Boolean)
        .join('\n');
      const messageText = [String(text || '').trim(), footer].filter(Boolean).join('\n\n');
      const buttons = [];
      if (revealUrl) buttons.push([{ text: '🔎 Узнать кто отправил · 7 ₽', url: revealUrl }]);
      if (botUrl) buttons.push([{ text: '💌 Открыть «Послания»', url: botUrl }]);
      if (media?.fileId) {
        const downloaded = await downloadBotFile(media.fileId);
        downloaded.buffer.name = downloaded.fileName;
        const stickerAttributes = media.kind === 'sticker'
          ? [new Api.DocumentAttributeSticker({
              alt: media.emoji || '',
              stickerset: media.stickerSetName
                ? new Api.InputStickerSetShortName({ shortName: media.stickerSetName })
                : new Api.InputStickerSetEmpty(),
              mask: false
            })]
          : undefined;
        await client.sendFile(entity, {
          file: downloaded.buffer,
          caption: messageText,
          forceDocument: media.kind === 'sticker',
          voiceNote: media.kind === 'voice',
          videoNote: media.kind === 'video_note',
          supportsStreaming: media.kind === 'video',
          attributes: stickerAttributes,
          buttons: buttons.length ? buttons : undefined
        });
      } else {
        await client.sendMessage(entity, { message: messageText, buttons: buttons.length ? buttons : undefined });
      }
      return { sent: true, channel: 'userbot', media: Boolean(media?.fileId) };
    } catch (error) {
      console.error(`[userbot] anonymous message to @${username} failed:`, error.message);
      return { sent: false, reason: error.message };
    }
  }

  async function getGiftOffer(gift) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (gift.type !== 'star_gift') throw new Error('Premium and direct Stars are delivered through MyStars');
    const recipient = await inputUserFor(gift.username);
    const selected = (await getStarGifts()).find((candidate) => candidate.id === String(gift.giftId));
    if (!selected) throw new Error('Selected Telegram gift is no longer available');
    return { type: gift.type, title: selected.title, giftId: selected.id, giftStars: selected.stars, costStars: selected.stars, stars: selected.stars, recipient: { username: recipient.username } };
  }

  async function sendStarsForm(invoice) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    // Star Gifts are paid from the userbot account through Telegram's
    // payments flow. The invoice must first be converted into a payment form;
    // calling an undefined helper here previously made every gift delivery
    // fail after the recipient/price checks had succeeded.
    const form = await withTimeout(
      client.invoke(new Api.payments.GetPaymentForm({ invoice })),
      15000,
      'Telegram Star Gift payment form'
    );
    if (!form?.formId) throw new Error('Telegram did not return a Star Gift payment form');
    return withTimeout(
      client.invoke(new Api.payments.SendStarsForm({ formId: form.formId, invoice })),
      30000,
      'Telegram Star Gift payment'
    );
  }

  async function sendStarGiftNow({ username, giftId, message, hideName = true }) {
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

  async function sendStarGift(args) {
    // Telegram Stars are spent from one userbot wallet. Serialize payment
    // forms so simultaneous orders cannot race on the same balance or MTProto
    // payment session.
    const previous = giftSendTail;
    let release;
    giftSendTail = new Promise((resolve) => { release = resolve; });
    await previous;
    try {
      return await sendStarGiftNow(args);
    } finally {
      release();
    }
  }

  async function sendGift({ gift, message }) {
    if (!ready || !client) throw new Error('Telegram userbot is not ready');
    if (gift.type !== 'star_gift') throw new Error('Premium and direct Stars are delivered through MyStars');
    return sendStarGift({ username: gift.username, giftId: gift.giftId, message, hideName: true });
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
    giftsRequest = null;
    starsBalanceRequest = null;
    giftSendTail = Promise.resolve();
    if (client) {
      try { await client.disconnect(); } catch (error) { console.error('[userbot] stop failed:', error.message); }
    }
    client = null;
  }

  return {
    start,
    stop,
    notify,
    sendAnonymousMessage,
    getStarGifts,
    getGiftOffer,
    getStarsBalance,
    getUsername,
    sendStarGift,
    sendGift,
    get isReady() { return ready; }
  };
}
