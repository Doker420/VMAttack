import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const projectRoot = join(import.meta.dirname, '..');

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitFor(check, timeout = 10000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeout) {
    if (await check()) return;
    await sleep(100);
  }
  throw new Error(`Timed out after ${timeout}ms`);
}

function readRequestBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }
      catch (error) { reject(error); }
    });
    request.on('error', reject);
  });
}

async function startMockCryptoBot() {
  let invoiceStatus = 'active';
  const requests = [];
  const server = createServer(async (request, response) => {
    if (request.method !== 'POST' || request.url !== '/api/getInvoices') {
      response.writeHead(404).end();
      return;
    }
    requests.push(await readRequestBody(request));
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({
      ok: true,
      result: { items: [{ invoice_id: 987654, status: invoiceStatus, amount: '100', fiat: 'RUB' }] }
    }));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return {
    url: `http://127.0.0.1:${server.address().port}/api`,
    requests,
    setStatus(status) { invoiceStatus = status; },
    close() { return new Promise((resolve) => server.close(resolve)); }
  };
}

async function startApp(env) {
  const child = spawn(process.execPath, ['server.mjs'], {
    cwd: projectRoot,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let output = '';
  child.stdout.on('data', (chunk) => { output += chunk.toString(); });
  child.stderr.on('data', (chunk) => { output += chunk.toString(); });
  await waitFor(async () => {
    try { return (await fetch(`http://127.0.0.1:${env.PORT}/health`)).ok; }
    catch { return false; }
  });
  return {
    child,
    get output() { return output; },
    async close() {
      if (child.exitCode == null) child.kill('SIGTERM');
      await waitFor(() => child.exitCode != null, 5000).catch(() => child.kill('SIGKILL'));
    }
  };
}

test('reconciles CryptoBot invoices after Web App closes and accepts unknown Telegram username recipients', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'poslaniya-integration-'));
  const storeFile = join(directory, 'store.json');
  const cryptoBot = await startMockCryptoBot();
  const port = 4300 + Math.floor(Math.random() * 500);
  const now = new Date().toISOString();
  await writeFile(storeFile, JSON.stringify({
    users: [{
      id: 'sender-user',
      displayName: 'Sender',
      username: 'sender_user',
      balanceRub: 0,
      language: 'ru',
      dailyEnabled: false,
      identities: [{ provider: 'telegram', providerUserId: '111', username: 'sender_user' }]
    }],
    publicLinks: [{ id: 'sender-link', userId: 'sender-user', slug: 'sender_user', isActive: true }],
    messages: [],
    payments: [['pay-crypto-test', {
      id: 'pay-crypto-test',
      provider: 'cryptobot',
      purpose: 'balance',
      plan: null,
      amount: 100,
      currency: 'RUB',
      userId: 'sender-user',
      status: 'pending',
      externalId: 987654,
      createdAt: now
    }]],
    retentionSettings: [],
    blockedSenders: [],
    mystarsOrders: []
  }));

  const app = await startApp({
    PORT: String(port),
    DB_DRIVER: 'json',
    DATA_FILE: storeFile,
    DEMO_MODE: 'false',
    TELEGRAM_MODE: 'webhook',
    TELEGRAM_USERBOT_ENABLED: 'false',
    RETENTION_INTERVAL_MS: '3600000',
    PAYMENT_RECONCILE_INTERVAL_MS: '100',
    CRYPTOBOT_API_TOKEN: 'mock-token',
    CRYPTOBOT_API_URL: cryptoBot.url
  });

  try {
    await waitFor(() => cryptoBot.requests.length > 0);
    assert.deepEqual(cryptoBot.requests.at(-1)?.invoice_ids, [987654]);

    // An active invoice is not a successful payment and must not credit balance.
    let state = JSON.parse(await readFile(storeFile, 'utf8'));
    assert.equal(state.users[0].balanceRub, 0);

    cryptoBot.setStatus('paid');
    await waitFor(async () => {
      state = JSON.parse(await readFile(storeFile, 'utf8'));
      return state.payments?.[0]?.[1]?.status === 'paid';
    });
    state = JSON.parse(await readFile(storeFile, 'utf8'));
    assert.equal(state.users[0].balanceRub, 100);

    // The recipient does not exist in the local database and has no publicLinks
    // entry. The bot flow still creates a userbot-delivery placeholder.
    const update = (text, updateId) => ({
      update_id: updateId,
      message: {
        message_id: updateId,
        chat: { id: 111, type: 'private' },
        from: { id: 111, first_name: 'Sender', username: 'sender_user' },
        text
      }
    });
    await fetch(`http://127.0.0.1:${port}/webhooks/telegram`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(update('/message', 1)) });
    await fetch(`http://127.0.0.1:${port}/webhooks/telegram`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(update('@bborodaaaaa', 2)) });
    await fetch(`http://127.0.0.1:${port}/webhooks/telegram`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(update('Привет без publicLinks', 3)) });

    await waitFor(async () => {
      state = JSON.parse(await readFile(storeFile, 'utf8'));
      return state.users.some((user) => user.username === 'bborodaaaaa') && state.messages.length === 1;
    });
    const recipient = state.users.find((user) => user.username === 'bborodaaaaa');
    assert.equal(recipient.identities[0].provider, 'telegram');
    assert.equal(recipient.identities[0].providerUserId, null);
    assert.equal(state.messages[0].publicLinkId, state.publicLinks.find((link) => link.userId === recipient.id).id);
  } finally {
    await app.close();
    await cryptoBot.close();
    await rm(directory, { recursive: true, force: true });
  }
});
