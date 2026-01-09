import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:re_editor/re_editor.dart';

import '../l10n/app_localizations.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/note_metadata.dart';
import '../services/auto_save_service.dart';
import '../services/settings_service.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/efficient_markdown.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/scroll_progress_indicator.dart';
import '../widgets/scroll_zone_mixin.dart';
import '../widgets/note_search_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/gradient_app_bar.dart';
import '../utils/note_search_controller.dart';
import '../config/default_markdown_shortcuts.dart';
import '../database/database.dart';
import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/markdown_constants.dart';
import '../constants/settings_keys.dart';
import 'markdown_settings_page.dart';

class OptimizedNoteEditorPage extends StatefulWidget {
  final String folderId;
  final String? noteId;
  final NoteMetadata? metadata;

  const OptimizedNoteEditorPage({
    super.key,
    required this.folderId,
    this.noteId,
    this.metadata,
  });

  @override
  State<OptimizedNoteEditorPage> createState() =>
      _OptimizedNoteEditorPageState();
}

class _OptimizedNoteEditorPageState extends State<OptimizedNoteEditorPage> {
  late TextEditingController _titleController;
  late CodeLineEditingController _contentController;
  late FocusNode _contentFocusNode;
  late CodeScrollController _editorScrollController;
  final ScrollController _previewScrollController = ScrollController();
  late NoteSearchController _searchController;

  bool _hasChanges = false;
  bool _isPreviewMode = false;
  bool _isLoading = true;
  bool _noteSwipeEnabled = true;
  bool _showStatsBar = true;
  SearchCursorBehavior _searchCursorBehavior = SearchCursorBehavior.end;

  AutoSaveService? _autoSaveService;

  double _previewFontSize = FontConstants.defaultFontSize;
  double _editorFontSize = FontConstants.defaultFontSize;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  String _previousText = '';
  bool _isProcessingTextChange = false;
  int _cachedLineCount = 1;
  int _cachedCharCount = 0;

  Timer? _lineCountDebounceTimer;
  Timer? _searchContentDebounceTimer;
  int _lastLineCountTextLength = 0;

  bool get _useVirtualPreview =>
      _contentController.text.length > MarkdownConstants.virtualPreviewThreshold;

  @override
  void initState() {
    super.initState();
    _loadSwipeSetting();

    _titleController = TextEditingController(
      text: widget.metadata?.title ?? '',
    );
    _contentController = CodeLineEditingController();
    _previousText = '';
    _contentFocusNode = FocusNode();
    _editorScrollController = CodeScrollController();
    _searchController = NoteSearchController();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onContentChanged);

    if (widget.noteId != null) {
      _loadNoteContent();
    } else {
      _isLoading = false;
    }

