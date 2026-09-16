import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../logging/secure_logger.dart';
import '../security/key_store.dart';

/// FieldProof encrypted database.
///
/// One DB, one key (ADR-0002). No second persistence path — no Hive,
/// no SharedPreferences for app state, no unencrypted key-value store.
///
/// Schema (S1 baseline):
///   attendance_queue — offline events awaiting sync (S2 fills this)
///   app_state        — non-secret app-level key/value (schema version,
///                      install id, last sync cursor)
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

  static Future<Database> _open() async {
    final key = await KeyStore.getOrCreateDbKey();
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);

    final db = await openDatabase(
      path,
      password: key,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );

    SecureLogger.i('db.opened', data: {'version': _schemaVersion});
    return db;
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
}
