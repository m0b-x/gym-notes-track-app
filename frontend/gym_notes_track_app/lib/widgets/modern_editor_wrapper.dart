import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/markdown_constants.dart';
import '../utils/re_editor_search_controller.dart';
import 'editor_chunk_overlay.dart';
import 'scroll_progress_indicator.dart';

/// Wraps the CodeEditor with custom toolbar and scroll indicator.
class ModernEditorWrapper extends StatefulWidget {
  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final CodeScrollController scrollController;
  final ReEditorSearchController searchController;
  final double editorFontSize;
  final VoidCallback onTextChanged;
  final bool showLineNumbers;
  final bool wordWrap;
  final bool showCursorLine;
  final GlobalKey? lineNumbersKey;
  final GlobalKey? scrollIndicatorKey;

  /// Number of lines per chunk for debug visualization (matches preview mode)
  final int linesPerChunk;

  /// Whether to show colored backgrounds for chunks (debug mode)
  final bool showChunkColors;

  /// Whether to show borders around chunks (debug mode)
  final bool showChunkBorders;

  const ModernEditorWrapper({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.searchController,
    required this.editorFontSize,
    required this.onTextChanged,
    this.showLineNumbers = false,
    this.wordWrap = true,
    this.showCursorLine = false,
    this.lineNumbersKey,
    this.scrollIndicatorKey,
    this.linesPerChunk = 10,
    this.showChunkColors = false,
    this.showChunkBorders = false,
  });

  @override
  State<ModernEditorWrapper> createState() => _ModernEditorWrapperState();
}

class _ModernEditorWrapperState extends State<ModernEditorWrapper> {
  late final SelectionToolbarController _toolbarController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _toolbarController = MobileSelectionToolbarController(
      builder: _buildSelectionToolbar,
    );
  }

  @override
  void dispose() {
    widget.searchController.clearFindController();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Widget _buildSelectionToolbar({
    required BuildContext context,
    required TextSelectionToolbarAnchors anchors,
    required CodeLineEditingController controller,
    required VoidCallback onDismiss,
    required VoidCallback onRefresh,
  }) {
    final isCollapsed = controller.selection.isCollapsed;

    // Build button items based on selection state
    final buttonItems = <ContextMenuButtonItem>[
      // Cut and Copy only when text is selected
      if (!isCollapsed) ...[
        ContextMenuButtonItem(
          label: MaterialLocalizations.of(context).cutButtonLabel,
          onPressed: () {
            controller.cut();
            onDismiss();
          },
        ),
        ContextMenuButtonItem(
          label: MaterialLocalizations.of(context).copyButtonLabel,
          onPressed: () {
            controller.copy();
            onDismiss();
          },
        ),
      ],
      // Paste is always available
      ContextMenuButtonItem(
        label: MaterialLocalizations.of(context).pasteButtonLabel,
        onPressed: () {
          controller.paste();
          onDismiss();
        },
      ),
      // Select All is always available
      ContextMenuButtonItem(
        label: MaterialLocalizations.of(context).selectAllButtonLabel,
        onPressed: () {
          controller.selectAll();
          onRefresh();
        },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: buttonItems,
    );
  }

  void _onControllerChanged() {
    widget.onTextChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDebugOverlay = widget.showChunkColors || widget.showChunkBorders;
    // Account for bottom system navigation bar (gesture bar on phones)
    final bottomSafeArea = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildCodeEditor(context),
        ),
        // Chunk debug overlay - positioned behind scrollbar but above editor
        if (showDebugOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: EditorChunkOverlay(
                scrollController: widget.scrollController,
                editingController: widget.controller,
                linesPerChunk: widget.linesPerChunk,
                fontSize: widget.editorFontSize,
                lineHeight: MarkdownConstants.lineHeight,
                showColors: widget.showChunkColors,
                showBorders: widget.showChunkBorders,
                editorPadding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  top: AppSpacing.lg,
                  right: AppSpacing.lg + AppConstants.editorScrollbarPadding,
                  bottom: AppSpacing.lg + bottomSafeArea,
                ),
              ),
            ),
          ),
        // Scrollbar positioned on the right - uses IgnorePointer except for the thumb area
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          child: KeyedSubtree(
            key: widget.scrollIndicatorKey,
            child: ScrollProgressIndicator(
              scrollController: widget.scrollController.verticalScroller,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEditor(BuildContext context) {
    final theme = Theme.of(context);
    // Account for bottom system navigation bar (gesture bar on phones)
    final bottomSafeArea = MediaQuery.of(context).viewPadding.bottom;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CodeEditor(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: widget.scrollController,
        // Enable mobile selection toolbar (copy/paste/cut/select all)
        toolbarController: _toolbarController,
        style: CodeEditorStyle(
          fontSize: widget.editorFontSize,
          fontFamily: FontConstants.editorFontFamily,
          fontHeight: MarkdownConstants.lineHeight,
          textColor: theme.textTheme.bodyLarge?.color,
          backgroundColor: Colors.transparent,
          cursorColor: theme.colorScheme.primary,
          cursorWidth: 2.5,
          cursorLineColor: widget.showCursorLine
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        wordWrap: widget.wordWrap,
        readOnly: false,
        autofocus: false,
        chunkAnalyzer: const NonCodeChunkAnalyzer(),
        // Add small right padding for visible scrollbar (6-12px width)
        // Add bottom safe area to account for phone navigation bar
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          top: AppSpacing.lg,
          right: AppSpacing.lg + AppConstants.editorScrollbarPadding,
          bottom: AppSpacing.lg + bottomSafeArea,
        ),
        indicatorBuilder: widget.showLineNumbers
            ? (context, editingController, chunkController, notifier) {
                return KeyedSubtree(
                  key: widget.lineNumbersKey,
                  child: DefaultCodeLineNumber(
                    controller: editingController,
                    notifier: notifier,
                  ),
                );
              }
            : null,
        scrollbarBuilder: (context, child, details) => child,
        findBuilder: (context, controller, readOnly) {
          widget.searchController.setFindController(controller);
          return _HiddenFindPanel(controller: controller);
        },
      ),
    );
  }
}

/// A hidden find panel widget that implements PreferredSizeWidget.
/// This allows us to use re_editor's native search highlighting
/// while using our own NoteSearchBar UI for the search interface.
class _HiddenFindPanel extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController? controller;

  const _HiddenFindPanel({required this.controller});

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
