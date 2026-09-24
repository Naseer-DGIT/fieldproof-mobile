import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../logging/secure_logger.dart';
import '../security/key_store.dart';

/// The FieldProof encrypted database.
///
/// Open tries three key aliases in order (primary, next, previous) to
/// survive a crash during a rekey. See docs/security/s5-mobile-rekey.md.
class AppDatabase {
  AppDatabase._();

  static const _fileName = 'fieldproof.db';
  static const _schemaVersion = 1;
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  /// Test-only: force a new open. Does not delete the file.
  static Future<void> reset() async {
    await _db?.close();
    _db = null;
  }

  /// Which alias the DB was opened with. Used by rekey to know what
  /// the "old key" is.
  static String? _activeKeyAlias;

  static String? get activeKeyAlias => _activeKeyAlias;

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);

    // Primary path: ensure a key exists and try to open.
    final primaryKey = await KeyStore.getOrCreateDbKey();

    final attempt = await _tryOpen(path, primaryKey);
    if (attempt != null) {
      _activeKeyAlias = 'primary';
      SecureLogger.i('db.opened', data: {'key_alias': 'primary'});
      return attempt;
    }

    // Fallback 1: the rekey wrote a new key but did not promote it.
    final nextKey = await KeyStore.getNextDbKey();
    if (nextKey != null) {
      final opened = await _tryOpen(path, nextKey);
      if (opened != null) {
        // Promote the next key to primary. Clear the stale prev.
        await KeyStore.setDbKey(nextKey);
        await KeyStore.clearNextDbKey();
        await KeyStore.clearPrevDbKey();
        _activeKeyAlias = 'primary';
        SecureLogger.w('db.recovered_promoted_next_key');
        return opened;
      }
    }

    // Fallback 2: the rekey promoted a new primary but the write failed,
    // so the DB is still on the old key.
    final prevKey = await KeyStore.getPrevDbKey();
    if (prevKey != null) {
      final opened = await _tryOpen(path, prevKey);
      if (opened != null) {
        await KeyStore.setDbKey(prevKey);
        await KeyStore.clearNextDbKey();
        await KeyStore.clearPrevDbKey();
        _activeKeyAlias = 'primary';
        SecureLogger.w('db.recovered_demoted_prev_key');
        return opened;
      }
    }

    // Every alias failed. The DB is unrecoverable. Log and clear state
    // so the app can start fresh.
    SecureLogger.e('db.unrecoverable');
    throw StateError('fieldproof.db is not readable with any stored key');
  }

  static Future<Database?> _tryOpen(String path, String key) async {
    try {
      final db = await openDatabase(
        path,
        password: key,
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      );
      return db;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        signature TEXT NOT NULL,
        previous_hash TEXT,
        idempotency_key TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_queue_status
        ON attendance_queue (sync_status, created_at)
    ''');

    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    SecureLogger.i('db.schema.created', data: {'version': version});
  }

  /// Two-phase rekey. Safe to interrupt at any point; the next open
  /// recovers.
  ///
  /// 1. Generate a new key and store it in the `next` alias.
  /// 2. Run PRAGMA rekey with the new key.
  /// 3. Copy the old key to `prev`.
  /// 4. Promote the new key to primary.
  /// 5. Clear `next` and `prev`.
  ///
  /// If the process dies:
  ///   - Before step 2: DB is on the old key; next open clears next.
  ///   - Between 2 and 4: DB is on the new key; next open promotes it.
  ///   - Between 4 and 5: DB is on the new key; next open clears the rest.
  static Future<void> rekey() async {
    final db = await instance;
    final oldKey = await KeyStore.getDbKey();
    if (oldKey == null) {
      throw StateError('No primary DB key to rekey from');
    }

    final newKey = KeyStore.generateDbKey();

    // Phase 1: stage
    await KeyStore.setNextDbKey(newKey);

    // Phase 2: rekey the DB itself
    await db.execute("PRAGMA rekey = '$newKey'");

    // Phase 3: keep the old key as prev (safety net for one open cycle)
    await KeyStore.setPrevDbKey(oldKey);

    // Phase 4: promote
    await KeyStore.setDbKey(newKey);

    // Phase 5: clean
    await KeyStore.clearNextDbKey();
    await KeyStore.clearPrevDbKey();

    await KeyStore.setLastRekeyAt(DateTime.now().toUtc());
    SecureLogger.w('db.rekeyed');
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
