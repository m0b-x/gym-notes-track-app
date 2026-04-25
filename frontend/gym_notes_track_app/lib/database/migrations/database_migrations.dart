import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import 'database_indexes.dart';
import 'database_schema.dart';

class DatabaseMigrations {
  final AppDatabase _db;

  DatabaseMigrations(this._db);

  List<Migration> get _migrations => [
    Migration(
      fromVersion: DatabaseSchema.v1Initial,
      toVersion: DatabaseSchema.v2UserSettings,
      migrate: _migrateV1ToV2,
    ),
    Migration(
      fromVersion: DatabaseSchema.v2UserSettings,
      toVersion: DatabaseSchema.v3ContentChunksIsDeleted,
      migrate: _migrateV2ToV3,
    ),
    Migration(
      fromVersion: DatabaseSchema.v3ContentChunksIsDeleted,
      toVersion: DatabaseSchema.v4ManualOrdering,
      migrate: _migrateV3ToV4,
    ),
    Migration(
      fromVersion: DatabaseSchema.v4ManualOrdering,
      toVersion: DatabaseSchema.v5FolderSortPreferences,
      migrate: _migrateV4ToV5,
    ),
    Migration(
      fromVersion: DatabaseSchema.v5FolderSortPreferences,
      toVersion: DatabaseSchema.v6CounterTables,
      migrate: _migrateV5ToV6,
    ),
    Migration(
      fromVersion: DatabaseSchema.v6CounterTables,
      toVersion: DatabaseSchema.v7CounterDateTimeFix,
      migrate: _migrateV6ToV7,
    ),
    Migration(
      fromVersion: DatabaseSchema.v7CounterDateTimeFix,
      toVersion: DatabaseSchema.v8CounterPinAndOrder,
      migrate: _migrateV7ToV8,
    ),
    Migration(
      fromVersion: DatabaseSchema.v8CounterPinAndOrder,
      toVersion: DatabaseSchema.v9NameUniquenessIndexes,
      migrate: _migrateV8ToV9,
    ),
  ];

  Future<void> runMigrations(Migrator m, int from, int to) async {
    for (final migration in _migrations) {
      if (from < migration.toVersion && to >= migration.toVersion) {
        await migration.migrate(m, _db);
      }
    }
  }

  Future<void> _migrateV1ToV2(Migrator m, GeneratedDatabase db) async {
    await m.createTable(_db.userSettings);
  }

