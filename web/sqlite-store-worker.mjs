import { parentPort, workerData } from 'node:worker_threads';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

async function loadDriver() {
  try {
    const native = await import('node:sqlite');
    return { type: 'native', Database: native.DatabaseSync };
  } catch {
    try {
      const better = await import('better-sqlite3');
      return { type: 'better', Database: better.default || better };
    } catch {
      return null;
    }
  }
}

function configureDatabase(db, type) {
  if (type === 'better') {
    db.pragma('journal_mode = WAL');
    db.pragma('synchronous = NORMAL');
    db.pragma('busy_timeout = 5000');
    db.pragma('temp_store = MEMORY');
    db.pragma('wal_autocheckpoint = 1000');
  } else {
    db.exec(`
      PRAGMA journal_mode = WAL;
      PRAGMA synchronous = NORMAL;
      PRAGMA busy_timeout = 5000;
      PRAGMA temp_store = MEMORY;
      PRAGMA wal_autocheckpoint = 1000;
    `);
  }
  db.exec(`
    CREATE TABLE IF NOT EXISTS app_state (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);
}

const driver = await loadDriver();
let db = null;
let write = null;
let pendingSnapshot = null;
let writing = false;
let closing = false;
let closeResolve = null;

try {
  if (!driver) throw new Error('SQLite driver unavailable in persistence worker');
  mkdirSync(dirname(workerData.filePath), { recursive: true });
  db = new driver.Database(workerData.filePath);
  configureDatabase(db, driver.type);
  write = db.prepare(`
    INSERT INTO app_state (key, value, updated_at) VALUES (?, ?, ?)
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
  `);
  parentPort.postMessage({ type: 'ready' });
} catch (error) {
  parentPort.postMessage({ type: 'error', message: error.message });
}

function closeIfReady() {
  if (!closing || writing || pendingSnapshot !== null) return;
  try { db?.close(); } catch {}
  closeResolve?.();
  closeResolve = null;
  parentPort.close();
}

function writeNext() {
  if (writing || pendingSnapshot === null || !write || closing && pendingSnapshot === null) {
    closeIfReady();
    return;
  }
  writing = true;
  const snapshot = pendingSnapshot;
  pendingSnapshot = null;
  try {
    // JSON serialization is intentionally performed off the HTTP/event-loop
    // thread. The old app_state writer serialized the complete application
    // snapshot synchronously during traffic spikes.
    write.run('snapshot', JSON.stringify(snapshot), new Date().toISOString());
    parentPort.postMessage({ type: 'saved' });
  } catch (error) {
    parentPort.postMessage({ type: 'write-error', message: error.message });
  } finally {
    writing = false;
    if (pendingSnapshot !== null) setImmediate(writeNext);
    else closeIfReady();
  }
}

parentPort.on('message', (message) => {
  if (message.type === 'save') {
    // Keep only the latest snapshot. This prevents a burst of writes from
    // creating an unbounded worker queue while preserving eventual durability.
    pendingSnapshot = message.snapshot;
    setImmediate(writeNext);
  } else if (message.type === 'close') {
    closing = true;
    closeResolve = message.resolveId ? () => parentPort.postMessage({ type: 'closed', resolveId: message.resolveId }) : null;
    writeNext();
  }
});
