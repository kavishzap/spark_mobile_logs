import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class CallQueueDatabase {
  CallQueueDatabase({this.factory, this.path});

  final DatabaseFactory? factory;
  final String? path;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return Future<Database>.value(existing);
    }
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// Runs [action] on an open database. A closed connection is dropped and
  /// the action runs once more on a new connection.
  Future<T> run<T>(Future<T> Function(Database db) action) async {
    try {
      return await action(await database);
    } on DatabaseException catch (error) {
      if (!_isClosed(error)) {
        rethrow;
      }
      await _discard();
      return action(await database);
    }
  }

  Future<Database> _open() async {
    final resolvedFactory = factory ?? databaseFactory;
    final resolvedPath =
        path ?? p.join(await getDatabasesPath(), 'spark_sales_calls.db');
    final opened = await resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE calls (
              android_call_id TEXT PRIMARY KEY,
              phone_number TEXT NOT NULL,
              call_type TEXT NOT NULL,
              call_date TEXT NOT NULL,
              call_date_millis INTEGER NOT NULL,
              duration_seconds INTEGER NOT NULL,
              sync_status TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_attempt_at TEXT,
              last_error TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_calls_status ON calls(sync_status, call_date_millis)',
          );
          await db.execute(
            'CREATE INDEX idx_calls_date ON calls(call_date_millis)',
          );
        },
      ),
    );
    _database = opened;
    return opened;
  }

  Future<void> _discard() async {
    final existing = _database;
    _database = null;
    if (existing == null) {
      return;
    }
    try {
      if (existing.isOpen) {
        await existing.close();
      }
    } catch (_) {
      // The handle is already closed. The next open creates a new one.
    }
  }

  Future<void> close() => _discard();

  bool _isClosed(DatabaseException error) {
    return error.toString().contains('database_closed');
  }
}
