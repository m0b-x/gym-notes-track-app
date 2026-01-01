import '../database.dart';

class DatabaseIndexes {
  final AppDatabase _db;

  DatabaseIndexes(this._db);

  Future<void> createAllIndexes() async {
    await _createFolderIndexes();
    await _createNoteIndexes();
    await _createChunkIndexes();
    await _createFtsTable();
  }

  Future<void> _createFolderIndexes() async {
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id) WHERE is_deleted = 0',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_hlc ON folders(hlc_timestamp)',
    );
  }

  Future<void> _createNoteIndexes() async {
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id) WHERE is_deleted = 0',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_hlc ON notes(hlc_timestamp)',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC) WHERE is_deleted = 0',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC) WHERE is_deleted = 0',
    );
  }

  Future<void> _createChunkIndexes() async {
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chunks_note_index ON content_chunks(note_id, chunk_index) WHERE is_deleted = 0',
    );
  }

  Future<void> _createFtsTable() async {
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(title, preview, content=notes, content_rowid=rowid)',
    );
  }
}
