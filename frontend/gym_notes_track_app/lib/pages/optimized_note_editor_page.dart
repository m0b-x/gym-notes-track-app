import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/scroll_zone_mixin.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/note_metadata.dart';
import '../services/auto_save_service.dart';
import '../services/settings_service.dart';
import '../utils/text_history_observer.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/efficient_markdown.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/scroll_progress_indicator.dart';
import '../widgets/note_search_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/gradient_app_bar.dart';
import '../utils/note_search_controller.dart';
import '../config/default_markdown_shortcuts.dart';
import '../database/database.dart';
import '../constants/app_constants.dart';
import '../constants/font_constants.dart';
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
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  late ScrollController _editorScrollController;
  late NoteSearchController _searchController;

  bool _hasChanges = false;
  bool _isPreviewMode = false;
  bool _isLoading = true;
  bool _noteSwipeEnabled = true;

  TextHistoryObserver? _textHistory;
  AutoSaveService? _autoSaveService;

  double _previewFontSize = FontConstants.defaultFontSize;
  double _editorFontSize = FontConstants.defaultFontSize;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  String _previousText = '';
  bool _isProcessingTextChange = false;
  int _cachedLineCount = 1;

  /// Only use virtual scrolling for PREVIEW mode with large content
  bool get _useVirtualPreview => _contentController.text.length > 5000;

  @override
  void initState() {
    super.initState();
    _loadSwipeSetting();

    _titleController = TextEditingController(
      text: widget.metadata?.title ?? '',
    );
    _contentController = TextEditingController();
    _previousText = '';
    _contentFocusNode = FocusNode();
    _editorScrollController = ScrollController();
    _searchController = NoteSearchController();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    _contentController.addListener(_updateSearchContent);

    if (widget.noteId != null) {
      _loadNoteContent();
    } else {
      _isLoading = false;
      _setupTextHistory();
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

  void _setupTextHistory() {
    _textHistory?.dispose();
    _textHistory = TextHistoryObserver(_contentController);
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
    if (mounted) {
      setState(() {
        _noteSwipeEnabled = noteSwipe;
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
          setState(() {
            _hasChanges = hasChanges;
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
      setState(() {
        _hasChanges = true;
      });
    }

    _updateCachedLineCount();

    if (widget.noteId != null) {
      _autoSaveService?.onContentChanged(
        widget.noteId!,
        _titleController.text,
        _contentController.text,
      );
    }
  }

  /// Gets the current content
  String _getCurrentContent() {
    return _contentController.text;
  }

  void _updateCachedLineCount() {
    final content = _contentController.text;
    final newCount = '\n'.allMatches(content).length + 1;
    if (newCount != _cachedLineCount) {
      setState(() {
        _cachedLineCount = newCount;
      });
    }
  }

  int _getCurrentLineFromScroll() {
    if (!_editorScrollController.hasClients) return 0;

    final scrollOffset = _editorScrollController.offset;
    final maxScroll = _editorScrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return 0;

    final scrollRatio = scrollOffset / maxScroll;
    return (scrollRatio * (_cachedLineCount - 1)).round().clamp(
      0,
      _cachedLineCount - 1,
    );
  }

  void _scrollToLine(int targetLine) {
    if (!_editorScrollController.hasClients) return;
    if (_cachedLineCount <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editorScrollController.hasClients) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_editorScrollController.hasClients) return;

        final maxScroll = _editorScrollController.position.maxScrollExtent;
        if (maxScroll <= 0) return;

        final lineRatio = targetLine / (_cachedLineCount - 1);
        final targetOffset = (lineRatio * maxScroll).clamp(0.0, maxScroll);
        _editorScrollController.jumpTo(targetOffset);
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
    _autoSaveService?.stopTracking(widget.noteId ?? '');
    _autoSaveService?.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _editorScrollController.dispose();
    _searchController.dispose();
    _textHistory?.dispose();
    super.dispose();
  }

  void _updateSearchContent() {
    _searchController.updateContent(_contentController.text);
  }

  void _toggleSearch() {
    if (_searchController.isSearching) {
      _searchController.closeSearch();
    } else {
      _searchController.openSearch();
      _searchController.updateContent(_contentController.text);
    }
    setState(() {});
  }

  void _navigateToSearchMatch(int offset) {
    // Set cursor to match position
    _contentController.selection = TextSelection.collapsed(offset: offset);
    _contentFocusNode.requestFocus();

    // Scroll to make match visible
    _scrollToCursor(offset, _contentController.text);
  }

  void _handleSearchReplace(String _, String newContent) {
    final cursorPos = _searchController.currentMatch?.start ?? 0;
    _contentController.text = newContent;
    _contentController.selection = TextSelection.collapsed(offset: cursorPos);
    _searchController.updateContent(newContent);
    _searchController.search(_searchController.query); // Re-search
  }

  void _handleTextChange() {
    if (_isProcessingTextChange) return;

    final text = _contentController.text;
    final selection = _contentController.selection;

    final textLengthIncreased = text.length > _previousText.length;
    _previousText = text;

    if (!textLengthIncreased) return;

    if (selection.baseOffset > 0 &&
        selection.baseOffset <= text.length &&
        text[selection.baseOffset - 1] == '\n') {
      _isProcessingTextChange = true;
      int prevLineStart;
      if (selection.baseOffset < 2) {
        prevLineStart = 0;
      } else {
        prevLineStart = text.lastIndexOf('\n', selection.baseOffset - 2);
        if (prevLineStart == -1) {
          prevLineStart = 0;
        } else {
          prevLineStart++;
        }
      }

      String prevLine = text.substring(prevLineStart, selection.baseOffset - 1);

      if (_isEmptyListItem(prevLine.trim())) {
        final newText =
            text.substring(0, prevLineStart) +
            text.substring(selection.baseOffset);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
        _previousText = newText;
        _isProcessingTextChange = false;
        return;
      }

      String? listPrefix = _getListPrefix(prevLine);
      if (listPrefix != null) {
        final beforeCursor = text.substring(0, selection.baseOffset);
        final afterCursor = text.substring(selection.baseOffset);

        if (!afterCursor.startsWith(listPrefix)) {
          final newText = beforeCursor + listPrefix + afterCursor;
          final newOffset = selection.baseOffset + listPrefix.length;

          _contentController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newOffset),
          );
          _previousText = newText;
        }
      }
      _isProcessingTextChange = false;
    }
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
            _isLoading = false;
          });
          _setupTextHistory();
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
                    if (widget.metadata != null)
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
                    if (widget.metadata != null)
                      RepaintBoundary(child: _buildNoteStats(context)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _isPreviewMode
                            ? _buildPreview()
                            : _buildEditor(),
                      ),
                    ),
                    RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarkdownToolbar(
                            shortcuts: _allShortcuts,
                            isPreviewMode: _isPreviewMode,
                            canUndo: _textHistory?.canUndo ?? false,
                            canRedo: _textHistory?.canRedo ?? false,
                            previewFontSize: _isPreviewMode
                                ? _previewFontSize
                                : _editorFontSize,
                            onUndo: () => _textHistory?.undo(),
                            onRedo: () => _textHistory?.redo(),
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
    final metadata = widget.metadata!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text(
            AppLocalizations.of(
              context,
            )!.noteStats(metadata.contentLength, metadata.chunkCount),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (metadata.isCompressed) ...[
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

    // Use efficient virtualized markdown for large content
    if (_useVirtualPreview) {
      return Stack(
        children: [
          EfficientMarkdownView(
            data: content,
            selectable: true,
            scrollController: _editorScrollController,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: _previewFontSize),
              h1: TextStyle(
                fontSize: _previewFontSize * 2,
                fontWeight: FontWeight.bold,
              ),
              h2: TextStyle(
                fontSize: _previewFontSize * 1.5,
                fontWeight: FontWeight.bold,
              ),
              h3: TextStyle(
                fontSize: _previewFontSize * 1.25,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              scrollController: _editorScrollController,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        InteractiveMarkdown(
          data: content,
          selectable: true,
          scrollController: _editorScrollController,
          padding: const EdgeInsets.all(16),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: _previewFontSize),
            h1: TextStyle(
              fontSize: _previewFontSize * 2,
              fontWeight: FontWeight.bold,
            ),
            h2: TextStyle(
              fontSize: _previewFontSize * 1.5,
              fontWeight: FontWeight.bold,
            ),
            h3: TextStyle(
              fontSize: _previewFontSize * 1.25,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            scrollController: _editorScrollController,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return _ModernEditorWrapper(
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
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) return;

    String newText = text;
    int newCursor = end;

    if (shortcut.insertType == 'date') {
      final now = DateTime.now();
      final formatted =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final middle = start != end ? text.substring(start, end) : formatted;
      final wrapped = '${shortcut.beforeText}$middle${shortcut.afterText}';
      newText = text.replaceRange(start, end, wrapped);
      newCursor = start + wrapped.length;
    } else if (shortcut.insertType == 'header') {
      final lineStart = text.lastIndexOf('\n', start - 1) + 1;
      newText = text.replaceRange(lineStart, lineStart, shortcut.beforeText);
      final delta = shortcut.beforeText.length;
      newCursor = end + delta;
    } else {
      final before = shortcut.beforeText;
      final after = shortcut.afterText;

      if (start != end) {
        final replaced = '$before${text.substring(start, end)}$after';
        newText = text.replaceRange(start, end, replaced);
        newCursor = start + replaced.length;
      } else {
        final inserted = '$before$after';
        newText = text.replaceRange(start, end, inserted);
        newCursor = start + before.length;
      }
    }

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _onTextChanged();
    _contentFocusNode.requestFocus();

    // Scroll to make cursor visible after inserting markdown
    _scrollToCursor(newCursor, newText);
  }

  /// Scrolls the editor to make the cursor visible
  void _scrollToCursor(int cursorOffset, String text) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editorScrollController.hasClients) return;

      final maxScroll = _editorScrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Estimate cursor position based on line number
      final textBeforeCursor = text.substring(0, cursorOffset);
      final lineNumber = '\n'.allMatches(textBeforeCursor).length;
      final totalLines = '\n'.allMatches(text).length + 1;

      if (totalLines <= 1) return;

      // Calculate approximate scroll position
      final lineRatio = lineNumber / totalLines;
      final viewportHeight = _editorScrollController.position.viewportDimension;
      final targetScroll =
          (lineRatio * (maxScroll + viewportHeight) - viewportHeight / 2).clamp(
            0.0,
            maxScroll,
          );

      // Only scroll if cursor is likely outside the viewport
      final currentScroll = _editorScrollController.offset;
      final buffer = viewportHeight * 0.2; // 20% buffer zone

      if (targetScroll > currentScroll + viewportHeight - buffer ||
          targetScroll < currentScroll + buffer) {
        _editorScrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadCustomShortcuts() async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = await db.userSettingsDao.getValue(
      'markdown_shortcuts',
    );

    final defaults = DefaultMarkdownShortcuts.shortcuts;

    if (shortcutsJson != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsJson);
      final loaded = decoded
          .map((json) => CustomMarkdownShortcut.fromJson(json))
          .toList();

      // Create a set of loaded shortcut IDs to track what we have
      final loadedIds = loaded.map((s) => s.id).toSet();

      // Start with loaded shortcuts in their saved order
      final mergedShortcuts = List<CustomMarkdownShortcut>.from(loaded);

      // Add any new default shortcuts that weren't in the saved data
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
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final NoteSearchController searchController;
  final double editorFontSize;
  final VoidCallback onTextChanged;

  const _ModernEditorWrapper({
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
  }

  @override
  void dispose() {
    disposeScrollZone();
    super.dispose();
  }

  @override
  ScrollController getScrollController() => widget.scrollController;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: ListenableBuilder(
                    listenable: widget.searchController,
                    builder: (context, _) => _buildEditorContent(context),
                  ),
                ),
              );
            },
          ),
        ),
        buildScrollZone(width: _scrollZoneWidth),
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          child: ScrollProgressIndicator(
            scrollController: widget.scrollController,
          ),
        ),
      ],
    );
  }

  Widget _buildEditorContent(BuildContext context) {
    final hasMatches =
        widget.searchController.matches.isNotEmpty &&
        widget.searchController.isSearching;

    return hasMatches
        ? _buildHighlightedEditor(context)
        : _buildPlainEditor(context);
  }

  TextStyle _getBaseStyle(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: widget.editorFontSize,
      height: 1.5,
      color: theme.textTheme.bodyLarge?.color,
    );
  }

  InputDecoration _getInputDecoration(
    BuildContext context,
    TextStyle style, {
    bool showHint = true,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: showHint ? AppLocalizations.of(context)!.startWriting : null,
      hintStyle: TextStyle(
        color: theme.hintColor.withValues(alpha: 0.5),
        fontSize: widget.editorFontSize,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      filled: false,
    );
  }

  Widget _buildPlainEditor(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getBaseStyle(context);

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: style,
      cursorColor: theme.colorScheme.primary,
      cursorWidth: 2.5,
      cursorRadius: const Radius.circular(2),
      decoration: _getInputDecoration(context, style),
      onChanged: (_) => widget.onTextChanged(),
    );
  }

  Widget _buildHighlightedEditor(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getBaseStyle(context);
    final highlightSpans = _buildHighlightSpans(context, style);

    return Stack(
      children: [
        // Highlight layer
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: RichText(
            text: TextSpan(
              style: style.copyWith(color: theme.textTheme.bodyLarge?.color),
              children: highlightSpans,
            ),
          ),
        ),
        // Transparent text field for editing
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: style.copyWith(color: Colors.transparent),
          cursorColor: theme.colorScheme.primary,
          cursorWidth: 2.5,
          cursorRadius: const Radius.circular(2),
          decoration: _getInputDecoration(context, style, showHint: true),
          onChanged: (_) => widget.onTextChanged(),
        ),
      ],
    );
  }

  List<TextSpan> _buildHighlightSpans(BuildContext context, TextStyle style) {
    final text = widget.controller.text;
    final matches = widget.searchController.matches;
    final currentMatchIndex = widget.searchController.currentMatchIndex;
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match.start > text.length || match.end > text.length) continue;

      // Add text before match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, match.start), style: style),
        );
      }

      // Add highlighted match
      final isCurrentMatch = i == currentMatchIndex;
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: style.copyWith(
            backgroundColor: isCurrentMatch
                ? Colors.orange.withValues(alpha: 0.6)
                : Colors.yellow.withValues(alpha: 0.4),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return spans;
  }
}
