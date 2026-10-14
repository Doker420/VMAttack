import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

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

/**
 * Small SQLite adapter for local development.
 * On Node 20 install the optional better-sqlite3 dependency first.
 * Production can replace it with PostgreSQL without changing the API layer.
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
  let write;
  try {
    db = new driver.Database(filePath);
    if (driver.type === 'better') db.pragma('journal_mode = WAL');
    else db.exec('PRAGMA journal_mode = WAL;');
    db.exec(`
      CREATE TABLE IF NOT EXISTS app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    read = db.prepare('SELECT value FROM app_state WHERE key = ?');
    write = db.prepare(`
      INSERT INTO app_state (key, value, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
    `);
  } catch (error) {
    try { db?.close(); } catch {}
    console.warn(`[store] SQLite driver failed to open; using JSON fallback: ${error.message}`);
    return null;
  }

  return {
    load() {
      const row = read.get('snapshot');
      return row ? JSON.parse(row.value) : null;
    },
    save(snapshot) {
      write.run('snapshot', JSON.stringify(snapshot), new Date().toISOString());
    },
    close() {
      db.close();
    }
  };
}
