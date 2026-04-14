import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_dialogs.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../bloc/markdown_bar/markdown_bar_bloc.dart';
import '../bloc/counter/counter_bloc.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/dev_options.dart';
import '../models/markdown_bar_profile.dart';
import '../models/note_metadata.dart';
import '../models/utility_button_config.dart';
import '../services/auto_save_service.dart';
import '../services/dev_options_service.dart';
import '../services/note_position_service.dart';
import '../services/settings_service.dart';
import '../factories/shortcut_handler_factory.dart';
import '../widgets/bar_switcher_sheet.dart';

import '../widgets/debug_overlays.dart';
import '../widgets/interactive_preview_scrollbar.dart';
import '../widgets/markdown_bar.dart';
import '../widgets/modern_editor_wrapper.dart';
import '../widgets/full_markdown_view.dart';
import '../widgets/source_mapped_markdown_view.dart';
import '../widgets/note_search_bar.dart';
import '../widgets/app_drawer.dart';
import '../services/app_navigator.dart';
import '../widgets/unified_app_bars.dart';
import '../utils/editor_width_calculator.dart';
import '../utils/custom_snackbar.dart';
import '../utils/re_editor_search_controller.dart';
import '../utils/text_history_observer.dart';
import '../utils/text_position_utils.dart';
import '../utils/markdown_list_utils.dart';
import '../controllers/preview_scroll_controller.dart';
import '../database/database.dart';
import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/json_keys.dart';
import '../constants/markdown_constants.dart';
import '../constants/settings_keys.dart';

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
  late ReEditorSearchController _searchController;
  late PreviewScrollController _previewController;
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

  // Toolbar settings
  double _toolbarShortcutRatio = SettingsKeys.defaultToolbarShortcutRatio;
  bool _toolbarSplitEnabled = SettingsKeys.defaultToolbarSplitEnabled;
  List<UtilityButtonConfig> _utilityConfigs = UtilityButtonConfig.defaults();

  /// The resolved bar profile currently active for this note.
  String _activeBarProfileId = MarkdownBarProfile.defaultProfileId;

  /// Saved editor selection for restoring cursor position after preview→editor.
  CodeLineSelection? _savedEditorSelection;

  AutoSaveService? _autoSaveService;
  NotePositionService? _notePositionService;
  NotePositionData? _pendingPosition;

  /// For new notes: becomes non-null once the note is persisted for the first time.
  String? _effectiveNoteId;
  bool _isCreatingNewNote = false;

  /// Cached reference so we can dispatch [SetNoteContext] during [dispose].
  late final CounterBloc _counterBloc;

  double _previewFontSize = FontConstants.defaultFontSize;
  double _editorFontSize = FontConstants.defaultFontSize;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  int _previousTextLength = 0;
  String _cachedPreviewContent = '';
  bool _isProcessingTextChange = false;
  int _cachedLineCount = 1;
  int _cachedCharCount = 0;

  // Paste detection threshold - if text increases by more than this, it's likely a paste
  static const int _pasteThreshold = 20;

  Timer? _lineCountDebounceTimer;
  Timer? _restorePositionTimer;
  int _lastLineCountTextLength = 0;
  double _previousKeyboardHeight = 0;
  bool _isTogglingPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveNoteId = widget.noteId;
    _loadEditorSettings();
    _initDevOptions();

    _titleController = TextEditingController(
      text: widget.metadata?.title ?? '',
    );
    _contentController = CodeLineEditingController();
    _historyObserver = TextHistoryObserver(_contentController);
    _previousTextLength = 0;
    _contentFocusNode = FocusNode();
    _editorScrollController = CodeScrollController();
    _searchController = ReEditorSearchController();
    _searchController.initialize(_contentController);
    _previewController = PreviewScrollController()
      ..bindView(GlobalKey<SourceMappedMarkdownViewState>());

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    if (widget.noteId != null) {
      _loadNoteContent();
    } else {
      _isLoading = false;
    }

    context.read<MarkdownBarBloc>().add(
      LoadMarkdownBar(noteId: _effectiveNoteId ?? widget.noteId),
    );
    ShortcutHandlerFactory.counterHandler.setActiveNoteId(
      _effectiveNoteId ?? widget.noteId,
    );
    _counterBloc = context.read<CounterBloc>();
    _counterBloc.add(SetNoteContext(noteId: _effectiveNoteId));
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
    final noteId = _effectiveNoteId;
    if (noteId != null) {
      // Existing (or already-created) note – force save via provider
      _autoSaveService?.forceSave(title: _titleController.text);
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

    // When keyboard dismisses and previewWhenKeyboardHidden is on,
    // refresh the cached preview content so the auto-shown preview
    // reflects the latest edits instead of stale text.
    if (_previewWhenKeyboardHidden &&
        _previousKeyboardHeight > 0 &&
        keyboardHeight == 0) {
      _cachedPreviewContent = _contentController.text;
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

  void _decreaseFontSize() {
    setState(() {
      if (_isPreviewMode) {
        _previewFontSize = (_previewFontSize - FontConstants.fontSizeStep)
            .clamp(FontConstants.minFontSize, FontConstants.maxFontSize);
      } else {
        _editorFontSize = (_editorFontSize - FontConstants.fontSizeStep).clamp(
          FontConstants.minFontSize,
          FontConstants.maxFontSize,
        );
      }
    });
    _saveFontSizes();
  }

  void _increaseFontSize() {
    setState(() {
      if (_isPreviewMode) {
        _previewFontSize = (_previewFontSize + FontConstants.fontSizeStep)
            .clamp(FontConstants.minFontSize, FontConstants.maxFontSize);
      } else {
        _editorFontSize = (_editorFontSize + FontConstants.fontSizeStep).clamp(
          FontConstants.minFontSize,
          FontConstants.maxFontSize,
        );
      }
    });
    _saveFontSizes();
  }

  Future<void> _loadEditorSettings() async {
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
    final toolbarRatio = await settings.getToolbarShortcutRatio();
    final toolbarSplit = await settings.getToolbarSplitEnabled();
    final utilityConfigs = await settings.getToolbarUtilityConfig();
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
        _toolbarShortcutRatio = toolbarRatio;
        _toolbarSplitEnabled = toolbarSplit;
        _utilityConfigs = utilityConfigs;
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
      onSave: (title, content) async {
        if (_effectiveNoteId != null) {
          final completer = Completer<void>();
          context.read<OptimizedNoteBloc>().add(
            UpdateOptimizedNote(
              noteId: _effectiveNoteId!,
              title: title,
              content: content,
              completer: completer,
            ),
          );
          await completer.future;
        }
      },
      onChangeDetected: (hasChanges) {
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
        _titleController.text,
        _contentController.text,
        contentProvider: () => _contentController.text,
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

    if (_effectiveNoteId != null) {
      _autoSaveService?.onContentChanged(_titleController.text);
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
    final currentLength = _contentController.textLength;
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
      _lastLineCountTextLength = _contentController.textLength;
    });
  }

  void _updateCachedStats() {
    if (!mounted) return;
    final newCharCount = _contentController.textLength;
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
    if (_isTogglingPreview) return;
    final switchingToPreview = !_isPreviewMode;
    final totalLines = _contentController.lineCount;
    final isLargeNote = totalLines > AppConstants.previewPreloadLineThreshold;

    // Force-save when switching to preview – a natural checkpoint
    // Compute text once — reused for force-save, cached preview, and search.
    final currentText = switchingToPreview ? _contentController.text : null;

    if (switchingToPreview && _effectiveNoteId != null) {
      _autoSaveService?.forceSave(
        title: _titleController.text,
        content: currentText!,
      );
    }

    // Update cached preview content BEFORE switching
    if (switchingToPreview) {
      _cachedPreviewContent = currentText!;
      final lineIndex = _contentController.selection.baseIndex;

      // Save editor position so we can restore it when switching back.
      _savedEditorSelection = _contentController.selection;

      if (isLargeNote) {
        // LARGE NOTE: Switch immediately, scroll with short animation
        // Preview builds lazily - no freeze from parsing all content at once
        _isTogglingPreview = true;
        setState(() {
          _isPreviewMode = true;
        });

        // Scroll after preview is visible with a quick animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isTogglingPreview = false;
          if (!mounted) return;
          _previewController.scrollToLineIndex(
            lineIndex,
            totalLines,
            animate: true,
            duration: const Duration(milliseconds: 150),
          );
        });
      } else {
        // SMALL NOTE: Pre-scroll while offstage, then reveal (instant)
        // First setState to rebuild preview with new content (still offstage)
        _isTogglingPreview = true;
        setState(() {});

        // After rebuild completes, scroll then reveal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            _isTogglingPreview = false;
            return;
          }

          // Now scroll to position (preview is still offstage)
          if (totalLines > 0) {
            _previewController.scrollToLineIndex(
              lineIndex,
              totalLines,
              animate: false,
            );
          }

          // After scroll completes, reveal the preview
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _isTogglingPreview = false;
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
        _searchController.updateContent(currentText);
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

    // Restore editor scroll: ensure the cursor line is visible after
    // the keyboard animation finishes.
    _restoreEditorPosition();

    _saveCurrentPosition();
  }

  void _restoreSavedPosition() {
    final position = _pendingPosition;
    if (position == null) return;
    _pendingPosition = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (position.isPreviewMode) {
        // Restore preview scroll using progress ratio (0.0–1.0)
        // via the PreviewScrollController's deferred restore.
        _previewController.restoreProgress(
          position.previewScrollProgress.clamp(0.0, 1.0),
        );
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

        _restorePositionTimer?.cancel();
        _restorePositionTimer = Timer(const Duration(milliseconds: 100), () {
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
      previewScrollProgress: _previewController.progress.value,
      editorLineIndex: _contentController.selection.baseIndex,
      editorColumnOffset: _contentController.selection.baseOffset,
    );

    await _notePositionService!.savePosition(noteId, position);
  }

  /// Restores the editor cursor position after switching from preview mode.
  /// Uses a delayed callback to account for the keyboard animation.
  void _restoreEditorPosition() {
    final selection = _savedEditorSelection;
    if (selection == null) return;

    final position = CodeLinePosition(
      index: selection.baseIndex,
      offset: selection.baseOffset,
    );

    // The keyboard may animate open when the editor regains focus.
    // Wait for that animation before scrolling, otherwise the cursor
    // might end up behind the keyboard.
    _restorePositionTimer?.cancel();
    _restorePositionTimer = Timer(
      Duration(milliseconds: Platform.isIOS ? 300 : 350),
      () {
        if (!mounted) return;
        _editorScrollController.makeCenterIfInvisible(position);
      },
    );
  }

  @override
  void dispose() {
    _counterBloc.add(const SetNoteContext());
    WidgetsBinding.instance.removeObserver(this);
    DevOptions.instance.removeListener(_onDevOptionsChanged);
    _lineCountDebounceTimer?.cancel();
    _restorePositionTimer?.cancel();
    _previewController.dispose();
    _autoSaveService?.dispose();
    _titleController.dispose();
    _historyObserver.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _editorScrollController.dispose();
    _searchController.dispose();
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

    final textLen = _contentController.textLength;
    if (textLen == 0 ||
        match.start < 0 ||
        match.end < 0 ||
        match.start > textLen ||
        match.end > textLen) {
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
    // Use the PreviewScrollController which delegates to the
    // SourceMappedMarkdownView's native scroll method.
    _previewController.scrollToSourceOffset(charOffset);
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

    final selection = _contentController.selection;

    final currentTextLength = _contentController.textLength;
    final textLengthDiff = currentTextLength - _previousTextLength;
    final textLengthIncreased = textLengthDiff > 0;

    // Detect paste: large text additions
    final isPaste = textLengthDiff > _pasteThreshold;

    // Calculate paste location before updating _previousTextLength
    int? pasteStartOffset;
    int? pasteEndOffset;
    if (isPaste && textLengthIncreased) {
      // The selection end is where the paste ended
      pasteEndOffset = _getOffsetFromSelection(selection.extent);
      // The paste started textLengthDiff characters before the end
      pasteStartOffset = pasteEndOffset - textLengthDiff;
      if (pasteStartOffset < 0) pasteStartOffset = 0;
    }

    _previousTextLength = currentTextLength;

    if (!textLengthIncreased) return;

    // Handle paste: break long lines to fit editor width.
    // _handlePasteLineBreaking sets controller.value directly (bypassing
    // runRevocableOp) so the reformatting overwrites the paste's undo
    // node — making paste + reformat a single undo entry.
    if (isPaste && pasteStartOffset != null && pasteEndOffset != null) {
      _handlePasteLineBreaking(pasteStartOffset, pasteEndOffset);
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
        // Need full text here for replaceRange (rare path: Enter on empty list item).
        final text = _contentController.text;
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
        _previousTextLength = _contentController.textLength;
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
        _previousTextLength = _contentController.textLength;
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
        fontFamily: FontConstants.editorFontFamily,
      ),
      editorPadding: EdgeInsets.only(
        left: AppSpacing.lg,
        top: AppSpacing.lg,
        right: AppSpacing.lg + AppConstants.editorScrollbarPadding,
        bottom: AppSpacing.lg,
      ),
    );
  }

  /// Handle paste by breaking long lines to fit editor width.
  /// Respects markdown syntax and skips code blocks.
  /// Only formats lines within the pasted range.
  void _handlePasteLineBreaking(int pasteStartOffset, int pasteEndOffset) {
    // Check if feature is enabled
    if (!_autoBreakLongLines) return;

    _isProcessingTextChange = true;

    final calculator = _createWidthCalculator();
    final availableWidth = calculator.getAvailableTextWidth();
    if (availableWidth == null || availableWidth <= 0) {
      _isProcessingTextChange = false;
      return;
    }

    final text = _contentController.text;
    final codeLines = _contentController.codeLines;
    final lineCount = codeLines.length;

    // Find which lines contain the pasted text
    final pasteStartLine = TextPositionUtils.getLineFromOffset(
      text,
      pasteStartOffset,
    );
    final pasteEndLine = TextPositionUtils.getLineFromOffset(
      text,
      pasteEndOffset,
    );

    // Only process the pasted lines
    final linesToProcess = <String>[];
    for (int i = pasteStartLine; i <= pasteEndLine && i < lineCount; i++) {
      linesToProcess.add(codeLines[i].text);
    }

    // Use smart line breaking on pasted lines only
    final result = calculator.breakLinesSmartly(linesToProcess, availableWidth);

    if (result.linesModified > 0) {
      // Reconstruct the full text with only the pasted portion modified
      final beforePaste = <String>[];
      for (int i = 0; i < pasteStartLine; i++) {
        beforePaste.add(codeLines[i].text);
      }

      final afterPaste = <String>[];
      for (int i = pasteEndLine + 1; i < lineCount; i++) {
        afterPaste.add(codeLines[i].text);
      }

      final newText = [
        ...beforePaste,
        ...result.lines,
        ...afterPaste,
      ].join('\n');

      if (newText != _contentController.text) {
        // Calculate new cursor position after formatting
        final beforePasteLength =
            beforePaste.join('\n').length + (beforePaste.isNotEmpty ? 1 : 0);
        final formattedPasteLength = result.lines.join('\n').length;
        final newCursorOffset = beforePasteLength + formattedPasteLength;

        final newCursorLine = TextPositionUtils.getLineFromOffset(
          newText,
          newCursorOffset,
        );
        final newCursorCol = TextPositionUtils.getColumnFromOffset(
          newText,
          newCursorOffset,
        );

        // Set value directly (not via `set text`) to bypass runRevocableOp.
        // This makes the reformatting overwrite the paste's undo node
        // so that paste + line-breaking is a single undo entry.
        _contentController.value = CodeLineEditingValue(
          codeLines: newText.codeLines,
          selection: CodeLineSelection.collapsed(
            index: newCursorLine,
            offset: newCursorCol,
          ),
        );
        _previousTextLength = newText.length;

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

  /// Convert a CodeLinePosition to a character offset in the full text
  int _getOffsetFromSelection(CodeLinePosition position) {
    int offset = 0;
    final codeLines = _contentController.codeLines;
    final lineIndex = position.index.clamp(0, codeLines.length - 1);

    // Add length of all lines before the target line
    for (int i = 0; i < lineIndex; i++) {
      offset += codeLines[i].text.length + 1; // +1 for newline
    }

    // Add column offset within the target line
    if (lineIndex < codeLines.length) {
      final lineLength = codeLines[lineIndex].text.length;
      offset += position.offset.clamp(0, lineLength);
    }

    return offset;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OptimizedNoteBloc, OptimizedNoteState>(
          listener: (context, state) {
            if (state is OptimizedNoteCreated) {
              _effectiveNoteId = state.metadata.id;
              _isCreatingNewNote = false;
              _counterBloc.add(SetNoteContext(noteId: _effectiveNoteId));
              ShortcutHandlerFactory.counterHandler.setActiveNoteId(
                _effectiveNoteId,
              );
              _autoSaveService?.startTracking(
                _titleController.text,
                _contentController.text,
                contentProvider: () => _contentController.text,
              );
            } else if (state is OptimizedNoteContentLoaded) {
              final content = state.note.content ?? '';
              setState(() {
                _contentController.text = content;
                _previousTextLength = content.length;
                _cachedPreviewContent = content;
                _cachedLineCount = '\n'.allMatches(content).length + 1;
                _cachedCharCount = content.length;
                _isLoading = false;
              });
              _restoreSavedPosition();
            }
          },
        ),
        BlocListener<MarkdownBarBloc, MarkdownBarState>(
          listener: (context, state) {
            if (state is MarkdownBarLoaded) {
              setState(() {
                _activeBarProfileId = state.activeProfileId;
                _allShortcuts = List.from(state.currentShortcuts);
              });
              ShortcutHandlerFactory.counterHandler.setActiveNoteId(
                _effectiveNoteId ?? widget.noteId,
              );
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            await _saveBeforeExit();
            if (context.mounted) {
              AppNavigator.pop(context);
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
                        child: MarkdownBar(
                          shortcuts: _allShortcuts,
                          isPreviewMode: _isPreviewMode,
                          canUndo: false,
                          canRedo: false,
                          previewFontSize: _previewFontSize,
                          shortcutRatio: _toolbarShortcutRatio,
                          splitEnabled: _toolbarSplitEnabled,
                          utilityConfigs: _utilityConfigs,
                          onUndo: () {},
                          onRedo: () {},
                          onDecreaseFontSize: () {},
                          onIncreaseFontSize: () {},
                          onSettings: () {},
                          onSwitchBar: _showBarSwitcher,
                          onScrollToTop: () => _scrollToEdge(toTop: true),
                          onScrollToBottom: () => _scrollToEdge(toTop: false),
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
                                    offstage: showPreview,
                                    child: IgnorePointer(
                                      ignoring: showPreview,
                                      child: _buildEditor(),
                                    ),
                                  ),
                                  Offstage(
                                    offstage: !showPreview,
                                    child: IgnorePointer(
                                      ignoring: !showPreview,
                                      child: _buildPreview(),
                                    ),
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
                            final noteSize = _contentController.textLength;

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
                                    offstage: showPreview,
                                    child: IgnorePointer(
                                      ignoring: showPreview,
                                      child: _buildEditor(),
                                    ),
                                  ),
                                  Offstage(
                                    offstage: !showPreview,
                                    child: IgnorePointer(
                                      ignoring: !showPreview,
                                      child: _buildPreview(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Always show toolbar — in preview mode it provides
                    // utility actions; in edit mode it appears with keyboard.
                    RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarkdownBar(
                            shortcuts: _allShortcuts,
                            isPreviewMode: _isPreviewMode,
                            canUndo: _historyObserver.canUndo,
                            canRedo: _historyObserver.canRedo,
                            previewFontSize: _isPreviewMode
                                ? _previewFontSize
                                : _editorFontSize,
                            shortcutRatio: _toolbarShortcutRatio,
                            splitEnabled: _toolbarSplitEnabled,
                            utilityConfigs: _utilityConfigs,
                            onUndo: () => _historyObserver.undo(),
                            onRedo: () => _historyObserver.redo(),
                            onPaste: () => _contentController.paste(),
                            onSwitchBar: _showBarSwitcher,
                            onDecreaseFontSize: _decreaseFontSize,
                            onIncreaseFontSize: _increaseFontSize,
                            onSettings: _openMarkdownSettings,
                            onShortcutPressed: _handleShortcut,
                            onReorderComplete: _handleReorderComplete,
                            onUtilityReorderComplete:
                                _handleUtilityReorderComplete,
                            onShare: _showExportFormatDialog,
                            onCounter: _showCounterPicker,
                            onScrollToTop: () => _scrollToEdge(toTop: true),
                            onScrollToBottom: () => _scrollToEdge(toTop: false),
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
        key: _previewController.viewKey,
        data: content,
        fontSize: _previewFontSize,
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          top: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: kToolbarHeight,
        ),
        onCheckboxToggle: _handleCheckboxToggle,
        linesPerChunk: _previewLinesPerChunk,
        onScrollProgress: _previewController.updateProgress,
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
          child: InteractivePreviewScrollbar(controller: _previewController),
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
    context.read<MarkdownBarBloc>().add(
      UpdateShortcuts(
        profileId: _activeBarProfileId,
        shortcuts: reorderedShortcuts,
      ),
    );
  }

  Future<void> _handleUtilityReorderComplete(
    List<UtilityButtonConfig> reorderedUtilities,
  ) async {
    setState(() {
      _utilityConfigs = reorderedUtilities;
    });
    final settings = await SettingsService.getInstance();
    await settings.setToolbarUtilityConfig(reorderedUtilities);
  }

  Future<void> _saveBeforeExit() async {
    _contentFocusNode.unfocus();

    await _saveCurrentPosition();

    if (_effectiveNoteId != null) {
      await _autoSaveService?.forceSave(title: _titleController.text);
    } else if (!_isCreatingNewNote) {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      if (title.isEmpty && content.isEmpty) return;
      _createNewNoteEarly();
    }
  }

  void _showExportFormatDialog() async {
    final format = await AppDialogs.choose<String>(
      context,
      title: AppLocalizations.of(context)!.chooseExportFormat,
      options: [
        (
          value: 'md',
          label: AppLocalizations.of(context)!.exportAsMarkdown,
          icon: Icons.description_rounded,
        ),
        (
          value: 'json',
          label: AppLocalizations.of(context)!.exportAsJson,
          icon: Icons.data_object_rounded,
        ),
        (
          value: 'txt',
          label: AppLocalizations.of(context)!.exportAsText,
          icon: Icons.text_snippet_rounded,
        ),
      ],
    );
    if (format == null) return;
    _shareNote(format);
  }

  Future<void> _shareNote(String format) async {
    AppDialogs.showLoading(
      context,
      message: AppLocalizations.of(context)!.exportingNote,
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
      AppNavigator.pop(context);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!mounted) return;
      AppNavigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.noteExportError}: $e'),
        ),
      );
    }
  }

  void _editTitle() async {
    final newTitle = await AppDialogs.textInput(
      context,
      title: AppLocalizations.of(context)!.editTitle,
      hintText: AppLocalizations.of(context)!.enterNoteTitle,
      initialValue: _titleController.text,
      confirmText: AppLocalizations.of(context)!.save,
    );
    if (newTitle == null) return;
    setState(() {
      _titleController.text = newTitle;
    });
  }

  void _scrollToEdge({required bool toTop}) {
    if (_isPreviewMode) {
      if (toTop) {
        _previewController.scrollToTop();
      } else {
        _previewController.scrollToBottom();
      }
    } else {
      if (toTop) {
        _contentController.selection = CodeLineSelection.collapsed(
          index: 0,
          offset: 0,
        );
      } else {
        final lastIndex = _contentController.codeLines.length - 1;
        final lastLineLength =
            _contentController.codeLines[lastIndex].text.length;
        _contentController.selection = CodeLineSelection.collapsed(
          index: lastIndex,
          offset: lastLineLength,
        );
      }
      _editorScrollController.makeCenterIfInvisible(
        _contentController.selection.extent,
      );
    }
  }

  /// Increments the given counter and returns its post-increment value.
  /// Also refreshes counter state in the BLoC.
  Future<int> _incrementCounter(String counterId) async {
    final bloc = context.read<CounterBloc>();
    final counterState = bloc.state;
    if (counterState is! CounterLoaded) return 0;

    final counter = counterState.counters
        .where((c) => c.id == counterId)
        .firstOrNull;
    if (counter == null) return 0;

    final currentValue =
        counterState.counterValues[counterId] ?? counter.startValue;
    final noteId = _effectiveNoteId ?? widget.noteId;
    bloc.add(IncrementCounter(counterId: counterId, noteId: noteId));
    return currentValue + counter.step;
  }

  Future<void> _showCounterPicker() async {
    final counterState = context.read<CounterBloc>().state;
    if (counterState is! CounterLoaded) return;

    final selected = await AppDialogs.counterPicker(
      context,
      counters: counterState.counters,
      counterValues: counterState.counterValues,
      noteId: _effectiveNoteId,
      onManageCounters: () async {
        await AppNavigator.toCounterManagement(
          context,
          noteId: _effectiveNoteId,
        );
        if (!mounted) return null;
        final bloc = context.read<CounterBloc>();
        bloc.add(RefreshCounters(noteId: _effectiveNoteId));
        final updated = await bloc.stream
            .where((s) => s is CounterLoaded)
            .first
            .timeout(const Duration(seconds: 2), onTimeout: () => bloc.state);
        if (updated is! CounterLoaded) return null;
        return (
          counters: updated.counters,
          counterValues: updated.counterValues,
        );
      },
    );

    if (selected == null || !mounted) return;

    final currentValue = await _incrementCounter(selected.id);
    _contentController.runRevocableOp(() {
      _contentController.replaceSelection(currentValue.toString());
    });
    _onTextChanged();
  }

  void _handleShortcut(CustomMarkdownShortcut shortcut) {
    // Store length before applying the shortcut to calculate inserted range
    final beforeLength = _contentController.textLength;

    // Prevent _handleTextChange from running during runRevocableOp.
    // Without this, replaceSelection fires notifyListeners synchronously
    // which triggers _handleTextChange → _handlePasteLineBreaking inside
    // the revocable op, then we'd call _handlePasteLineBreaking again
    // below — double-formatting with stale offsets.
    _isProcessingTextChange = true;

    // Wrap the entire shortcut operation in an atomic undo entry
    // so that e.g. date insertion + repeat + wrapper text all revert together.
    _contentController.runRevocableOp(() {
      _applyShortcut(shortcut);
    });

    _isProcessingTextChange = false;

    // Sync _previousTextLength so subsequent edits diff correctly
    _previousTextLength = _contentController.textLength;

    _onTextChanged();

    // Format the inserted text if auto-break is enabled
    if (_autoBreakLongLines) {
      final afterLength = _contentController.textLength;
      final textLengthDiff = afterLength - beforeLength;
      if (textLengthDiff > 0) {
        final afterSelection = _contentController.selection;
        final insertEndOffset = _getOffsetFromSelection(afterSelection.extent);
        final insertStartOffset = insertEndOffset - textLengthDiff;

        if (insertStartOffset >= 0 && insertEndOffset <= afterLength) {
          _handlePasteLineBreaking(insertStartOffset, insertEndOffset);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _contentController.makeCursorVisible();
      }
    });
  }

  Future<void> _applyShortcut(CustomMarkdownShortcut shortcut) async {
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
    } else if (shortcut.insertType == 'counter') {
      final counterId = shortcut.counterId;
      if (counterId == null) return;
      final counterState = context.read<CounterBloc>().state;
      if (counterState is! CounterLoaded) return;
      if (!counterState.counters.any((c) => c.id == counterId)) return;
      final currentValue = await _incrementCounter(counterId);
      final valueStr = currentValue.toString();
      final insertText = '${shortcut.beforeText}$valueStr${shortcut.afterText}';
      _contentController.replaceSelection(insertText);
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

  /// Opens the bar switcher bottom sheet and applies the selection.
  Future<void> _showBarSwitcher() async {
    final result = await BarSwitcherSheet.show(
      context,
      currentProfileId: _activeBarProfileId,
      noteId: _effectiveNoteId ?? widget.noteId,
    );
    if (result == null || !mounted) return;

    final noteId = _effectiveNoteId ?? widget.noteId;

    if (result.clearedOverride) {
      if (noteId != null) {
        context.read<MarkdownBarBloc>().add(
          SetNoteBarAssignment(noteId: noteId, profileId: null),
        );
      }
      return;
    }

    if (result.profile != null) {
      final selected = result.profile!;
      if (noteId != null) {
        context.read<MarkdownBarBloc>().add(
          SetNoteBarAssignment(noteId: noteId, profileId: selected.id),
        );
      } else {
        context.read<MarkdownBarBloc>().add(
          SetActiveProfile(profileId: selected.id),
        );
      }
    }
  }

  Future<void> _openMarkdownSettings() async {
    await AppNavigator.toMarkdownSettings(context, allShortcuts: _allShortcuts);

    if (!mounted) return;

    context.read<MarkdownBarBloc>().add(
      ResolveBarForNote(noteId: _effectiveNoteId ?? widget.noteId),
    );
    final settings = await SettingsService.getInstance();
    final ratio = await settings.getToolbarShortcutRatio();
    final splitEnabled = await settings.getToolbarSplitEnabled();
    final utilityConfigs = await settings.getToolbarUtilityConfig();
    if (mounted) {
      setState(() {
        _toolbarShortcutRatio = ratio;
        _toolbarSplitEnabled = splitEnabled;
        _utilityConfigs = utilityConfigs;
      });
    }
  }
}
