import 'package:intl/intl.dart';
import 'package:re_editor/re_editor.dart';

import '../models/custom_markdown_shortcut.dart';

/// Async callback that increments [counterId] and returns the new value.
/// Returns `null` when the counter doesn't exist or isn't loaded.
typedef CounterIncrementer = Future<int?> Function(String counterId);

/// Applies a [CustomMarkdownShortcut] to a [CodeLineEditingController].
///
/// Extracted from `OptimizedNoteEditorPage` so the body of the
/// per-shortcut switch (date / header / counter / wrapper) can live
/// outside the page widget. Callers stay responsible for the
/// surrounding undo wrapper and post-apply housekeeping.
class ShortcutApplier {
  ShortcutApplier._();

  static Future<void> apply({
    required CodeLineEditingController controller,
    required CustomMarkdownShortcut shortcut,
    required CounterIncrementer incrementCounter,
  }) async {
    final selectedText = controller.selectedText;
    final repeatCount = shortcut.repeatConfig?.count ?? 1;
    final separator = shortcut.repeatConfig?.separator ?? '\n';
    final beforeRepeatText = shortcut.repeatConfig?.beforeRepeatText ?? '';
    final afterRepeatText = shortcut.repeatConfig?.afterRepeatText ?? '';

    switch (shortcut.insertType) {
      case 'date':
        _applyDate(
          controller: controller,
          shortcut: shortcut,
          selectedText: selectedText,
          repeatCount: repeatCount,
          separator: separator,
          beforeRepeatText: beforeRepeatText,
          afterRepeatText: afterRepeatText,
        );
        return;
      case 'header':
        _applyHeader(controller);
        return;
      case 'counter':
        await _applyCounter(
          controller: controller,
          shortcut: shortcut,
          incrementCounter: incrementCounter,
        );
        return;
      default:
        _applyWrapper(
          controller: controller,
          shortcut: shortcut,
          selectedText: selectedText,
          repeatCount: repeatCount,
          separator: separator,
          beforeRepeatText: beforeRepeatText,
          afterRepeatText: afterRepeatText,
        );
    }
  }

  static void _applyDate({
    required CodeLineEditingController controller,
    required CustomMarkdownShortcut shortcut,
    required String selectedText,
    required int repeatCount,
    required String separator,
    required String beforeRepeatText,
    required String afterRepeatText,
  }) {
    final format = shortcut.dateFormat ?? 'yyyy-MM-dd';
    final dateOffset = shortcut.dateOffset;
    final repeatConfig = shortcut.repeatConfig;

    var baseDate = DateTime.now();
    if (dateOffset != null) {
      baseDate = DateTime(
        baseDate.year + dateOffset.years,
        baseDate.month + dateOffset.months,
        baseDate.day + dateOffset.days,
      );
    }

    final results = <String>[];
    for (int i = 0; i < repeatCount; i++) {
      var date = baseDate;
      if (repeatConfig != null && repeatConfig.incrementDate && i > 0) {
        date = DateTime(
          baseDate.year + (repeatConfig.dateIncrementYears * i),
          baseDate.month + (repeatConfig.dateIncrementMonths * i),
          baseDate.day + (repeatConfig.dateIncrementDays * i),
        );
      }
      final formatted = DateFormat(format).format(date);
      final middle = selectedText.isNotEmpty && i == 0
          ? selectedText
          : formatted;
      results.add('${shortcut.beforeText}$middle${shortcut.afterText}');
    }

    var wrapped = results.join(separator);
    if (beforeRepeatText.isNotEmpty || afterRepeatText.isNotEmpty) {
      wrapped = '$beforeRepeatText$wrapped$afterRepeatText';
    }
    controller.replaceSelection(wrapped);
  }

  static void _applyHeader(CodeLineEditingController controller) {
    final selection = controller.selection;
    final lineIndex = selection.startIndex;
    final line = controller.codeLines[lineIndex];
    final lineText = line.text;

    final headerMatch = RegExp(r'^(#{1,6})\s').firstMatch(lineText);
    String newLineText;

    if (headerMatch != null) {
      final currentHashes = headerMatch.group(1)!;
      final textWithoutHeader = lineText.substring(headerMatch.end);
      newLineText = currentHashes.length >= 6
          ? textWithoutHeader
          : '$currentHashes# $textWithoutHeader';
    } else {
      newLineText = '# $lineText';
    }

    controller.selectLine(lineIndex);
    controller.replaceSelection(newLineText);
  }

  static Future<void> _applyCounter({
    required CodeLineEditingController controller,
    required CustomMarkdownShortcut shortcut,
    required CounterIncrementer incrementCounter,
  }) async {
    final counterId = shortcut.counterId;
    if (counterId == null) return;
    final value = await incrementCounter(counterId);
    if (value == null) return;
    final insertText = '${shortcut.beforeText}$value${shortcut.afterText}';
    controller.replaceSelection(insertText);
  }

  static void _applyWrapper({
    required CodeLineEditingController controller,
    required CustomMarkdownShortcut shortcut,
    required String selectedText,
    required int repeatCount,
    required String separator,
    required String beforeRepeatText,
    required String afterRepeatText,
  }) {
    final before = shortcut.beforeText;
    final after = shortcut.afterText;
    final isSymmetricWrapper =
        before == after && before.isNotEmpty && after.isNotEmpty;

    String wrapped;
    if (selectedText.isEmpty && isSymmetricWrapper) {
      wrapped = before;
    } else {
      wrapped = '$before$selectedText$after';
    }

    if (repeatCount > 1) {
      wrapped = List.filled(repeatCount, wrapped).join(separator);
    }
    if (beforeRepeatText.isNotEmpty || afterRepeatText.isNotEmpty) {
      wrapped = '$beforeRepeatText$wrapped$afterRepeatText';
    }
    controller.replaceSelection(wrapped);
  }
}
