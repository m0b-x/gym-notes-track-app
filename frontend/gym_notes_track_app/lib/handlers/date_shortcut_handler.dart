import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../interfaces/markdown_shortcut_handler.dart';
import '../models/custom_markdown_shortcut.dart';
import '../database/database.dart';
import '../services/settings_service.dart';

class DateShortcutHandler implements MarkdownShortcutHandler {
  String? _cachedFormat;

  Future<String> _getDefaultDateFormat() async {
    if (_cachedFormat != null) return _cachedFormat!;
    final db = await AppDatabase.getInstance();
    final format = await db.userSettingsDao.getValue(
      SettingsService.dateFormatKey,
    );
    _cachedFormat = format ?? SettingsService.defaultDateFormat;
    return _cachedFormat!;
  }

  void clearCache() {
    _cachedFormat = null;
  }

  @override
  void execute({
    required BuildContext context,
    required CustomMarkdownShortcut shortcut,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onTextChanged,
  }) async {
    final format = shortcut.dateFormat ?? await _getDefaultDateFormat();
    final currentDate = DateFormat(format).format(DateTime.now());
    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.start;

    final insertText = shortcut.beforeText + currentDate + shortcut.afterText;
    final newText =
        text.substring(0, cursorPos) + insertText + text.substring(cursorPos);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + insertText.length),
    );

    focusNode.requestFocus();
    onTextChanged();
  }
}
