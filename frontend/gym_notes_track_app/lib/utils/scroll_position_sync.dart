import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';

import '../constants/markdown_constants.dart';

class ScrollPositionSync {
  final ScrollController previewScrollController;
  final CodeScrollController editorScrollController;

  // Platform keyboard animation durations (approximate)
  // Android: 300ms, iOS: 250ms
  static int get _keyboardAnimationMs => Platform.isIOS ? 250 : 300;

  CodeLineSelection? _savedEditorSelection;
  int _savedEditorLineIndex = 0;
  int _savedTotalLines = 1;

  ScrollPositionSync({
    required this.previewScrollController,
    required this.editorScrollController,
  });

  void syncScrollOnModeSwitch({
    required bool switchingToPreviewMode,
    required String content,
    required double editorFontSize,
    required double previewFontSize,
    required bool Function() isMounted,
    required CodeLineEditingController contentController,
  }) {
    if (switchingToPreviewMode) {
      _savedEditorSelection = contentController.selection;
      // Save line-based position for accurate preview scroll
      _savedEditorLineIndex = contentController.selection.baseIndex;
      _savedTotalLines = contentController.lineCount;
    } else {
      // Currently no-op: we restore editor based on saved selection,
      // not on preview scroll position
    }

    if (switchingToPreviewMode) {
      _restorePreviewFromEditorLine(isMounted);
    } else {
      _restoreEditor(isMounted, contentController);
    }
  }

  /// Restore preview scroll position based on editor line index.
  /// More accurate than offset-based restoration for varied content.
  void _restorePreviewFromEditorLine(bool Function() isMounted) {
    void tryRestore() {
      if (!isMounted()) return;
      if (!previewScrollController.hasClients) return;
      if (_savedTotalLines <= 1) return;

      final maxScroll = previewScrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Use line ratio for more accurate positioning
      final lineRatio = _savedEditorLineIndex / (_savedTotalLines - 1);
      final targetOffset = (lineRatio * maxScroll).clamp(0.0, maxScroll);
      previewScrollController.jumpTo(targetOffset);
    }

    Future.delayed(const Duration(milliseconds: 50), tryRestore);
    Future.delayed(const Duration(milliseconds: 150), tryRestore);
  }

  void _restoreEditor(
    bool Function() isMounted,
    CodeLineEditingController contentController,
  ) {
    final selection = _savedEditorSelection;
    if (selection == null) return;

    void tryRestore() {
      if (!isMounted()) return;

      final position = CodeLinePosition(
        index: selection.baseIndex,
        offset: selection.baseOffset,
      );

      editorScrollController.makeCenterIfInvisible(position);
    }

    // Timing based on keyboard animation duration
    final keyboardMs = _keyboardAnimationMs;
    Future.delayed(const Duration(milliseconds: 50), tryRestore);
    Future.delayed(Duration(milliseconds: keyboardMs + 50), tryRestore);
    Future.delayed(Duration(milliseconds: keyboardMs + 200), tryRestore);
  }

  void scrollToOffsetInPreview({
    required int charOffset,
    required String text,
    required double previewFontSize,
    required double editorFontSize,
  }) {
    if (text.isEmpty) return;
    if (!previewScrollController.hasClients) return;

    int lineNumber = 0;
    int totalLines = 1;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        totalLines++;
        if (i < charOffset) lineNumber++;
      }
    }

    if (totalLines <= 1) return;

    final lineRatio = lineNumber / (totalLines - 1);
    final maxScroll = previewScrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final scrollTarget = (lineRatio * maxScroll).clamp(0.0, maxScroll);

    previewScrollController.animateTo(
      scrollTarget,
      duration: const Duration(
        milliseconds: MarkdownConstants.animationDurationMs,
      ),
      curve: Curves.easeOut,
    );
  }

  void reset() {
    _savedEditorSelection = null;
    _savedEditorLineIndex = 0;
    _savedTotalLines = 1;
  }
}
