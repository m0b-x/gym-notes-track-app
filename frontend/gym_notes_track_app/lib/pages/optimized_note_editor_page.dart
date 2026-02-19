import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_notes_track_app/utils/markdown_settings_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/dev_options.dart';
import '../models/note_metadata.dart';
import '../services/auto_save_service.dart';
import '../services/dev_options_service.dart';
import '../services/note_position_service.dart';
import '../services/settings_service.dart';
import '../widgets/debug_overlays.dart';
import '../widgets/interactive_preview_scrollbar.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/modern_editor_wrapper.dart';
import '../widgets/full_markdown_view.dart';
import '../widgets/source_mapped_markdown_view.dart';
import '../widgets/note_search_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/unified_app_bars.dart';
import '../utils/editor_width_calculator.dart';
import '../utils/custom_snackbar.dart';
import '../utils/re_editor_search_controller.dart';
import '../utils/scroll_position_sync.dart';
import '../utils/text_history_observer.dart';
import '../utils/text_position_utils.dart';
import '../utils/markdown_list_utils.dart';
import '../config/default_markdown_shortcuts.dart';
import '../database/database.dart';
import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/json_keys.dart';
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

class _OptimizedNoteEditorPageState extends State<OptimizedNoteEditorPage>
    with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late CodeLineEditingController _contentController;
  late FocusNode _contentFocusNode;
  late CodeScrollController _editorScrollController;
  late TextHistoryObserver _historyObserver;
  final ScrollController _previewScrollController = ScrollController();
  late ReEditorSearchController _searchController;
  late ScrollPositionSync _scrollPositionSync;
  final GlobalKey<SourceMappedMarkdownViewState> _markdownViewKey = GlobalKey();
  final GlobalKey _editorWrapperKey = GlobalKey();
  final GlobalKey _lineNumbersKey = GlobalKey();
  final GlobalKey _scrollIndicatorKey = GlobalKey();

  bool _hasChanges = false;
  bool _isPreviewMode = false;
  bool _isLoading = true;
  bool _noteSwipeEnabled = true;
  bool _showStatsBar = true;

  // Editor settings
  bool _showLineNumbers = false;
  bool _wordWrap = true;
  bool _showCursorLine = false;
  bool _autoBreakLongLines = true;
  bool _previewWhenKeyboardHidden = false;
  bool _scrollCursorOnKeyboard = false;

  // Preview settings
  bool _showPreviewScrollbar = false;

  // Preview performance settings
  int _previewLinesPerChunk = 10;

  // Preview scroll progress (for scrollbar when using ScrollablePositionedList)
  final ValueNotifier<double> _previewScrollProgress = ValueNotifier(0.0);

  AutoSaveService? _autoSaveService;
  NotePositionService? _notePositionService;
  NotePositionData? _pendingPosition;

  /// For new notes: becomes non-null once the note is persisted for the first time.
  String? _effectiveNoteId;
  bool _isCreatingNewNote = false;

  double _previewFontSize = FontConstants.defaultFontSize;
  double _editorFontSize = FontConstants.defaultFontSize;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  String _previousText = '';
  String _cachedPreviewContent = '';
  bool _isProcessingTextChange = false;
  int _cachedLineCount = 1;
  int _cachedCharCount = 0;

  // Paste detection threshold - if text increases by more than this, it's likely a paste
  static const int _pasteThreshold = 20;

  Timer? _lineCountDebounceTimer;
  int _lastLineCountTextLength = 0;
  double _previousKeyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveNoteId = widget.noteId;
    _loadSwipeSetting();
    _initDevOptions();

    _titleController = TextEditingController(
      text: widget.metadata?.title ?? '',
    );
    _contentController = CodeLineEditingController();
    _historyObserver = TextHistoryObserver(_contentController);
    _previousText = '';
    _contentFocusNode = FocusNode();
    _editorScrollController = CodeScrollController();
    _searchController = ReEditorSearchController();
    _searchController.initialize(_contentController);
    _scrollPositionSync = ScrollPositionSync(
      previewScrollController: _previewScrollController,
      editorScrollController: _editorScrollController,
    );

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    if (widget.noteId != null) {
      _loadNoteContent();
    } else {
      _isLoading = false;
    }

    _loadCustomShortcuts();
    _initializeAutoSave();
    _loadFontSizes();
    _initializePositionService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Save immediately when the app loses focus (backgrounded, switched, etc.)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveOnLifecycleEvent();
    }
  }

  /// Performs a synchronous-as-possible save when the OS is about to
  /// suspend / kill the app.  For existing notes we force-save via the
  /// auto-save service; for brand-new notes that haven't been persisted
  /// yet we trigger an early create.
  void _saveOnLifecycleEvent() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    final noteId = _effectiveNoteId;
    if (noteId != null) {
      // Existing (or already-created) note – force save
      _autoSaveService?.forceSave(noteId, title, content);
    } else {
      // Brand-new note never saved – create it now
      _createNewNoteEarly();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track keyboard visibility to scroll cursor into view when keyboard appears
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (_scrollCursorOnKeyboard &&
        keyboardHeight > _previousKeyboardHeight &&
        keyboardHeight > 0) {
      // Keyboard just appeared - scroll to make cursor visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isPreviewMode) {
          _contentController.makeCursorVisible();
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  Future<void> _initializePositionService() async {
    _notePositionService = await NotePositionService.getInstance();
    if (widget.noteId != null) {
      final position = await _notePositionService!.getPosition(widget.noteId!);
      if (mounted) {
        setState(() {
          _pendingPosition = position;
          _isPreviewMode = position.isPreviewMode;
        });
      }
    }
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
    final showStats = await settings.getShowStatsBar();
    final showLineNumbers = await settings.getShowLineNumbers();
    final wordWrap = await settings.getWordWrap();
    final showCursorLine = await settings.getShowCursorLine();
    final showPreviewScrollbar = await settings.getShowPreviewScrollbar();
    final previewLinesPerChunk = await settings.getPreviewLinesPerChunk();
    final autoBreakLongLines = await settings.getAutoBreakLongLines();
    final previewWhenKeyboardHidden = await settings
        .getPreviewWhenKeyboardHidden();
    final scrollCursorOnKeyboard = await settings.getScrollCursorOnKeyboard();
    if (mounted) {
      setState(() {
        _noteSwipeEnabled = noteSwipe;
        _showStatsBar = showStats;
        _showLineNumbers = showLineNumbers;
        _wordWrap = wordWrap;
        _showCursorLine = showCursorLine;
        _showPreviewScrollbar = showPreviewScrollbar;
        _previewLinesPerChunk = previewLinesPerChunk;
        _autoBreakLongLines = autoBreakLongLines;
        _previewWhenKeyboardHidden = previewWhenKeyboardHidden;
        _scrollCursorOnKeyboard = scrollCursorOnKeyboard;
      });
    }
  }

  Future<void> _initDevOptions() async {
    // Initialize dev options service (loads settings from DB)
    await DevOptionsService.getInstance();
    // Listen for changes and rebuild if needed
    if (mounted) {
      DevOptions.instance.addListener(_onDevOptionsChanged);
    }
  }

  void _onDevOptionsChanged() {
    if (mounted) setState(() {});
  }

  void _initializeAutoSave() {
    _autoSaveService = AutoSaveService(
      onSave: (noteId, title, content) async {
        if (_effectiveNoteId != null) {
          context.read<OptimizedNoteBloc>().add(
            UpdateOptimizedNote(
              noteId: _effectiveNoteId!,
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

    if (_effectiveNoteId != null) {
      _autoSaveService?.startTracking(
        _effectiveNoteId!,
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

    // Reset retry budget on every fresh user edit
    _autoSaveService?.resetRetries();

    if (_effectiveNoteId != null) {
      _autoSaveService?.onContentChanged(
        _effectiveNoteId!,
        _titleController.text,
        _contentController.text,
      );
    } else {
      // New note: create early once there's meaningful content
      _maybeCreateNewNoteEarly();
    }
  }

  /// Triggers early creation as soon as the note has any title or content.
  void _maybeCreateNewNoteEarly() {
    if (_effectiveNoteId != null || _isCreatingNewNote) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isNotEmpty || content.isNotEmpty) {
      _createNewNoteEarly();
    }
  }

  /// Immediately persists a brand-new note and switches to update mode.
  void _createNewNoteEarly() {
    if (_effectiveNoteId != null || _isCreatingNewNote) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    _isCreatingNewNote = true;
    if (!mounted) return;
    context.read<OptimizedNoteBloc>().add(
      CreateOptimizedNote(
        folderId: widget.folderId,
        title: title,
        content: content,
      ),
    );
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

  void _togglePreviewMode() {
    final switchingToPreview = !_isPreviewMode;
    final totalLines = _contentController.lineCount;
    final isLargeNote = totalLines > AppConstants.previewPreloadLineThreshold;

    // Force-save when switching to preview – a natural checkpoint
    if (switchingToPreview && _effectiveNoteId != null) {
      _autoSaveService?.forceSave(
        _effectiveNoteId!,
        _titleController.text,
        _contentController.text,
      );
    }

    // Update cached preview content BEFORE switching
    if (switchingToPreview) {
      _cachedPreviewContent = _contentController.text;
      final lineIndex = _contentController.selection.baseIndex;

      if (isLargeNote) {
        // LARGE NOTE: Switch immediately, scroll with short animation
        // Preview builds lazily - no freeze from parsing all content at once
        setState(() {
          _isPreviewMode = true;
        });

        // Scroll after preview is visible with a quick animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _markdownViewKey.currentState?.scrollToLineIndex(
            lineIndex,
            totalLines,
            animate: true,
            duration: const Duration(milliseconds: 150),
          );
        });
      } else {
        // SMALL NOTE: Pre-scroll while offstage, then reveal (instant)
        // First setState to rebuild preview with new content (still offstage)
        setState(() {});

        // After rebuild completes, scroll then reveal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Now scroll to position (preview is still offstage)
          if (totalLines > 0) {
            _markdownViewKey.currentState?.scrollToLineIndex(
              lineIndex,
              totalLines,
              animate: false,
            );
          }

          // After scroll completes, reveal the preview
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isPreviewMode = true;
            });
            _saveCurrentPosition();
          });
        });
      }

      // Handle search
      if (_searchController.isSearching && _searchController.query.isNotEmpty) {
        final currentQuery = _searchController.query;
        _searchController.updateContent(_contentController.text);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchController.search(currentQuery);
          }
        });
      }

      if (!isLargeNote) {
        return; // Early return for small notes - async callbacks handle the rest
      }
      _saveCurrentPosition();
      return;
    }

    // Switching to editor mode
    if (_searchController.isSearching && _searchController.query.isNotEmpty) {
      final currentQuery = _searchController.query;
      Future.microtask(() {
        if (mounted) {
          _searchController.search(currentQuery);
        }
      });
    }

    // Just flip the mode
    setState(() {
      _isPreviewMode = switchingToPreview;
    });

    // Sync scroll for editor mode (preview -> editor)
    _scrollPositionSync.syncScrollOnModeSwitch(
      switchingToPreviewMode: false,
      content: _contentController.text,
      editorFontSize: _editorFontSize,
      previewFontSize: _previewFontSize,
      isMounted: () => mounted,
      contentController: _contentController,
      markdownViewKey: _markdownViewKey,
    );

    _saveCurrentPosition();
  }

  void _restoreSavedPosition() {
    final position = _pendingPosition;
    if (position == null) return;
    _pendingPosition = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (position.isPreviewMode) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (_previewScrollController.hasClients) {
            final maxScroll = _previewScrollController.position.maxScrollExtent;
            final offset = position.previewScrollOffset.clamp(0.0, maxScroll);
            _previewScrollController.jumpTo(offset);
          }
        });
      } else {
        final lineCount = _contentController.lineCount;
        final lineIndex = position.editorLineIndex.clamp(0, lineCount - 1);

        final lineText = lineIndex < _contentController.codeLines.length
            ? _contentController.codeLines[lineIndex].text
            : '';
        final columnOffset = position.editorColumnOffset.clamp(
          0,
          lineText.length,
        );

        _contentController.selection = CodeLineSelection.collapsed(
          index: lineIndex,
          offset: columnOffset,
        );

        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _editorScrollController.makeCenterIfInvisible(
            CodeLinePosition(index: lineIndex, offset: columnOffset),
          );
        });
      }
    });
  }

  Future<void> _saveCurrentPosition() async {
    final noteId = _effectiveNoteId ?? widget.noteId;
    if (noteId == null || _notePositionService == null) return;

    final position = NotePositionData(
      isPreviewMode: _isPreviewMode,
      previewScrollOffset: _previewScrollController.hasClients
          ? _previewScrollController.offset
          : 0.0,
      editorLineIndex: _contentController.selection.baseIndex,
      editorColumnOffset: _contentController.selection.baseOffset,
    );

    await _notePositionService!.savePosition(noteId, position);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DevOptions.instance.removeListener(_onDevOptionsChanged);
    _lineCountDebounceTimer?.cancel();
    _autoSaveService?.stopTracking(_effectiveNoteId ?? widget.noteId ?? '');
    _autoSaveService?.dispose();
    _titleController.dispose();
    _historyObserver.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    _searchController.dispose();
    _previewScrollProgress.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_searchController.isSearching) {
      _searchController.closeSearch();
    } else {
      _searchController.openSearch();
    }
    setState(() {});
  }

  void _navigateToSearchMatch(int offset) {
    final match = _searchController.currentMatch;
    if (match == null) return;

    final text = _contentController.text;
    if (text.isEmpty ||
        match.start < 0 ||
        match.end < 0 ||
        match.start > text.length ||
        match.end > text.length) {
      return;
    }

    if (_isPreviewMode) {
      _scrollToOffsetInPreview(match.start);
    }
  }

  void _handleCheckboxToggle(CheckboxToggleInfo info) {
    final text = _contentController.text;
    final startLine = TextPositionUtils.getLineFromOffset(text, info.start);
    final startCol = TextPositionUtils.getColumnFromOffset(text, info.start);
    final endLine = TextPositionUtils.getLineFromOffset(text, info.end);
    final endCol = TextPositionUtils.getColumnFromOffset(text, info.end);

    // Select the checkbox bracket range [x] or [ ] and replace atomically
    _contentController.runRevocableOp(() {
      _contentController.selection = CodeLineSelection(
        baseIndex: startLine,
        baseOffset: startCol,
        extentIndex: endLine,
        extentOffset: endCol,
      );
      _contentController.replaceSelection(info.replacement);
    });
    _hasChanges = true;

    if (_isPreviewMode) {
      _cachedPreviewContent = _contentController.text;
      setState(() {});
    }
  }

  void _scrollToOffsetInPreview(int charOffset) {
    // Use the SourceMappedMarkdownView's native scroll method
    // which uses actual widget positions (not estimated line heights)
    _markdownViewKey.currentState?.scrollToSourceOffset(charOffset);
  }

  /// Handle double-tap on preview to navigate to source line in editor
  void _handleDoubleTapLine(int lineIndex, int columnOffset) {
    if (!_isPreviewMode) return;

    final lineCount = _contentController.lineCount;
    if (lineCount == 0) return;

    // Clamp line index to valid range
    final clampedLineIndex = lineIndex.clamp(0, lineCount - 1);

    // Get the line text and set cursor at the end of the line
    final lineText = clampedLineIndex < _contentController.codeLines.length
        ? _contentController.codeLines[clampedLineIndex].text
        : '';
    final endOfLineOffset = lineText.length;

    // Switch to editor mode
    setState(() {
      _isPreviewMode = false;
    });

    // Navigate to the line after mode switch completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Set cursor position at end of line
      _contentController.selection = CodeLineSelection.collapsed(
        index: clampedLineIndex,
        offset: endOfLineOffset,
      );

      // Scroll to make the line visible (centered if possible)
      _editorScrollController.makeCenterIfInvisible(
        CodeLinePosition(index: clampedLineIndex, offset: endOfLineOffset),
      );

      // Focus the editor
      _contentFocusNode.requestFocus();
    });

    _saveCurrentPosition();
  }

  void _handleSearchReplace(String _, String newContent) {
    // Note: Replace is handled by CodeFindController internally
    // The newContent parameter is kept for API compatibility
    // but the actual text change happens through the controller
    _hasChanges = true;
  }

  void _handleTextChange() {
    if (_isProcessingTextChange) return;

    final text = _contentController.text;
    final selection = _contentController.selection;

    final textLengthDiff = text.length - _previousText.length;
    final textLengthIncreased = textLengthDiff > 0;

    // Detect paste: large text additions
    final isPaste = textLengthDiff > _pasteThreshold;

    _previousText = text;

    if (!textLengthIncreased) return;

    // Handle paste: break long lines to fit editor width.
    // _handlePasteLineBreaking sets controller.value directly (bypassing
    // runRevocableOp) so the reformatting overwrites the paste's undo
    // node — making paste + reformat a single undo entry.
    if (isPaste) {
      _handlePasteLineBreaking();
      return;
    }

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

      if (MarkdownListUtils.isEmptyListItem(prevLine.trim())) {
        // Remove the empty list item line — merge with the Enter undo node
        // by setting value directly (bypasses runRevocableOp).
        final newText = text.replaceRange(
          _getLineStartOffset(prevLineIndex),
          _getLineStartOffset(currentLineIndex),
          '',
        );
        _contentController.value = CodeLineEditingValue(
          codeLines: newText.codeLines,
          selection: CodeLineSelection.collapsed(
            index: prevLineIndex,
            offset: 0,
          ),
        );
        _previousText = newText;
        _isProcessingTextChange = false;
        return;
      }

      String? listPrefix = MarkdownListUtils.getListPrefix(prevLine);
      if (listPrefix != null) {
        // Insert the list prefix — merge with the Enter undo node
        // by setting value directly (bypasses runRevocableOp).
        final currentLine = _contentController.codeLines[currentLineIndex];
        final newLineText = '$listPrefix${currentLine.text}';
        final newCodeLines = CodeLines.of([
          for (int i = 0; i < _contentController.codeLines.length; i++)
            if (i == currentLineIndex)
              CodeLine(newLineText)
            else
              _contentController.codeLines[i],
        ]);
        _contentController.value = CodeLineEditingValue(
          codeLines: newCodeLines,
          selection: CodeLineSelection.collapsed(
            index: currentLineIndex,
            offset: listPrefix.length,
          ),
        );
        _previousText = _contentController.text;
      }
      _isProcessingTextChange = false;
    }
  }

  /// Creates an EditorWidthCalculator with current configuration
  EditorWidthCalculator _createWidthCalculator() {
    return EditorWidthCalculator(
      config: EditorWidthConfig(
        editorContainerKey: _editorWrapperKey,
        lineNumbersKey: _showLineNumbers ? _lineNumbersKey : null,
        scrollIndicatorKey: _scrollIndicatorKey,
        fontSize: _editorFontSize,
      ),
      editorPadding: EdgeInsets.only(
        left: AppSpacing.lg,
        top: AppSpacing.lg,
        right: AppSpacing.lg + 48,
        bottom: AppSpacing.lg,
      ),
    );
  }

  /// Handle paste by breaking long lines to fit editor width.
  /// Respects markdown syntax and skips code blocks.
  void _handlePasteLineBreaking() {
    // Check if feature is enabled
    if (!_autoBreakLongLines) return;

    _isProcessingTextChange = true;

    final calculator = _createWidthCalculator();
    final availableWidth = calculator.getAvailableTextWidth();
    if (availableWidth == null) {
      _isProcessingTextChange = false;
      return;
    }

    // Get all lines as strings
    final codeLines = _contentController.codeLines;
    final lineCount = codeLines.length;
    final lines = <String>[];
    for (int i = 0; i < lineCount; i++) {
      lines.add(codeLines[i].text);
    }

    // Use smart line breaking that respects code blocks and markdown syntax
    final result = calculator.breakLinesSmartly(lines, availableWidth);

    if (result.linesModified > 0) {
      final newText = result.lines.join('\n');
      if (newText != _contentController.text) {
        // Set value directly (not via `set text`) to bypass runRevocableOp.
        // This makes the reformatting overwrite the paste's undo node
        // so that paste + line-breaking is a single undo entry.
        _contentController.value = CodeLineEditingValue(
          codeLines: newText.codeLines,
          selection: CodeLineSelection.collapsed(
            index: result.lines.length - 1,
            offset: result.lines.last.length,
          ),
        );
        _previousText = newText;

        // Show toast notification
        if (mounted) {
          CustomSnackbar.show(
            context,
            AppLocalizations.of(context)!.linesFormatted(result.linesModified),
            withToolbarOffset: true,
          );
        }
      }
    }

    _isProcessingTextChange = false;
  }

  int _getLineStartOffset(int lineIndex) {
    int offset = 0;
    final codeLines = _contentController.codeLines;
    for (int i = 0; i < lineIndex && i < codeLines.length; i++) {
      offset += codeLines[i].text.length + 1;
    }
    return offset;
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
            _cachedPreviewContent = content;
            _cachedLineCount = '\n'.allMatches(content).length + 1;
            _cachedCharCount = content.length;
            _isLoading = false;
          });
          _restoreSavedPosition();
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
          appBar: NoteAppBar(
            title: _titleController.text.isEmpty
                ? AppLocalizations.of(context)!.newNote
                : _titleController.text,
            hasChanges: _hasChanges,
            saveStatusNotifier: _autoSaveService?.saveStatusNotifier,
            onTitleTap: _editTitle,
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
                    ? AppLocalizations.of(context)!.previewMarkdown
                    : AppLocalizations.of(context)!.switchToEditMode,
                waitDuration: AppConstants.debounceDelay,
                child: IconButton(
                  icon: Icon(_isPreviewMode ? Icons.visibility : Icons.edit),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Builder(
                          builder: (context) {
                            final keyboardVisible =
                                MediaQuery.of(context).viewInsets.bottom > 0;
                            // Show preview if:
                            // 1. User toggled preview mode manually, OR
                            // 2. previewWhenKeyboardHidden is enabled AND keyboard is hidden
                            final showPreview =
                                _isPreviewMode ||
                                (_previewWhenKeyboardHidden &&
                                    !keyboardVisible);

                            // Only calculate debug info if any debug option is enabled
                            final devOptions = DevOptions.instance;
                            if (!devOptions.anyEnabled) {
                              return Stack(
                                children: [
                                  Offstage(
                                    offstage:
                                        showPreview, // Hide editor when showing preview
                                    child: _buildEditor(),
                                  ),
                                  Offstage(
                                    offstage:
                                        !showPreview, // Hide preview when showing editor
                                    child: _buildPreview(),
                                  ),
                                ],
                              );
                            }

                            final selection = _contentController.selection;
                            final cursorLine = selection.baseIndex + 1;
                            final cursorColumn = selection.baseOffset;
                            final cursorOffset =
                                _getLineStartOffset(selection.baseIndex) +
                                selection.baseOffset;
                            final int? selStart;
                            final int? selEnd;
                            if (selection.isCollapsed) {
                              selStart = null;
                              selEnd = null;
                            } else {
                              // Get start and end offsets based on normalized selection
                              final baseOff =
                                  _getLineStartOffset(selection.baseIndex) +
                                  selection.baseOffset;
                              final extentOff =
                                  _getLineStartOffset(selection.extentIndex) +
                                  selection.extentOffset;
                              if (baseOff <= extentOff) {
                                selStart = baseOff;
                                selEnd = extentOff;
                              } else {
                                selStart = extentOff;
                                selEnd = baseOff;
                              }
                            }
                            final noteSize = _contentController.text.length;

                            return DebugOverlayStack(
                              cursorLine: cursorLine,
                              cursorColumn: cursorColumn,
                              cursorOffset: cursorOffset,
                              selectionStart: selStart,
                              selectionEnd: selEnd,
                              noteSize: noteSize,
                              child: Stack(
                                children: [
                                  Offstage(
                                    offstage:
                                        showPreview, // Hide editor when showing preview
                                    child: _buildEditor(),
                                  ),
                                  Offstage(
                                    offstage:
                                        !showPreview, // Hide preview when showing editor
                                    child: _buildPreview(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Show toolbar only when keyboard is visible (edit mode) or in preview mode
                    if (_isPreviewMode ||
                        MediaQuery.of(context).viewInsets.bottom > 0)
                      RepaintBoundary(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MarkdownToolbar(
                              shortcuts: _allShortcuts,
                              isPreviewMode: _isPreviewMode,
                              canUndo: _historyObserver.canUndo,
                              canRedo: _historyObserver.canRedo,
                              previewFontSize: _isPreviewMode
                                  ? _previewFontSize
                                  : _editorFontSize,
                              onUndo: () => _historyObserver.undo(),
                              onRedo: () => _historyObserver.redo(),
                              onPaste: () => _contentController.paste(),
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
                              onShare: _showExportFormatDialog,
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
    // For large notes, don't pre-build preview to avoid memory/CPU overhead
    // The preview will build when actually needed (when switching to preview mode)
    final isLargeNote =
        _cachedLineCount > AppConstants.previewPreloadLineThreshold;
    if (!_isPreviewMode && isLargeNote) {
      return const SizedBox.shrink();
    }

    // Use cached content to avoid re-parsing on every keystroke
    // Content is updated only when switching to preview mode
    final content = _cachedPreviewContent.isEmpty
        ? AppLocalizations.of(context)!.noContentYet
        : _cachedPreviewContent;

    // Only update search content when we're actually in preview mode
    if (_isPreviewMode) {
      _searchController.updateContent(content);
    }

    // Use Listenable.merge to listen to both search and dev options changes
    final markdownView = ListenableBuilder(
      listenable: Listenable.merge([_searchController, DevOptions.instance]),
      builder: (context, _) => SourceMappedMarkdownView(
        key: _markdownViewKey,
        data: content,
        fontSize: _previewFontSize,
        scrollController: _previewScrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        onCheckboxToggle: _handleCheckboxToggle,
        linesPerChunk: _previewLinesPerChunk,
        onScrollProgress: (progress) {
          _previewScrollProgress.value = progress;
        },
        onDoubleTapLine: _handleDoubleTapLine,
        searchHighlights: _isPreviewMode && _searchController.isSearching
            ? _searchController.matches
                  .map((m) => TextRange(start: m.start, end: m.end))
                  .toList()
            : null,
        currentHighlightIndex: _isPreviewMode && _searchController.isSearching
            ? _searchController.currentMatchIndex
            : null,
      ),
    );

    // If scrollbar is disabled, just return the markdown view
    if (!_showPreviewScrollbar) {
      return KeyedSubtree(key: const ValueKey('preview'), child: markdownView);
    }

    return Stack(
      key: const ValueKey('preview'),
      alignment: Alignment.topLeft,
      children: [
        Positioned.fill(child: markdownView),
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          child: InteractivePreviewScrollbar(
            progressNotifier: _previewScrollProgress,
            markdownViewKey: _markdownViewKey,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final devOptions = DevOptions.instance;
    final showChunkDebug = devOptions.showChunkIndicators;

    return KeyedSubtree(
      key: _editorWrapperKey,
      child: ModernEditorWrapper(
        key: const ValueKey('editor'),
        controller: _contentController,
        focusNode: _contentFocusNode,
        scrollController: _editorScrollController,
        searchController: _searchController,
        editorFontSize: _editorFontSize,
        onTextChanged: _handleTextChange,
        showLineNumbers: _showLineNumbers,
        wordWrap: _wordWrap,
        showCursorLine: _showCursorLine,
        lineNumbersKey: _lineNumbersKey,
        scrollIndicatorKey: _scrollIndicatorKey,
        // Chunk debug visualization (matches preview mode)
        linesPerChunk: _previewLinesPerChunk,
        showChunkColors: showChunkDebug && devOptions.colorMarkdownBlocks,
        showChunkBorders: showChunkDebug && devOptions.showBlockBoundaries,
      ),
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

    await _saveCurrentPosition();

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      return;
    }

    if (_effectiveNoteId == null) {
      // Note was never persisted – create it now
      if (!mounted) return;
      context.read<OptimizedNoteBloc>().add(
        CreateOptimizedNote(
          folderId: widget.folderId,
          title: title,
          content: content,
        ),
      );
    } else {
      await _autoSaveService?.forceSave(_effectiveNoteId!, title, content);
    }
  }

  void _showExportFormatDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chooseExportFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsMarkdown),
              onTap: () {
                Navigator.pop(dialogContext);
                _shareNote('md');
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsJson),
              onTap: () {
                Navigator.pop(dialogContext);
                _shareNote('json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsText),
              onTap: () {
                Navigator.pop(dialogContext);
                _shareNote('txt');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _shareNote(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(AppLocalizations.of(dialogContext)!.exportingNote),
          ],
        ),
      ),
    );

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text;

      String fileContent;
      String extension;

      switch (format) {
        case 'md':
          extension = 'md';
          final noteTitle = title.isEmpty ? 'Untitled' : title;
          fileContent = '# $noteTitle\n\n$content';
          break;
        case 'json':
          extension = 'json';
          final noteJson = {
            JsonKeys.title: title,
            JsonKeys.content: content,
            JsonKeys.createdAt:
                widget.metadata?.createdAt.toIso8601String() ??
                DateTime.now().toIso8601String(),
            JsonKeys.updatedAt:
                widget.metadata?.updatedAt.toIso8601String() ??
                DateTime.now().toIso8601String(),
            JsonKeys.exportedAt: DateTime.now().toIso8601String(),
          };
          fileContent = const JsonEncoder.withIndent('  ').convert(noteJson);
          break;
        case 'txt':
        default:
          extension = 'txt';
          fileContent = content;
          break;
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = title.isEmpty
          ? 'note_${widget.noteId?.substring(0, 8) ?? 'new'}'
          : title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '$sanitizedTitle.$extension';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(fileContent);

      if (!mounted) return;
      Navigator.pop(context);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.noteExportError}: $e'),
        ),
      );
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
    // Wrap the entire shortcut operation in an atomic undo entry
    // so that e.g. date insertion + repeat + wrapper text all revert together.
    _contentController.runRevocableOp(() {
      _applyShortcut(shortcut);
    });

    _onTextChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _contentController.makeCursorVisible();
      }
    });
  }

  void _applyShortcut(CustomMarkdownShortcut shortcut) {
    final selectedText = _contentController.selectedText;
    final repeatCount = shortcut.repeatConfig?.count ?? 1;
    final separator = shortcut.repeatConfig?.separator ?? '\n';
    final beforeRepeatText = shortcut.repeatConfig?.beforeRepeatText ?? '';
    final afterRepeatText = shortcut.repeatConfig?.afterRepeatText ?? '';

    if (shortcut.insertType == 'date') {
      final format = shortcut.dateFormat ?? 'yyyy-MM-dd';
      final dateOffset = shortcut.dateOffset;
      final repeatConfig = shortcut.repeatConfig;

      // Calculate base date with offset
      var baseDate = DateTime.now();
      if (dateOffset != null) {
        baseDate = DateTime(
          baseDate.year + dateOffset.years,
          baseDate.month + dateOffset.months,
          baseDate.day + dateOffset.days,
        );
      }

      // Generate repeated dates
      final results = <String>[];
      for (int i = 0; i < repeatCount; i++) {
        var date = baseDate;

        // Apply incremental date offset for each repetition
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

      // Apply wrapper text around all repeated items
      if (beforeRepeatText.isNotEmpty || afterRepeatText.isNotEmpty) {
        wrapped = '$beforeRepeatText$wrapped$afterRepeatText';
      }

      _contentController.replaceSelection(wrapped);
    } else if (shortcut.insertType == 'header') {
      final selection = _contentController.selection;
      final lineIndex = selection.startIndex;
      final line = _contentController.codeLines[lineIndex];
      final lineText = line.text;

      final headerMatch = RegExp(r'^(#{1,6})\s').firstMatch(lineText);
      String newLineText;

      if (headerMatch != null) {
        final currentHashes = headerMatch.group(1)!;
        final textWithoutHeader = lineText.substring(headerMatch.end);

        if (currentHashes.length >= 6) {
          newLineText = textWithoutHeader;
        } else {
          newLineText = '$currentHashes# $textWithoutHeader';
        }
      } else {
        newLineText = '# $lineText';
      }

      _contentController.selectLine(lineIndex);
      _contentController.replaceSelection(newLineText);
    } else {
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

      // Apply repeat if configured
      if (repeatCount > 1) {
        wrapped = List.filled(repeatCount, wrapped).join(separator);
      }

      // Apply wrapper text around all repeated items
      if (beforeRepeatText.isNotEmpty || afterRepeatText.isNotEmpty) {
        wrapped = '$beforeRepeatText$wrapped$afterRepeatText';
      }

      _contentController.replaceSelection(wrapped);
    }
  }

  Future<void> _loadCustomShortcuts() async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = await db.userSettingsDao.getValue(
      SettingsKeys.markdownShortcuts,
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
    final db = await AppDatabase.getInstance();
    final shortcutsJson = _allShortcuts.map((s) => s.toJson()).toList();
    await db.userSettingsDao.setValue(
      SettingsKeys.markdownShortcuts,
      jsonEncode(shortcutsJson),
    );
  }

  Future<void> _openMarkdownSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownSettingsPage(allShortcuts: _allShortcuts),
      ),
    );

    // Reload shortcuts from database (they are saved immediately in settings page)
    final shortcuts = await MarkdownSettingsUtils.loadShortcuts();
    if (mounted) {
      setState(() => _allShortcuts = shortcuts);
    }
  }
}