    _loadCustomShortcuts();
    _initializeAutoSave();
    _loadFontSizes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoading) {
        _contentFocusNode.requestFocus();
      }
    });
  }

  void _onContentChanged() {
    _onTextChanged();
  }

  Future<void> _loadFontSizes() async {
    final db = await AppDatabase.getInstance();
    final previewSize = await db.userSettingsDao.getValue(
      SettingsKeys.previewFontSize,
    );
    final editorSize = await db.userSettingsDao.getValue(
      SettingsKeys.editorFontSize,
    );

    if (mounted) {
      setState(() {
        if (previewSize != null) {
          _previewFontSize =
              double.tryParse(previewSize) ?? FontConstants.defaultFontSize;
        }
        if (editorSize != null) {
          _editorFontSize =
              double.tryParse(editorSize) ?? FontConstants.defaultFontSize;
        }
      });
    }
  }

  Future<void> _saveFontSizes() async {
    final db = await AppDatabase.getInstance();
    await db.userSettingsDao.setValue(
      SettingsKeys.previewFontSize,
      _previewFontSize.toString(),
    );
    await db.userSettingsDao.setValue(
      SettingsKeys.editorFontSize,
      _editorFontSize.toString(),
    );
  }

  Future<void> _loadSwipeSetting() async {
    final settings = await SettingsService.getInstance();
    final noteSwipe = await settings.getNoteSwipeEnabled();
    final searchCursor = await settings.getSearchCursorBehavior();
    final showStats = await settings.getShowStatsBar();
    if (mounted) {
      setState(() {
        _noteSwipeEnabled = noteSwipe;
        _searchCursorBehavior = SearchCursorBehavior.values[searchCursor];
        _showStatsBar = showStats;
      });
    }
  }

  void _initializeAutoSave() {
    _autoSaveService = AutoSaveService(
      onSave: (noteId, title, content) async {
        if (widget.noteId != null) {
          context.read<OptimizedNoteBloc>().add(
            UpdateOptimizedNote(
              noteId: widget.noteId!,
              title: title,
              content: content,
            ),
          );
        }
      },
      onChangeDetected: (noteId, hasChanges) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasChanges = hasChanges;
              });
            }
          });
        }
      },
    );

    if (widget.noteId != null) {
      _autoSaveService?.startTracking(
        widget.noteId!,
        _titleController.text,
        _contentController.text,
      );
    }
  }

  Future<void> _loadNoteContent() async {
    context.read<OptimizedNoteBloc>().add(LoadNoteContent(widget.noteId!));
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasChanges) {
          setState(() {
            _hasChanges = true;
          });
        }
      });
    }

    _debouncedLineCountUpdate();
    _throttledSearchContentUpdate();

    if (widget.noteId != null) {
      _autoSaveService?.onContentChanged(
        widget.noteId!,
        _titleController.text,
        _contentController.text,
      );
    }
  }

  void _debouncedLineCountUpdate() {
    final currentLength = _contentController.text.length;
    final lengthDelta = (currentLength - _lastLineCountTextLength).abs();

    if (lengthDelta > MarkdownConstants.contentChangeDeltaThreshold) {
      _lineCountDebounceTimer?.cancel();
      _updateCachedStats();
      _lastLineCountTextLength = currentLength;
      return;
    }

    _lineCountDebounceTimer?.cancel();
    _lineCountDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updateCachedStats();
      _lastLineCountTextLength = _contentController.text.length;
    });
  }

  void _throttledSearchContentUpdate() {
    if (!_searchController.isSearching) return;

    _searchContentDebounceTimer?.cancel();
    _searchContentDebounceTimer = Timer(
      const Duration(milliseconds: MarkdownConstants.searchDebounceMs),
      () {
      _searchController.updateContent(_contentController.text);
    });
  }

  /// Gets the current content
  String _getCurrentContent() {
    return _contentController.text;
  }

  void _updateCachedStats() {
    final newCharCount = _contentController.text.length;
    // Use re_editor's built-in lineCount for efficiency
    final newLineCount = _contentController.lineCount;
    if (newLineCount != _cachedLineCount || newCharCount != _cachedCharCount) {
      setState(() {
        _cachedLineCount = newLineCount;
        _cachedCharCount = newCharCount;
      });
    }
  }

  int _getCurrentLineFromScroll() {
    // Use the appropriate scroll controller based on current mode
    final scroller = _isPreviewMode 
        ? _previewScrollController 
        : _editorScrollController.verticalScroller;
    if (!scroller.hasClients) return 0;

    final scrollOffset = scroller.offset;
    final maxScroll = scroller.position.maxScrollExtent;
    if (maxScroll <= 0) return 0;

    final scrollRatio = scrollOffset / maxScroll;
    return (scrollRatio * (_cachedLineCount - 1)).round().clamp(
      0,
      _cachedLineCount - 1,
    );
  }

  void _scrollToLine(int targetLine) {
    if (_cachedLineCount <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Wait for the new view to be built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Use the appropriate scroll controller based on current mode
        final scroller = _isPreviewMode 
            ? _previewScrollController 
            : _editorScrollController.verticalScroller;
        
        if (!scroller.hasClients) return;

        final maxScroll = scroller.position.maxScrollExtent;
        if (maxScroll <= 0) return;

        final lineRatio = targetLine / (_cachedLineCount - 1);
        final targetOffset = (lineRatio * maxScroll).clamp(0.0, maxScroll);
        scroller.jumpTo(targetOffset);
      });
    });
  }

  void _togglePreviewMode() {
    final currentLine = _getCurrentLineFromScroll();

    setState(() {
      _isPreviewMode = !_isPreviewMode;
      if (!_isPreviewMode) {
        Future.delayed(AppConstants.shortDelay, () {
          _contentFocusNode.requestFocus();
        });
      }
    });

    _scrollToLine(currentLine);
  }

  @override
  void dispose() {
    _lineCountDebounceTimer?.cancel();
    _searchContentDebounceTimer?.cancel();
    _autoSaveService?.stopTracking(widget.noteId ?? '');
    _autoSaveService?.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_searchController.isSearching) {
      _searchContentDebounceTimer?.cancel();
      _searchController.closeSearch();
    } else {
      _searchController.openSearch();
      _searchController.updateContent(_contentController.text);
    }
    setState(() {});
  }

  void _navigateToSearchMatch(int offset) {
    final match = _searchController.currentMatch;

    if (_isPreviewMode) {
      _scrollToOffsetInPreview(match?.start ?? offset);
    } else {
      if (match != null) {
        final text = _contentController.text;
        final startLine = _getLineFromOffset(text, match.start);
        final startCol = _getColumnFromOffset(text, match.start);
        final endLine = _getLineFromOffset(text, match.end);
        final endCol = _getColumnFromOffset(text, match.end);

        switch (_searchCursorBehavior) {
          case SearchCursorBehavior.start:
            _contentController.selection = CodeLineSelection.collapsed(
              index: startLine,
              offset: startCol,
            );
          case SearchCursorBehavior.end:
            _contentController.selection = CodeLineSelection.collapsed(
              index: endLine,
              offset: endCol,
            );
          case SearchCursorBehavior.selection:
            _contentController.selection = CodeLineSelection(
              baseIndex: startLine,
              baseOffset: startCol,
              extentIndex: endLine,
              extentOffset: endCol,
            );
        }

        _editorScrollController.makeCenterIfInvisible(
          CodeLinePosition(index: startLine, offset: startCol),
        );
      }
    }
  }

  int _getLineFromOffset(String text, int offset) {
    int line = 0;
    for (int i = 0; i < offset && i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) line++;
    }
    return line;
  }

  int _getColumnFromOffset(String text, int offset) {
    int lastNewline = text.lastIndexOf('\n', offset - 1);
    return offset - (lastNewline + 1);
  }

  void _scrollToOffsetInPreview(int charOffset) {
    final text = _contentController.text;
    if (text.isEmpty) return;

    // Calculate line number for the offset
    int lineNumber = 0;
    for (int i = 0; i < charOffset && i < text.length; i++) {
      if (text[i] == '\n') lineNumber++;
    }

    if (!_previewScrollController.hasClients) return;

    final estimatedLineHeight =
        _previewFontSize * MarkdownConstants.lineHeight;
    final targetScroll = lineNumber * estimatedLineHeight;

    final maxScroll = _previewScrollController.position.maxScrollExtent;
    final clampedScroll = targetScroll.clamp(0.0, maxScroll);

    _previewScrollController.animateTo(
      clampedScroll,
      duration:
          const Duration(milliseconds: MarkdownConstants.animationDurationMs),
      curve: Curves.easeOut,
    );
  }

  void _handleSearchReplace(String _, String newContent) {
    _contentController.text = newContent;
    _searchController.updateContent(newContent);
    _searchController.search(_searchController.query);
  }

  void _handleTextChange() {
    if (_isProcessingTextChange) return;

    final text = _contentController.text;
    final selection = _contentController.selection;

    final textLengthIncreased = text.length > _previousText.length;
    _previousText = text;

    if (!textLengthIncreased) return;

    // Check if we just inserted a newline
    // In CodeLineEditingController, after pressing Enter:
    // - baseIndex is the new line (current line)
    // - baseOffset is 0 (start of new line)
    final currentLineIndex = selection.baseIndex;
    if (currentLineIndex > 0 && selection.baseOffset == 0) {
      _isProcessingTextChange = true;

      // Get the previous line text
      final prevLineIndex = currentLineIndex - 1;
      final prevLine = _contentController.codeLines[prevLineIndex].text;

      if (_isEmptyListItem(prevLine.trim())) {
        // Remove the empty list item line
        final newText = text.replaceRange(
          _getLineStartOffset(prevLineIndex),
          _getLineStartOffset(currentLineIndex),
          '',
        );
        _contentController.text = newText;
        _contentController.selection = CodeLineSelection.collapsed(
          index: prevLineIndex,
          offset: 0,
        );
        _previousText = newText;
        _isProcessingTextChange = false;
        return;
      }

      String? listPrefix = _getListPrefix(prevLine);
      if (listPrefix != null) {
        // Insert the list prefix at the current position
        _contentController.replaceSelection(listPrefix);
        _previousText = _contentController.text;
      }
      _isProcessingTextChange = false;
    }
  }

  /// Get the character offset where a given line starts in the full text
  int _getLineStartOffset(int lineIndex) {
    int offset = 0;
    final codeLines = _contentController.codeLines;
    for (int i = 0; i < lineIndex && i < codeLines.length; i++) {
      offset += codeLines[i].text.length + 1; // +1 for newline
    }
    return offset;
  }

  bool _isEmptyListItem(String line) {
    line = line.trim();
    final emptyPatterns = ['•', '-', '- [ ]', '- [x]', '- [X]'];
    for (var pattern in emptyPatterns) {
      if (line == pattern) return true;
    }
    final numberedPattern = RegExp(r'^\d+\.$');
    return numberedPattern.hasMatch(line);
  }

  String? _getListPrefix(String line) {
    line = line.trimLeft();

    if (line.startsWith('• ')) return '• ';
    if (line.startsWith('- ') && !line.startsWith('- [')) return '- ';
    if (line.startsWith('- [ ] ')) return '- [ ] ';
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) return '- [ ] ';

    final numberedMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (numberedMatch != null) {
      final currentNumber = int.parse(numberedMatch.group(1)!);
      return '${currentNumber + 1}. ';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OptimizedNoteBloc, OptimizedNoteState>(
      listener: (context, state) {
        if (state is OptimizedNoteContentLoaded) {
          final content = state.note.content ?? '';
          setState(() {
            _contentController.text = content;
            _previousText = content;
            _cachedLineCount = '\n'.allMatches(content).length + 1;
            _cachedCharCount = content.length;
            _isLoading = false;
          });
          _contentFocusNode.requestFocus();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            await _saveBeforeExit();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          drawer: const AppDrawer(),
          drawerEnableOpenDragGesture: _noteSwipeEnabled,
          appBar: GradientAppBar(
            automaticallyImplyLeading: false,
            purpleAlpha: 0.7,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: GestureDetector(
              onTap: _editTitle,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _titleController.text.isEmpty
                          ? AppLocalizations.of(context)!.newNote
                          : _titleController.text,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_hasChanges)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _searchController.isSearching
                      ? Icons.search_off
                      : Icons.search,
                ),
                onPressed: _toggleSearch,
                tooltip: AppLocalizations.of(context)!.search,
              ),
              Tooltip(
                message: _isPreviewMode
                    ? AppLocalizations.of(context)!.switchToEditMode
                    : AppLocalizations.of(context)!.previewMarkdown,
                waitDuration: AppConstants.debounceDelay,
                child: IconButton(
                  icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
                  onPressed: () => _togglePreviewMode(),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? Column(
                  children: [
                    if (_showStatsBar)
                      RepaintBoundary(child: _buildNoteStats(context)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    if (_allShortcuts.isNotEmpty)
                      RepaintBoundary(
                        child: MarkdownToolbar(
                          shortcuts: _allShortcuts,
                          isPreviewMode: _isPreviewMode,
                          canUndo: false,
                          canRedo: false,
                          previewFontSize: _previewFontSize,
                          onUndo: () {},
                          onRedo: () {},
                          onDecreaseFontSize: () {},
                          onIncreaseFontSize: () {},
                          onSettings: () {},
                          onShortcutPressed: (_) {},
                          onReorderComplete: (_) {},
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    // Search bar
                    if (_searchController.isSearching)
                      NoteSearchBar(
                        searchController: _searchController,
                        onClose: () => setState(() {}),
                        onNavigateToMatch: _navigateToSearchMatch,
                        showReplaceField: !_isPreviewMode,
                        onReplace: _handleSearchReplace,
                      ),
                    if (_showStatsBar)
                      RepaintBoundary(child: _buildNoteStats(context)),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: MarkdownConstants.animationDurationMs,
                          ),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _isPreviewMode
                              ? _buildPreview()
                              : _buildEditor(),
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarkdownToolbar(
                            shortcuts: _allShortcuts,
                            isPreviewMode: _isPreviewMode,
                            canUndo: _contentController.canUndo,
                            canRedo: _contentController.canRedo,
                            previewFontSize: _isPreviewMode
                                ? _previewFontSize
                                : _editorFontSize,
                            onUndo: () => _contentController.undo(),
                            onRedo: () => _contentController.redo(),
                            onDecreaseFontSize: () {
                              setState(() {
                                if (_isPreviewMode) {
                                  _previewFontSize =
                                      (_previewFontSize -
                                              FontConstants.fontSizeStep)
                                          .clamp(
                                            FontConstants.minFontSize,
                                            FontConstants.maxFontSize,
                                          );
                                } else {
                                  _editorFontSize =
                                      (_editorFontSize -
                                              FontConstants.fontSizeStep)
                                          .clamp(
                                            FontConstants.minFontSize,
                                            FontConstants.maxFontSize,
                                          );
                                }
                              });
                              _saveFontSizes();
                            },
                            onIncreaseFontSize: () {
                              setState(() {
                                if (_isPreviewMode) {
                                  _previewFontSize =
                                      (_previewFontSize +
                                              FontConstants.fontSizeStep)
                                          .clamp(
                                            FontConstants.minFontSize,
                                            FontConstants.maxFontSize,
                                          );
                                } else {
                                  _editorFontSize =
                                      (_editorFontSize +
                                              FontConstants.fontSizeStep)
                                          .clamp(
                                            FontConstants.minFontSize,
                                            FontConstants.maxFontSize,
                                          );
                                }
                              });
                              _saveFontSizes();
                            },
                            onSettings: _openMarkdownSettings,
                            onShortcutPressed: _handleShortcut,
                            onReorderComplete: _handleReorderComplete,
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNoteStats(BuildContext context) {
    final metadata = widget.metadata;
    final charCount = _cachedCharCount > 0
        ? _cachedCharCount
        : (metadata?.contentLength ?? 0);
    final chunkCount = metadata?.chunkCount ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.noteStats(charCount, chunkCount),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (metadata?.isCompressed ?? false) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.compress,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.compressedNote,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const Spacer(),
          Text(
            AppLocalizations.of(context)!.lineCount(_cachedLineCount),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final content = _contentController.text.isEmpty
        ? AppLocalizations.of(context)!.noContentYet
        : _contentController.text;

    if (_useVirtualPreview) {
      return Stack(
        key: const ValueKey('preview'),
        children: [
          EfficientMarkdownView(
            data: content,
            selectable: true,
            scrollController: _previewScrollController,
            styleSheet: _getPreviewStyleSheet(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            onCheckboxChanged: (updatedContent) {
              setState(() {
                _contentController.text = updatedContent;
                _hasChanges = true;
              });
            },
          ),
          Positioned(
            top: 8,
            bottom: 8,
            right: 0,
            child: ScrollProgressIndicator(
              scrollController: _previewScrollController,
            ),
          ),
        ],
      );
    }

    return Stack(
      key: const ValueKey('preview'),
      children: [
        InteractiveMarkdown(
          data: content,
          selectable: true,
          scrollController: _previewScrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          styleSheet: _getPreviewStyleSheet(),
          onCheckboxChanged: (updatedContent) {
            setState(() {
              _contentController.text = updatedContent;
              _hasChanges = true;
            });
          },
        ),
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          child: ScrollProgressIndicator(
            scrollController: _previewScrollController,
          ),
        ),
      ],
    );
  }

  MarkdownStyleSheet _getPreviewStyleSheet() {
    // Match editor's line height for visual consistency
    const lineHeight = MarkdownConstants.lineHeight;
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: _previewFontSize, height: lineHeight),
      h1: TextStyle(
        fontSize: _previewFontSize * MarkdownConstants.h1Scale,
        fontWeight: FontWeight.bold,
        height: lineHeight,
      ),
      h2: TextStyle(
        fontSize: _previewFontSize * MarkdownConstants.h2Scale,
        fontWeight: FontWeight.bold,
        height: lineHeight,
      ),
      h3: TextStyle(
        fontSize: _previewFontSize * MarkdownConstants.h3Scale,
        fontWeight: FontWeight.bold,
        height: lineHeight,
      ),
    );
  }

  Widget _buildEditor() {
    return _ModernEditorWrapper(
      key: const ValueKey('editor'),
      controller: _contentController,
      focusNode: _contentFocusNode,
      scrollController: _editorScrollController,
      searchController: _searchController,
      editorFontSize: _editorFontSize,
      onTextChanged: _handleTextChange,
    );
  }

  Future<void> _handleReorderComplete(
    List<CustomMarkdownShortcut> reorderedShortcuts,
  ) async {
    setState(() {
      _allShortcuts = reorderedShortcuts;
    });
    await _saveShortcutsOrder();
  }

  Future<void> _saveBeforeExit() async {
    _contentFocusNode.unfocus();

    final title = _titleController.text.trim();
    final content = _getCurrentContent().trim();

    if (title.isEmpty && content.isEmpty) {
      return;
    }

    if (widget.noteId == null) {
      context.read<OptimizedNoteBloc>().add(
        CreateOptimizedNote(
          folderId: widget.folderId,
          title: title,
          content: content,
        ),
      );
    } else {
      await _autoSaveService?.forceSave(widget.noteId!, title, content);
    }
  }

  void _editTitle() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _titleController.text);
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.editTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterNoteTitle,
            ),
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _titleController.text = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  void _handleShortcut(CustomMarkdownShortcut shortcut) {
    final selectedText = _contentController.selectedText;

    if (shortcut.insertType == 'date') {
      final now = DateTime.now();
      final formatted =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final middle = selectedText.isNotEmpty ? selectedText : formatted;
      final wrapped = '${shortcut.beforeText}$middle${shortcut.afterText}';
      _contentController.replaceSelection(wrapped);
    } else if (shortcut.insertType == 'header') {
      final selection = _contentController.selection;
      final lineIndex = selection.startIndex;
      final line = _contentController.codeLines[lineIndex];
      final newLineText = '${shortcut.beforeText}${line.text}';
      _contentController.selectLine(lineIndex);
      _contentController.replaceSelection(newLineText);
    } else {
      final before = shortcut.beforeText;
      final after = shortcut.afterText;

      final isSymmetricWrapper =
          before == after && before.isNotEmpty && after.isNotEmpty;

      if (selectedText.isEmpty && isSymmetricWrapper) {
        _contentController.replaceSelection(before);
      } else {
        final wrapped = '$before$selectedText$after';
        _contentController.replaceSelection(wrapped);
      }
    }

    _onTextChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _contentController.makeCursorVisible();
      }
    });
  }

  Future<void> _loadCustomShortcuts() async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = await db.userSettingsDao.getValue(
      'markdown_shortcuts',
    );

    final defaults = DefaultMarkdownShortcuts.shortcuts;
    final defaultsMap = {for (var d in defaults) d.id: d};

    if (shortcutsJson != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsJson);
      final loaded = decoded
          .map((json) => CustomMarkdownShortcut.fromJson(json))
          .toList();

      final loadedIds = loaded.map((s) => s.id).toSet();

      final migrated = loaded.map((shortcut) {
        if (shortcut.isDefault && defaultsMap.containsKey(shortcut.id)) {
          final defaultShortcut = defaultsMap[shortcut.id]!;
          return shortcut.copyWith(
            iconCodePoint: defaultShortcut.iconCodePoint,
            iconFontFamily: defaultShortcut.iconFontFamily,
          );
        }
        return shortcut;
      }).toList();

      final mergedShortcuts = List<CustomMarkdownShortcut>.from(migrated);

      for (var defaultShortcut in defaults) {
        if (!loadedIds.contains(defaultShortcut.id)) {
          mergedShortcuts.add(defaultShortcut);
        }
      }

      setState(() {
        _allShortcuts = mergedShortcuts;
      });
    } else {
      setState(() {
        _allShortcuts = defaults;
      });
    }
  }

  Future<void> _saveShortcutsOrder() async {
    try {
      final db = await AppDatabase.getInstance();
      final shortcutsJson = _allShortcuts
          .map((shortcut) => shortcut.toJson())
          .toList();
      await db.userSettingsDao.setValue(
        'markdown_shortcuts',
        jsonEncode(shortcutsJson),
      );
      debugPrint(
        '[NoteEditor] Shortcuts order saved (${_allShortcuts.length} items)',
      );
    } catch (e, stackTrace) {
      debugPrint('[NoteEditor] ERROR saving shortcuts order: $e');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
    }
  }

  Future<void> _openMarkdownSettings() async {
    final result = await Navigator.push<List<CustomMarkdownShortcut>>(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownSettingsPage(allShortcuts: _allShortcuts),
      ),
    );

    if (result != null) {
      setState(() {
        _allShortcuts = result;
      });

      final db = await AppDatabase.getInstance();
      final shortcutsJson = result
          .map((shortcut) => shortcut.toJson())
          .toList();
      await db.userSettingsDao.setValue(
        'markdown_shortcuts',
        jsonEncode(shortcutsJson),
      );
    }
  }
}

