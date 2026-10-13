import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

/**
 * Small SQLite adapter for local development.
 * Production can replace it with PostgreSQL without changing the API layer.
 */
export function createSqliteStore(filePath) {
  mkdirSync(dirname(filePath), { recursive: true });
  const db = new DatabaseSync(filePath);
  db.exec(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS app_state (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);
  const read = db.prepare('SELECT value FROM app_state WHERE key = ?');
  const write = db.prepare(`
    INSERT INTO app_state (key, value, updated_at) VALUES (?, ?, ?)
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
  `);

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
