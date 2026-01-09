import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../l10n/app_localizations.dart';

class ReNoteEditor extends StatefulWidget {
  final String initialContent;
  final FocusNode? focusNode;
  final double fontSize;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final CodeLineEditingController? externalController;

  const ReNoteEditor({
    super.key,
    this.initialContent = '',
    this.focusNode,
    this.fontSize = 16.0,
    this.readOnly = false,
    this.onChanged,
    this.externalController,
  });

  @override
  State<ReNoteEditor> createState() => ReNoteEditorState();
}

class ReNoteEditorState extends State<ReNoteEditor> {
  late CodeLineEditingController _controller;
  late CodeScrollController _scrollController;
  bool _ownsController = false;

  CodeLineEditingController get controller => _controller;
  CodeScrollController get scrollController => _scrollController;

  String get text => _controller.text;

  set text(String value) {
    _controller.text = value;
  }

  int get lineCount => _controller.lineCount;

  int get charCount => _controller.text.length;

  @override
  void initState() {
    super.initState();
    if (widget.externalController != null) {
      _controller = widget.externalController!;
      _ownsController = false;
    } else {
      _controller = CodeLineEditingController.fromText(widget.initialContent);
      _ownsController = true;
    }
    _scrollController = CodeScrollController();

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
  }

  void undo() {
    _controller.undo();
  }

  void redo() {
    _controller.redo();
  }

  bool get canUndo => _controller.canUndo;
  bool get canRedo => _controller.canRedo;

  void insertText(String before, String after) {
    final selectedText = _controller.selectedText;
    final newText = '$before$selectedText$after';
    _controller.replaceSelection(newText);
  }

  void insertAtLineStart(String prefix) {
    final selection = _controller.selection;
    final lineIndex = selection.startIndex;
    final line = _controller.codeLines[lineIndex];
    final newLineText = '$prefix${line.text}';

    _controller.selectLine(lineIndex);
    _controller.replaceSelection(newLineText);
  }

  void scrollToOffset(double offset) {
    _scrollController.verticalScroller.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void makeCursorVisible() {
    _controller.makeCursorVisible();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CodeEditor(
        controller: _controller,
        scrollController: _scrollController,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        wordWrap: true,
        showCursorWhenReadOnly: false,
        chunkAnalyzer: const NonCodeChunkAnalyzer(),
        style: CodeEditorStyle(
          fontSize: widget.fontSize,
          fontHeight: 1.5,
          textColor: theme.textTheme.bodyLarge?.color,
          backgroundColor: Colors.transparent,
          selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
          cursorColor: theme.colorScheme.primary,
          cursorWidth: 2.5,
        ),
        hint: l10n.startWriting,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
