import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'tables/folders_table.dart';
import 'tables/notes_table.dart';
import 'tables/content_chunks_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/user_settings_table.dart';
import 'daos/folder_dao.dart';
import 'daos/note_dao.dart';
import 'daos/content_chunk_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/user_settings_dao.dart';
import 'crdt/hlc.dart';
import 'loading_interceptor.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Folders, Notes, ContentChunks, SyncMetadata, UserSettings],
  daos: [FolderDao, NoteDao, ContentChunkDao, SyncDao, UserSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  final String _deviceId;
  late final HybridLogicalClock hlc;

  AppDatabase._internal(super.e, this._deviceId) {
    hlc = HybridLogicalClock(nodeId: _deviceId);
  }

  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;

    final deviceId = await _getOrCreateDeviceId();
    _instance = AppDatabase._internal(_openConnection(), deviceId);
    return _instance!;
  }

  /// Closes the database and deletes all data files.
  /// After calling this, the app should be restarted.
  static Future<void> deleteAllData() async {
    // Close the current instance if it exists
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }

    // Get the database folder path
    final dbFolder = await getApplicationDocumentsDirectory();
    final gymNotesDir = Directory(p.join(dbFolder.path, 'gym_notes'));

    // Delete the entire gym_notes directory (includes db, device_id, etc.)
    if (await gymNotesDir.exists()) {
      await gymNotesDir.delete(recursive: true);
    }
  }

  static Future<String> _getOrCreateDeviceId() async {
    final directory = await getApplicationDocumentsDirectory();
    final deviceFile = File(p.join(directory.path, 'gym_notes', 'device_id'));

    if (await deviceFile.exists()) {
      return await deviceFile.readAsString();
    }

    final deviceId = const Uuid().v4();
    await deviceFile.parent.create(recursive: true);
    await deviceFile.writeAsString(deviceId);
    return deviceId;
  }

  String get deviceId => _deviceId;

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(userSettings);
        }
        if (from < 3) {
          // Add isDeleted column to content_chunks for CRDT consistency
          await m.addColumn(contentChunks, contentChunks.isDeleted);
          // Add new indexes
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC) WHERE is_deleted = 0',
          );
          // Drop redundant index if exists
          await customStatement('DROP INDEX IF EXISTS idx_chunks_note');
        }
        if (from < 4) {
          // Add position column for manual ordering
          await m.addColumn(folders, folders.position);
          await m.addColumn(notes, notes.position);
          // Initialize positions based on creation date
          await customStatement('''
            UPDATE folders SET position = (
              SELECT COUNT(*) FROM folders f2 
              WHERE f2.created_at < folders.created_at 
              AND COALESCE(f2.parent_id, '') = COALESCE(folders.parent_id, '')
              AND f2.is_deleted = 0
            ) WHERE is_deleted = 0
          ''');
          await customStatement('''
            UPDATE notes SET position = (
              SELECT COUNT(*) FROM notes n2 
              WHERE n2.created_at < notes.created_at 
              AND n2.folder_id = notes.folder_id
              AND n2.is_deleted = 0
            ) WHERE is_deleted = 0
          ''');
          // Add position indexes
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_folders_position ON folders(parent_id, position) WHERE is_deleted = 0',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_position ON notes(folder_id, position) WHERE is_deleted = 0',
          );
        }
      },
    );
  }

  Future<void> _createIndexes(Migrator m) async {
    // Folder indexes
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id) WHERE is_deleted = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_hlc ON folders(hlc_timestamp)',
    );

    // Note indexes - covering common query patterns
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id) WHERE is_deleted = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_hlc ON notes(hlc_timestamp)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC) WHERE is_deleted = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC) WHERE is_deleted = 0',
    );

    // Chunk indexes - composite only (single column index is redundant)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chunks_note_index ON content_chunks(note_id, chunk_index) WHERE is_deleted = 0',
    );
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(title, preview, content=notes, content_rowid=rowid)',
    );
  }

  Future<void> rebuildFtsIndex() async {
    await customStatement("INSERT INTO notes_fts(notes_fts) VALUES('rebuild')");
  }

  Future<void> vacuum() async {
    await customStatement('VACUUM');
  }

  String generateHlc() {
    return hlc.now().toString();
  }

  String generateId() {
    return const Uuid().v4();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gym_notes', 'gym_notes.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(
      file,
    ).interceptWith(LoadingQueryInterceptor());
  });
}
