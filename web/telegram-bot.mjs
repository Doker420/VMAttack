/**
 * Telegram transport module.
 *
 * The application owns business rules and passes update handling through `onUpdate`.
 * This module owns the Telegram connection: long polling, offset management,
 * graceful stop and API errors. It can later be swapped for a webhook adapter
 * without changing the bot UI or the shared application state.
 */
export function createTelegramBot({ token, onUpdate, onError = console.error, pollTimeout = 25 }) {
  let running = false;
  let offset = 0;
  let loopPromise = null;

  async function request(method, body = {}, timeoutMs = 15_000) {
    if (!token) return null;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal
      });
      const payload = await response.json();
      if (!response.ok || !payload.ok) throw new Error(payload.description || `Telegram API ${response.status}`);
      return payload.result;
    } finally {
      clearTimeout(timer);
    }
  }

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  async function poll() {
    while (running) {
      try {
        const updates = await request('getUpdates', {
          offset,
          timeout: pollTimeout,
          allowed_updates: ['message', 'callback_query', 'my_chat_member']
        }, (pollTimeout + 10) * 1000) || [];

        for (const update of updates) {
          offset = update.update_id + 1;
          try {
            await onUpdate(update);
          } catch (error) {
            onError('[telegram module] update handler failed', error);
          }
        }
      } catch (error) {
        if (running) {
          onError('[telegram module] polling failed', error);
          await sleep(3000);
        }
      }
    }
  }

  async function start() {
    if (!token || running) return false;
    running = true;
    // Polling and webhook modes cannot be active simultaneously. The explicit
    // polling adapter removes an old webhook so a fresh local launch responds.
    try { await request('deleteWebhook', { drop_pending_updates: false }); } catch (error) { onError('[telegram module] deleteWebhook failed', error); }
    loopPromise = poll();
    console.log('[telegram module] polling started');
    return true;
  }

  async function stop() {
    running = false;
    await loopPromise;
    loopPromise = null;
    console.log('[telegram module] polling stopped');
  }

  return { request, start, stop, get isRunning() { return running; } };
}
