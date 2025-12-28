import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/note_metadata.dart';
import '../services/auto_save_service.dart';
import '../utils/text_history_observer.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/efficient_markdown.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/virtual_scrolling_editor.dart';
import '../config/default_markdown_shortcuts.dart';
import '../constants/app_constants.dart';
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

  bool _hasChanges = false;
  bool _isPreviewMode = false;
  bool _isLoading = true;
  bool _useVirtualScrolling = false;

  TextHistoryObserver? _textHistory;
  AutoSaveService? _autoSaveService;

  double _previewFontSize = 16.0;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  String _previousText = '';
  bool _isProcessingTextChange = false;

  static const int _virtualScrollingThreshold = 5000;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.metadata?.title ?? '',
    );
    _contentController = TextEditingController();
    _previousText = '';
    _contentFocusNode = FocusNode();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    if (widget.noteId != null) {
      _loadNoteContent();
    } else {
      _isLoading = false;
      _setupTextHistory();
    }

    _loadCustomShortcuts();
    _initializeAutoSave();

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
    setState(() {
      _hasChanges = true;
    });

    _updateVirtualScrollingMode();

    if (widget.noteId != null) {
      _autoSaveService?.onContentChanged(
        widget.noteId!,
        _titleController.text,
        _contentController.text,
      );
    }
  }

  void _updateVirtualScrollingMode() {
    final shouldUseVirtualScrolling =
        _contentController.text.length > _virtualScrollingThreshold;

    if (shouldUseVirtualScrolling != _useVirtualScrolling) {
      setState(() {
        _useVirtualScrolling = shouldUseVirtualScrolling;
      });
    }
  }

  @override
  void dispose() {
    _autoSaveService?.stopTracking(widget.noteId ?? '');
    _autoSaveService?.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _textHistory?.dispose();
    super.dispose();
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
          setState(() {
            _contentController.text = state.note.content ?? '';
            _previousText = _contentController.text;
            _isLoading = false;
            _updateVirtualScrollingMode();
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
          appBar: AppBar(
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
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              if (_useVirtualScrolling)
                Tooltip(
                  message: AppLocalizations.of(context)!.virtualScrollEnabled,
                  child: Icon(
                    Icons.speed,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              Tooltip(
                message: _isPreviewMode
                    ? AppLocalizations.of(context)!.switchToEditMode
                    : AppLocalizations.of(context)!.previewMarkdown,
                waitDuration: AppConstants.debounceDelay,
                child: IconButton(
                  icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _isPreviewMode = !_isPreviewMode;
                      if (!_isPreviewMode) {
                        Future.delayed(AppConstants.shortDelay, () {
                          _contentFocusNode.requestFocus();
                        });
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          body: _isLoading
              ? Column(
                  children: [
                    if (widget.metadata != null) _buildNoteStats(context),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    if (_allShortcuts.isNotEmpty)
                      MarkdownToolbar(
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
                  ],
                )
              : Column(
                  children: [
                    if (widget.metadata != null) _buildNoteStats(context),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _isPreviewMode
                            ? _buildPreview()
                            : _buildEditor(),
                      ),
                    ),
                    MarkdownToolbar(
                      shortcuts: _allShortcuts,
                      isPreviewMode: _isPreviewMode,
                      canUndo: _textHistory?.canUndo ?? false,
                      canRedo: _textHistory?.canRedo ?? false,
                      previewFontSize: _previewFontSize,
                      onUndo: () => _textHistory?.undo(),
                      onRedo: () => _textHistory?.redo(),
                      onDecreaseFontSize: () {
                        setState(() {
                          _previewFontSize = (_previewFontSize - 2).clamp(
                            10.0,
                            30.0,
                          );
                        });
                      },
                      onIncreaseFontSize: () {
                        setState(() {
                          _previewFontSize = (_previewFontSize + 2).clamp(
                            10.0,
                            30.0,
                          );
                        });
                      },
                      onSettings: _openMarkdownSettings,
                      onShortcutPressed: _handleShortcut,
                      onReorderComplete: _handleReorderComplete,
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
            AppLocalizations.of(
              context,
            )!.lineCount(_contentController.text.split('\n').length),
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

    if (_useVirtualScrolling) {
      return EfficientMarkdownView(
        data: content,
        selectable: true,
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
      );
    }

    return InteractiveMarkdown(
      data: content,
      selectable: true,
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
    );
  }

  Widget _buildEditor() {
    if (_useVirtualScrolling) {
      return VirtualScrollingEditor(
        initialContent: _contentController.text,
        focusNode: _contentFocusNode,
        hintText: AppLocalizations.of(context)!.startWriting,
        textStyle: const TextStyle(fontSize: 16, height: 1.5),
        onChanged: (value) {
          _contentController.text = value;
          _handleTextChange();
        },
      );
    }

    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.startWriting,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(0),
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontSize: 16, height: 1.5),
      onChanged: (_) => _handleTextChange(),
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
    final content = _contentController.text.trim();

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
  }

  Future<void> _loadCustomShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = prefs.getString(
      AppConstants.markdownShortcutsStorageKey,
    );

    final defaults = DefaultMarkdownShortcuts.shortcuts;

    if (shortcutsJson != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsJson);
      final loaded = decoded
          .map((json) => CustomMarkdownShortcut.fromJson(json))
          .toList();

      final Map<String, CustomMarkdownShortcut> loadedMap = {
        for (var s in loaded) s.id: s,
      };

      final mergedShortcuts = <CustomMarkdownShortcut>[];

      for (var defaultShortcut in defaults) {
        if (loadedMap.containsKey(defaultShortcut.id)) {
          mergedShortcuts.add(loadedMap[defaultShortcut.id]!);
        } else {
          mergedShortcuts.add(defaultShortcut);
        }
      }

      for (var shortcut in loaded) {
        if (!shortcut.isDefault) {
          mergedShortcuts.add(shortcut);
        }
      }

      setState(() {
        _allShortcuts = mergedShortcuts;
      });

      await _saveShortcutsOrder();
    } else {
      setState(() {
        _allShortcuts = defaults;
      });
    }
  }

  Future<void> _saveShortcutsOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = _allShortcuts
        .map((shortcut) => shortcut.toJson())
        .toList();
    await prefs.setString(
      AppConstants.markdownShortcutsStorageKey,
      jsonEncode(shortcutsJson),
    );
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

      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = result
          .map((shortcut) => shortcut.toJson())
          .toList();
      await prefs.setString(
        AppConstants.markdownShortcutsStorageKey,
        jsonEncode(shortcutsJson),
      );
    }
  }
}