  Future<void> _migrateV2ToV3(Migrator m, GeneratedDatabase db) async {
    await m.addColumn(_db.contentChunks, _db.contentChunks.isDeleted);
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC) WHERE is_deleted = 0',
    );
    await _db.customStatement('DROP INDEX IF EXISTS idx_chunks_note');
  }

  Future<void> _migrateV3ToV4(Migrator m, GeneratedDatabase db) async {
    await m.addColumn(_db.folders, _db.folders.position);
    await m.addColumn(_db.notes, _db.notes.position);

    await _initializeFolderPositions();
    await _initializeNotePositions();
    await _createPositionIndexes();
  }

  Future<void> _initializeFolderPositions() async {
    await _db.customStatement('''
      UPDATE folders SET position = (
        SELECT COUNT(*) FROM folders f2 
        WHERE f2.created_at < folders.created_at 
        AND COALESCE(f2.parent_id, '') = COALESCE(folders.parent_id, '')
        AND f2.is_deleted = 0
      ) WHERE is_deleted = 0
    ''');
  }

  Future<void> _initializeNotePositions() async {
    await _db.customStatement('''
      UPDATE notes SET position = (
        SELECT COUNT(*) FROM notes n2 
        WHERE n2.created_at < notes.created_at 
        AND n2.folder_id = notes.folder_id
        AND n2.is_deleted = 0
      ) WHERE is_deleted = 0
    ''');
  }

  Future<void> _createPositionIndexes() async {
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_position ON folders(parent_id, position) WHERE is_deleted = 0',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_position ON notes(folder_id, position) WHERE is_deleted = 0',
    );
  }

  Future<void> _migrateV4ToV5(Migrator m, GeneratedDatabase db) async {
    // Add sort preference columns to folders table
    await m.addColumn(_db.folders, _db.folders.noteSortOrder);
    await m.addColumn(_db.folders, _db.folders.subfolderSortOrder);
  }

  Future<void> _migrateV5ToV6(Migrator m, GeneratedDatabase db) async {
    // 1. Create the new tables using raw SQL (schema as of v6, without
    //    isPinned/position columns that were added in v8)
    await _db.customStatement(
      'CREATE TABLE IF NOT EXISTS counters ('
      '  id TEXT NOT NULL PRIMARY KEY, '
      '  name TEXT NOT NULL, '
      '  start_value INTEGER NOT NULL DEFAULT 1, '
      '  step INTEGER NOT NULL DEFAULT 1, '
      '  scope TEXT NOT NULL DEFAULT \'global\', '
      '  position INTEGER NOT NULL DEFAULT 0, '
      '  created_at INTEGER NOT NULL'
      ')',
    );
    await _db.customStatement(
      'CREATE TABLE IF NOT EXISTS counter_values ('
      '  counter_id TEXT NOT NULL, '
      '  note_id TEXT NOT NULL DEFAULT \'\', '
      '  value INTEGER NOT NULL, '
      '  PRIMARY KEY (counter_id, note_id)'
      ')',
    );

    // 2. Create index on counter_values for fast lookups by counter_id
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_counter_values_counter '
      'ON counter_values(counter_id)',
    );

    // 3. Migrate existing JSON data from user_settings
    await _migrateCounterJsonToTables();

    // 4. Clean up old JSON keys
    await _db.customStatement(
      "DELETE FROM user_settings WHERE key = 'counters'",
    );
    await _db.customStatement(
      "DELETE FROM user_settings WHERE key = 'counter_global_values'",
    );
    await _db.customStatement(
      "DELETE FROM user_settings WHERE key LIKE 'counter_note_values_%'",
    );
  }

  Future<void> _migrateV6ToV7(Migrator m, GeneratedDatabase db) async {
    await _db.customStatement(
      "UPDATE counters "
      "SET created_at = CAST(strftime('%s', created_at) AS INTEGER) * 1000 "
      "WHERE typeof(created_at) = 'text'",
    );
  }

  Future<void> _migrateCounterJsonToTables() async {
    // Read existing counter definitions
    final countersRaw = await _db.userSettingsDao.getValue('counters');
    if (countersRaw == null) return;

    List<dynamic> countersList;
    try {
      countersList = jsonDecode(countersRaw) as List<dynamic>;
    } catch (_) {
      return;
    }

    // Insert counter definitions
    for (var i = 0; i < countersList.length; i++) {
      final c = countersList[i] as Map<String, dynamic>;
      final id = c['id'] as String;
      final name = c['name'] as String? ?? 'Counter';
      final startValue = c['start_value'] as int? ?? 1;
      final step = c['step'] as int? ?? 1;
      final scope = c['scope'] as String? ?? 'global';
      final createdAtStr =
          c['created_at'] as String? ?? DateTime.now().toIso8601String();
      final createdAtMs =
          DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;

      await _db.customStatement(
        'INSERT OR IGNORE INTO counters (id, name, start_value, step, scope, position, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [id, name, startValue, step, scope, i, createdAtMs],
      );
    }

    // Migrate global values
    final globalRaw = await _db.userSettingsDao.getValue(
      'counter_global_values',
    );
    if (globalRaw != null) {
      try {
        final globalMap = jsonDecode(globalRaw) as Map<String, dynamic>;
        for (final entry in globalMap.entries) {
          await _db.customStatement(
            'INSERT OR IGNORE INTO counter_values (counter_id, note_id, value) '
            'VALUES (?, ?, ?)',
            [entry.key, '', entry.value as int],
          );
        }
      } catch (_) {}
    }

    // Migrate per-note values
    final allSettings = await _db.userSettingsDao.getAllSettings();
    for (final entry in allSettings.entries) {
      if (!entry.key.startsWith('counter_note_values_')) continue;
      final noteId = entry.key.substring('counter_note_values_'.length);
      try {
        final noteMap = jsonDecode(entry.value) as Map<String, dynamic>;
        for (final valEntry in noteMap.entries) {
          await _db.customStatement(
            'INSERT OR IGNORE INTO counter_values (counter_id, note_id, value) '
            'VALUES (?, ?, ?)',
            [valEntry.key, noteId, valEntry.value as int],
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _migrateV7ToV8(Migrator m, GeneratedDatabase db) async {
    await _db.customStatement(
      'ALTER TABLE counters ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
    );
    await _db.customStatement(
      'ALTER TABLE counter_values ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
    );
    await _db.customStatement(
      'ALTER TABLE counter_values ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// v8→v9: Add expression indexes that back the per-parent name
  /// uniqueness queries. The new indexes cover
  /// `(COALESCE(parent_id,''), LOWER(TRIM(name)))` for folders and
  /// `(folder_id, LOWER(TRIM(title)))` for notes, both partial on
  /// `is_deleted = 0`. CREATE INDEX IF NOT EXISTS makes this idempotent
  /// for fresh installs (where createAllIndexes already created them).
  Future<void> _migrateV8ToV9(Migrator m, GeneratedDatabase db) async {
    await DatabaseIndexes(_db).createUniqueNameIndexes();
  }
}
