import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../bloc/note/note_bloc.dart';
import '../bloc/note/note_event.dart';
import '../models/note.dart';
import '../models/custom_markdown_shortcut.dart';
import '../utils/text_history_observer.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/interactive_markdown.dart';
import '../config/default_markdown_shortcuts.dart';
import '../config/app_constants.dart';
import 'markdown_settings_page.dart';

class NoteEditorPage extends StatefulWidget {
  final String folderId;
  final Note? note;

  const NoteEditorPage({super.key, required this.folderId, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  bool _hasChanges = false;
  bool _isPreviewMode = false;
  TextHistoryObserver? _textHistory;
  double _previewFontSize = 16.0;
  List<CustomMarkdownShortcut> _allShortcuts = [];
  String _previousText = '';
  bool _isProcessingTextChange = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _previousText = _contentController.text;
    _contentFocusNode = FocusNode();
    _textHistory = TextHistoryObserver(_contentController);

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    _loadCustomShortcuts();
    _loadAutoSavePreference();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = true;
    });
    _resetAutoSaveTimer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _textHistory?.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _handleEnterKey() {
    _handleTextChange();
  }

  void _handleTextChange() {
    if (_isProcessingTextChange) return;

    final text = _contentController.text;
    final selection = _contentController.selection;

    // Only process if a newline was actually added (text got longer and has newline before cursor)
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
    // Check if the line is just a list marker with no content
    // Trim to handle any whitespace
    line = line.trim();

    final emptyPatterns = ['•', '-', '- [ ]', '- [x]', '- [X]'];

    for (var pattern in emptyPatterns) {
      if (line == pattern) return true;
    }

    // Check for numbered list (e.g., "1.", "2.", etc.)
    final numberedPattern = RegExp(r'^\d+\.$');
    return numberedPattern.hasMatch(line);
  }

  String? _getListPrefix(String line) {
    line = line.trimLeft();

    // Point list (•)
    if (line.startsWith('• ')) {
      return '• ';
    }

    // Bullet list (-)
    if (line.startsWith('- ') && !line.startsWith('- [')) {
      return '- ';
    }

    // Checkbox list
    if (line.startsWith('- [ ] ')) {
      return '- [ ] ';
    }
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      return '- [ ] '; // Reset to unchecked for new item
    }

    // Numbered list (1. 2. 3. etc.)
    final numberedMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (numberedMatch != null) {
      final currentNumber = int.parse(numberedMatch.group(1)!);
      return '${currentNumber + 1}. ';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
            child: Text(
              _titleController.text.isEmpty
                  ? AppLocalizations.of(context)!.newNote
                  : _titleController.text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
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
                tooltip: _isPreviewMode
                    ? AppLocalizations.of(context)!.edit
                    : AppLocalizations.of(context)!.preview,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _isPreviewMode
                    ? InteractiveMarkdown(
                        data: _contentController.text.isEmpty
                            ? AppLocalizations.of(context)!.noContentYet
                            : _contentController.text,
                        selectable: true,
                        padding: const EdgeInsets.all(16),
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: _previewFontSize),
                          listBullet: TextStyle(fontSize: _previewFontSize),
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
                          h4: TextStyle(
                            fontSize: _previewFontSize * 1.1,
                            fontWeight: FontWeight.bold,
                          ),
                          h5: TextStyle(
                            fontSize: _previewFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          h6: TextStyle(
                            fontSize: _previewFontSize * 0.9,
                            fontWeight: FontWeight.bold,
                          ),
                          code: TextStyle(fontSize: _previewFontSize * 0.9),
                        ),
                        onCheckboxChanged: (updatedContent) {
                          setState(() {
                            _contentController.text = updatedContent;
                            _hasChanges = true;
                          });
                        },
                      )
                    : TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.startWriting,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(0),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        onSubmitted: (_) => _handleEnterKey(),
                        onChanged: (_) => _handleTextChange(),
                      ),
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
                  _previewFontSize = (_previewFontSize - 2).clamp(10.0, 30.0);
                });
              },
              onIncreaseFontSize: () {
                setState(() {
                  _previewFontSize = (_previewFontSize + 2).clamp(10.0, 30.0);
                });
              },
              onSettings: _openMarkdownSettings,
              onShortcutPressed: _handleShortcut,
              onReorderComplete: _handleReorderComplete,
            ),
          ],
        ),
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
    _autoSaveTimer?.cancel();

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      return;
    }

    if (widget.note == null) {
      context.read<NoteBloc>().add(
        CreateNote(folderId: widget.folderId, title: title, content: content),
      );
    } else {
      context.read<NoteBloc>().add(
        UpdateNote(noteId: widget.note!.id, title: title, content: content),
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
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos < 0) return;

    final boldLabel = '**${shortcut.label}**';
    final newText =
        text.substring(0, cursorPos) +
        boldLabel +
        text.substring(selection.extentOffset);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + boldLabel.length),
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

      // Create maps for efficient lookup
      final Map<String, CustomMarkdownShortcut> loadedMap = {
        for (var s in loaded) s.id: s,
      };

      // Rebuild shortcuts using the new default order
      final mergedShortcuts = <CustomMarkdownShortcut>[];

      // First, add all default shortcuts in the new order, preserving visibility settings
      for (var defaultShortcut in defaults) {
        if (loadedMap.containsKey(defaultShortcut.id)) {
          // Use the loaded version to preserve visibility settings
          mergedShortcuts.add(loadedMap[defaultShortcut.id]!);
        } else {
          // New default shortcut
          mergedShortcuts.add(defaultShortcut);
        }
      }

      // Then add custom shortcuts
      for (var shortcut in loaded) {
        if (!shortcut.isDefault) {
          mergedShortcuts.add(shortcut);
        }
      }

      setState(() {
        _allShortcuts = mergedShortcuts;
      });

      // Save the updated order
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

  Future<void> _loadAutoSavePreference() async {
    _startAutoSaveTimer();
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(AppConstants.autoSaveInterval, (_) {
      if (_hasChanges) {
        _saveNoteQuietly();
      }
    });
  }

  void _resetAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(AppConstants.autoSaveDelay, () {
      if (_hasChanges) {
        _saveNoteQuietly();
      }
    });
  }

  void _saveNoteQuietly() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      return;
    }

    if (widget.note == null) {
      context.read<NoteBloc>().add(
        CreateNote(folderId: widget.folderId, title: title, content: content),
      );
    } else {
      context.read<NoteBloc>().add(
        UpdateNote(noteId: widget.note!.id, title: title, content: content),
      );
    }

    setState(() {
      _hasChanges = false;
    });
  }
}
