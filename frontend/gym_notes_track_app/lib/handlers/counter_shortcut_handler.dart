import 'package:flutter/material.dart';

import '../interfaces/markdown_shortcut_handler.dart';
import '../models/custom_markdown_shortcut.dart';
import '../services/counter_service.dart';

class CounterShortcutHandler implements MarkdownShortcutHandler {
  String? _activeNoteId;

  void setActiveNoteId(String? noteId) {
    _activeNoteId = noteId;
  }

  @override
  void execute({
    required BuildContext context,
    required CustomMarkdownShortcut shortcut,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onTextChanged,
  }) async {
    final counterId = shortcut.counterId;
    if (counterId == null) return;

    final counterService = await CounterService.getInstance();
    final counter = counterService.getCounterById(counterId);
    if (counter == null) return;

    final currentValue = await counterService.increment(
      counterId,
      noteId: _activeNoteId,
    );

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    final valueStr = currentValue.toString();
    final insertText =
        '${shortcut.beforeText}$valueStr${shortcut.afterText}';

    final newText =
        text.substring(0, start) + insertText + text.substring(end);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );

    focusNode.requestFocus();
    onTextChanged();
  }
}
