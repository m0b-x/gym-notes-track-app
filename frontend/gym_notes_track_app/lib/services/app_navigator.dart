import 'package:flutter/material.dart';
import '../models/counter.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/note_metadata.dart';
import '../pages/controls_settings_page.dart';
import '../pages/counter_management_page.dart';
import '../pages/counter_per_note_page.dart';
import '../pages/database_settings_page.dart';
import '../pages/developer_options_page.dart';
import '../pages/markdown_settings_page.dart';
import '../pages/note_bar_assignment_page.dart';
import '../pages/optimized_folder_content_page.dart';
import '../pages/optimized_note_editor_page.dart';
import '../pages/search_page.dart';
import '../pages/shortcut_editor_page.dart';

enum SettingsResult { openDrawer }

abstract final class AppNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState get _navigator => navigatorKey.currentState!;

  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
  }

  static Future<T?> pushNoAnimation<T>(
    BuildContext context,
    Widget page, {
    Duration reverseTransitionDuration = const Duration(milliseconds: 150),
  }) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: reverseTransitionDuration,
      ),
    );
  }

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    TO? result,
  }) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (_) => page),
      result: result,
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  static Future<bool> maybePop<T>(BuildContext context, [T? result]) {
    return Navigator.of(context).maybePop(result);
  }

  static void popUntilFirst(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  static Future<T?> rootPush<T>(Widget page) {
    return _navigator.push<T>(MaterialPageRoute(builder: (_) => page));
  }

  static void rootPop<T>([T? result]) {
    _navigator.pop(result);
  }

  // --- Page-specific navigation ---

  static Future<void> toFolder(
    BuildContext context, {
    required String folderId,
    required String title,
  }) {
    return push(
      context,
      OptimizedFolderContentPage(folderId: folderId, title: title),
    );
  }

  static Future<void> toNoteEditor(
    BuildContext context, {
    required String folderId,
    String? noteId,
    NoteMetadata? metadata,
  }) {
    return push(
      context,
      OptimizedNoteEditorPage(
        folderId: folderId,
        noteId: noteId,
        metadata: metadata,
      ),
    );
  }

  static Future<void> toNoteEditorInstant(
    BuildContext context, {
    required String folderId,
    required String noteId,
    NoteMetadata? metadata,
  }) {
    return pushNoAnimation(
      context,
      OptimizedNoteEditorPage(
        folderId: folderId,
        noteId: noteId,
        metadata: metadata,
      ),
    );
  }

  static Future<void> toSearch(BuildContext context, {String? folderId}) {
    return push(context, SearchPage(folderId: folderId));
  }

  static Future<SettingsResult?> toDatabaseSettings(BuildContext context) {
    return push<SettingsResult>(context, const DatabaseSettingsPage());
  }

  static Future<SettingsResult?> toControlsSettings(BuildContext context) {
    return push<SettingsResult>(context, const ControlsSettingsPage());
  }

  static Future<SettingsResult?> toMarkdownSettings(
    BuildContext context, {
    required List<CustomMarkdownShortcut> allShortcuts,
  }) {
    return push<SettingsResult>(
      context,
      MarkdownSettingsPage(allShortcuts: allShortcuts),
    );
  }

  static Future<SettingsResult?> toCounterManagement(
    BuildContext context, {
    String? noteId,
  }) {
    return push<SettingsResult>(context, CounterManagementPage(noteId: noteId));
  }

  static Future<void> toCounterPerNote(
    BuildContext context, {
    required Counter counter,
  }) {
    return push(context, CounterPerNotePage(counter: counter));
  }

  static Future<SettingsResult?> toDeveloperOptions(BuildContext context) {
    return push<SettingsResult>(context, const DeveloperOptionsPage());
  }

  static Future<void> toShortcutEditor(
    BuildContext context, {
    CustomMarkdownShortcut? shortcut,
    required Function(CustomMarkdownShortcut) onSave,
  }) {
    return push(
      context,
      ShortcutEditorPage(shortcut: shortcut, onSave: onSave),
    );
  }

  static Future<void> toNoteBarAssignment(BuildContext context) {
    return push(context, const NoteBarAssignmentPage());
  }
}
