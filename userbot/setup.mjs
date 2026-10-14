import dotenv from 'dotenv';
import input from 'input';
import { fileURLToPath } from 'node:url';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';

// One-time interactive setup. It prints a StringSession; put that value only in
// the root .env as TELEGRAM_USERBOT_SESSION and never commit it.
dotenv.config({ path: fileURLToPath(new URL('../.env', import.meta.url)), override: true });

const apiId = Number(process.env.TELEGRAM_USERBOT_API_ID || '0');
const apiHash = process.env.TELEGRAM_USERBOT_API_HASH || '';
if (!apiId || !apiHash) {
  console.error('Set TELEGRAM_USERBOT_API_ID and TELEGRAM_USERBOT_API_HASH in the root .env first.');
  process.exit(1);
}

const client = new TelegramClient(new StringSession(''), apiId, apiHash, { connectionRetries: 5 });
await client.start({
  phoneNumber: async () => input.text('Telegram phone number: '),
  password: async () => input.password('Telegram 2FA password (if enabled): '),
  phoneCode: async () => input.text('Telegram login code: '),
  onError: (error) => console.error('[userbot setup]', error.message)
});

console.log('\nUserbot authorized. Add this line to the root .env:');
console.log(`TELEGRAM_USERBOT_SESSION=${client.session.save()}`);
await client.disconnect();
