/**
 * Telegram transport module.
 *
 * The application owns business rules and passes update handling through `onUpdate`.
 * This module owns the Telegram connection: long polling, offset management,
 * graceful stop and bounded per-chat concurrency.
 */
export function createTelegramBot({
  token,
  onUpdate,
  onError = console.error,
  pollTimeout = 25,
  maxConcurrentUpdates = 32,
  maxPendingUpdates = 2000
}) {
  let running = false;
  let offset = 0;
  let loopPromise = null;
  let pollController = null;
  let active = 0;
  let queuedUpdates = 0;
  const tasks = new Set();
  const chatTails = new Map();
  const concurrencyLimit = Math.max(1, Number(maxConcurrentUpdates) || 32);
  const pendingLimit = Math.max(concurrencyLimit, Number(maxPendingUpdates) || 2000);
  const semaphoreWaiters = [];
  const capacityWaiters = [];

  async function request(method, body = {}, timeoutMs = 15_000, externalSignal = null) {
    if (!token) return null;
    const controller = externalSignal ? null : new AbortController();
    const signal = externalSignal || controller.signal;
    const timer = setTimeout(() => {
      if (externalSignal) pollController?.abort();
      else controller.abort();
    }, timeoutMs);
    try {
      const response = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal
      });
      const payload = await response.json();
      if (!response.ok || !payload.ok) throw new Error(payload.description || `Telegram API ${response.status}`);
      return payload.result;
    } finally {
      clearTimeout(timer);
    }
  }

  const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

  function updateKey(update) {
    const chatId = update?.message?.chat?.id
      || update?.callback_query?.message?.chat?.id
      || update?.my_chat_member?.chat?.id;
    return chatId == null ? `update:${update?.update_id || Math.random()}` : `chat:${chatId}`;
  }

  function acquire() {
    if (active < concurrencyLimit) {
      active += 1;
      return Promise.resolve();
    }
    return new Promise((resolve) => semaphoreWaiters.push(() => {
      active += 1;
      resolve();
    }));
  }

  function release() {
    active -= 1;
    const next = semaphoreWaiters.shift();
    if (next) next();
  }

  function signalCapacity() {
    while (capacityWaiters.length && queuedUpdates < pendingLimit) capacityWaiters.shift()();
  }

  function waitForCapacity() {
    if (queuedUpdates < pendingLimit) return Promise.resolve();
    return new Promise((resolve) => capacityWaiters.push(resolve));
  }

  function enqueueUpdate(update) {
    queuedUpdates += 1;
    const key = updateKey(update);
    const previous = chatTails.get(key) || Promise.resolve();
    const task = previous.then(async () => {
      await acquire();
      try {
        await onUpdate(update);
      } catch (error) {
        onError('[telegram module] update handler failed', error);
      } finally {
        release();
        queuedUpdates -= 1;
        signalCapacity();
      }
    });
    const tail = task.catch(() => {});
    chatTails.set(key, tail);
    task.finally(() => {
      if (chatTails.get(key) === tail) chatTails.delete(key);
      tasks.delete(task);
    }).catch(() => {});
    tasks.add(task);
  }

  async function poll() {
    while (running) {
      try {
        await waitForCapacity();
        if (!running) break;
        pollController = new AbortController();
        const updates = await request('getUpdates', {
          offset,
          timeout: pollTimeout,
          allowed_updates: ['message', 'callback_query', 'my_chat_member']
        }, (pollTimeout + 10) * 1000, pollController.signal) || [];
        pollController = null;

        for (const update of updates) {
          offset = update.update_id + 1;
          enqueueUpdate(update);
        }
      } catch (error) {
        pollController = null;
        if (running && error?.name !== 'AbortError') {
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
    try { await request('deleteWebhook', { drop_pending_updates: false }); }
    catch (error) { onError('[telegram module] deleteWebhook failed', error); }
    loopPromise = poll();
    console.log(`[telegram module] polling started; concurrency=${concurrencyLimit}, queue=${pendingLimit}`);
    return true;
  }

  async function stop() {
    running = false;
    pollController?.abort();
    for (const resolve of capacityWaiters.splice(0)) resolve();
    await loopPromise;
    loopPromise = null;
    await Promise.allSettled([...tasks]);
    console.log('[telegram module] polling stopped');
  }

  return { request, start, stop, get isRunning() { return running; }, get queuedUpdates() { return queuedUpdates; } };
}
