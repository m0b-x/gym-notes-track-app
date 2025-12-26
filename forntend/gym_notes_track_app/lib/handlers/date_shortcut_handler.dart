import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../interfaces/markdown_shortcut_handler.dart';
import '../models/custom_markdown_shortcut.dart';

class DateShortcutHandler implements MarkdownShortcutHandler {
  @override
  void execute({
    required BuildContext context,
    required CustomMarkdownShortcut shortcut,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onTextChanged,
  }) {
    final currentDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.start;

    final insertText = shortcut.beforeText + currentDate + shortcut.afterText;
    final newText = text.substring(0, cursorPos) + insertText + text.substring(cursorPos);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + insertText.length),
    );

    focusNode.requestFocus();
    onTextChanged();
  }
}
