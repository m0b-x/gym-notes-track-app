import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';
import '../constants/json_keys.dart';

class BackupService {
  static BackupService? _instance;
  late AppDatabase _db;

  BackupService._();

  static Future<BackupService> getInstance() async {
    if (_instance == null) {
      _instance = BackupService._();
      _instance!._db = await AppDatabase.getInstance();
    }
    return _instance!;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final folders = await _db.folderDao.getAllFolders(includeDeleted: false);
    final notes = await _db.noteDao.getAllNotes(includeDeleted: false);

    final notesWithContent = <Map<String, dynamic>>[];
    for (final note in notes) {
      final content = await _db.contentChunkDao.loadContent(note.id);
      notesWithContent.add({
        JsonKeys.id: note.id,
        JsonKeys.folderId: note.folderId,
        JsonKeys.title: note.title,
        JsonKeys.content: content,
        JsonKeys.preview: note.preview,
        JsonKeys.createdAt: note.createdAt.toIso8601String(),
        JsonKeys.updatedAt: note.updatedAt.toIso8601String(),
      });
    }

    final foldersData = folders.map((f) => {
      JsonKeys.id: f.id,
      JsonKeys.name: f.name,
      JsonKeys.parentId: f.parentId,
      'position': f.position,
      JsonKeys.createdAt: f.createdAt.toIso8601String(),
      JsonKeys.updatedAt: f.updatedAt.toIso8601String(),
      JsonKeys.noteSortOrder: f.noteSortOrder,
      JsonKeys.subfolderSortOrder: f.subfolderSortOrder,
    }).toList();

    final shortcuts = await _db.userSettingsDao.getValue('markdown_shortcuts');
    final settings = await _exportSettings();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': foldersData,
      'notes': notesWithContent,
      'markdownShortcuts': shortcuts,
      'settings': settings,
    };
  }

  Future<Map<String, dynamic>> _exportSettings() async {
    final settingsKeys = [
      'preview_font_size',
      'editor_font_size',
      'locale',
      'theme_mode',
      'date_format',
      'folder_swipe_enabled',
      'note_swipe_enabled',
      'confirm_delete',
      'auto_save_enabled',
      'auto_save_interval',
      'show_note_preview',
      'show_stats_bar',
      'haptic_feedback',
      'show_line_numbers',
      'word_wrap',
      'show_cursor_line',
    ];

    final settings = <String, dynamic>{};
    for (final key in settingsKeys) {
      final value = await _db.userSettingsDao.getValue(key);
      if (value != null) {
        settings[key] = value;
      }
    }
    return settings;
  }

  Future<String> exportToFile() async {
    final data = await exportAllData();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'gym_notes_backup_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonString);

    return file.path;
  }

  Future<void> shareBackup() async {
    final filePath = await exportToFile();
    await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
  }

  Future<BackupValidationResult> validateBackup(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!data.containsKey('folders') || !data.containsKey('notes')) {
        return BackupValidationResult(
          isValid: false,
          error: 'Invalid backup format: missing folders or notes',
        );
      }

      final folders = data['folders'] as List;
      final notes = data['notes'] as List;

      return BackupValidationResult(
        isValid: true,
        folderCount: folders.length,
        noteCount: notes.length,
        exportedAt: data['exportedAt'] as String?,
        version: data['version'] as int? ?? 1,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        error: 'Failed to parse backup: $e',
      );
    }
  }

  Future<ImportResult> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final folders = data['folders'] as List? ?? [];
      final notes = data['notes'] as List? ?? [];
      final settings = data['settings'] as Map<String, dynamic>? ?? {};
      final markdownShortcuts = data['markdownShortcuts'] as String?;

      int foldersImported = 0;
      int notesImported = 0;

      for (final folderData in folders) {
        final map = folderData as Map<String, dynamic>;
        await _db.folderDao.createFolder(
          name: map[JsonKeys.name] as String,
          parentId: map[JsonKeys.parentId] as String?,
        );
        foldersImported++;
      }

      for (final noteData in notes) {
        final map = noteData as Map<String, dynamic>;
        final content = map[JsonKeys.content] as String? ?? '';
        final preview = content.length > 200 ? content.substring(0, 200) : content;

        final note = await _db.noteDao.createNote(
          folderId: map[JsonKeys.folderId] as String,
          title: map[JsonKeys.title] as String,
          preview: preview,
          contentLength: content.length,
          chunkCount: 1,
        );

        await _db.contentChunkDao.saveContent(noteId: note.id, content: content);
        notesImported++;
      }

      for (final entry in settings.entries) {
        await _db.userSettingsDao.setValue(entry.key, entry.value.toString());
      }

      if (markdownShortcuts != null) {
        await _db.userSettingsDao.setValue('markdown_shortcuts', markdownShortcuts);
      }

      return ImportResult(
        success: true,
        foldersImported: foldersImported,
        notesImported: notesImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> hasExistingData() async {
    final folderCount = await _db.folderDao.getFolderCount(null);
    final noteCount = await _db.noteDao.getNoteCount(null);
    return folderCount > 0 || noteCount > 0;
  }
}

class BackupValidationResult {
  final bool isValid;
  final String? error;
  final int folderCount;
  final int noteCount;
  final String? exportedAt;
  final int version;

  const BackupValidationResult({
    required this.isValid,
    this.error,
    this.folderCount = 0,
    this.noteCount = 0,
    this.exportedAt,
    this.version = 1,
  });
}

class ImportResult {
  final bool success;
  final String? error;
  final int foldersImported;
  final int notesImported;

  const ImportResult({
    required this.success,
    this.error,
    this.foldersImported = 0,
    this.notesImported = 0,
  });
}