class _ModernEditorWrapper extends StatefulWidget {
  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final CodeScrollController scrollController;
  final NoteSearchController searchController;
  final double editorFontSize;
  final VoidCallback onTextChanged;

  const _ModernEditorWrapper({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.searchController,
    required this.editorFontSize,
    required this.onTextChanged,
  });

  @override
  State<_ModernEditorWrapper> createState() => _ModernEditorWrapperState();
}

class _ModernEditorWrapperState extends State<_ModernEditorWrapper>
    with SingleTickerProviderStateMixin, ScrollZoneMixin {
  static const double _scrollZoneWidth = 80.0;

  @override
  void initState() {
    super.initState();
    initScrollZone();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    disposeScrollZone();
    super.dispose();
  }

  void _onControllerChanged() {
    widget.onTextChanged();
  }

  @override
  ScrollController getScrollController() =>
      widget.scrollController.verticalScroller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildCodeEditor(context),
        ),
        buildScrollZone(width: _scrollZoneWidth),
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          child: ScrollProgressIndicator(
            scrollController: widget.scrollController.verticalScroller,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEditor(BuildContext context) {
    final theme = Theme.of(context);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CodeEditor(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: widget.scrollController,
        style: CodeEditorStyle(
          fontSize: widget.editorFontSize,
          fontHeight: MarkdownConstants.lineHeight,
          textColor: theme.textTheme.bodyLarge?.color,
          backgroundColor: Colors.transparent,
          cursorColor: theme.colorScheme.primary,
          cursorWidth: 2.5,
          selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        wordWrap: true,
        readOnly: false,
        chunkAnalyzer: const NonCodeChunkAnalyzer(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        // Hide default scrollbar - we use ScrollProgressIndicator instead
        scrollbarBuilder: (context, child, details) => child,
      ),
    );
  }
}
