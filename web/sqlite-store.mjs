import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { Worker } from 'node:worker_threads';

async function loadDriver() {
  // Node 22+ ships an experimental SQLite API. Node 20 uses the optional
  // better-sqlite3 package so the same server can run on both versions.
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

/**
 * SQLite adapter with a dedicated write worker.
 *
 * The HTTP and Telegram event loop only reads the initial snapshot from SQLite.
 * Runtime snapshots are coalesced and written by sqlite-store-worker.mjs, so a
 * large JSON serialization or SQLite fsync cannot freeze request handling.
 * Production deployments should still use one app writer per SQLite file and
 * move to PostgreSQL for multi-instance horizontal scaling.
 */
export async function createSqliteStore(filePath) {
  mkdirSync(dirname(filePath), { recursive: true });
  const driver = await loadDriver();
  if (!driver) {
    console.warn('[store] SQLite driver unavailable; using JSON fallback. Run `npm install` on Node 20 to enable SQLite.');
    return null;
  }

  let db;
  let read;
  try {
    db = new driver.Database(filePath);
    configureDatabase(db, driver.type);
    read = db.prepare('SELECT value FROM app_state WHERE key = ?');
  } catch (error) {
    try { db?.close(); } catch {}
    console.warn(`[store] SQLite driver failed to open; using JSON fallback: ${error.message}`);
    return null;
  }

  const worker = new Worker(new URL('./sqlite-store-worker.mjs', import.meta.url), { workerData: { filePath } });
  let workerReady = false;
  let workerFailed = false;
  let pendingSnapshot = null;
  let writeInFlight = false;
  let readyResolve;
  let readyReject;
  const ready = new Promise((resolve, reject) => {
    readyResolve = resolve;
    readyReject = reject;
  });
  let closeResolve;
  let closeReject;
  let closePromise = null;

  const pump = () => {
    if (!workerReady || workerFailed || writeInFlight || pendingSnapshot === null) return;
    const snapshot = pendingSnapshot;
    pendingSnapshot = null;
    writeInFlight = true;
    worker.postMessage({ type: 'save', snapshot });
  };

  worker.on('message', (message) => {
    if (message.type === 'ready') {
      workerReady = true;
      readyResolve();
      pump();
    } else if (message.type === 'saved') {
      writeInFlight = false;
      pump();
    } else if (message.type === 'error') {
      workerFailed = true;
      const error = new Error(message.message || 'SQLite persistence worker failed');
      readyReject(error);
      console.error('[store] SQLite persistence worker failed:', error.message);
      if (writeInFlight) writeInFlight = false;
    } else if (message.type === 'write-error') {
      writeInFlight = false;
      console.error('[store] SQLite async write failed:', message.message);
      pump();
    } else if (message.type === 'closed') {
      closeResolve?.();
      closeResolve = null;
      closeReject = null;
    }
  });
  worker.on('error', (error) => {
    workerFailed = true;
    readyReject(error);
    closeReject?.(error);
    console.error('[store] SQLite persistence worker error:', error.message);
  });

  // A failed worker must not crash the HTTP process. It is safer to keep
  // serving from memory and log the persistence failure than to deadlock all
  // incoming requests on a broken SQLite connection.
  ready.catch(() => {});

  return {
    load() {
      const row = read.get('snapshot');
      return row ? JSON.parse(row.value) : null;
    },
    save(snapshot) {
      if (workerFailed) return;
      pendingSnapshot = snapshot;
      pump();
    },
    async close() {
      try { db?.close(); } catch {}
      if (workerFailed || worker.threadId === -1) return;
      try { await ready; } catch { await worker.terminate(); return; }
      // A save can be queued before the worker has finished opening SQLite.
      // Pump it before sending close, otherwise the worker could close first
      // and silently drop the final snapshot during graceful shutdown.
      pump();
      closePromise = new Promise((resolve, reject) => {
        closeResolve = resolve;
        closeReject = reject;
      });
      worker.postMessage({ type: 'close', resolveId: 'close' });
      await closePromise;
      await worker.terminate();
    }
  };
}
