import 'package:drift/drift.dart';
import '../database.dart';
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
}
