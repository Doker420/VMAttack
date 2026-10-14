import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createSqliteStore } from '../web/sqlite-store.mjs';

test('SQLite persistence worker coalesces writes and flushes the latest snapshot', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'poslaniya-sqlite-'));
  const file = join(directory, 'state.sqlite');
  const store = await createSqliteStore(file);
  assert.ok(store, 'SQLite driver must be available for this test');
  store.save({ revision: 1, messages: [] });
  store.save({ revision: 2, messages: [{ id: 'latest' }] });
  await store.close();

  const reopened = await createSqliteStore(file);
  assert.deepEqual(reopened.load(), { revision: 2, messages: [{ id: 'latest' }] });
  await reopened.close();
  await rm(directory, { recursive: true, force: true });
});
