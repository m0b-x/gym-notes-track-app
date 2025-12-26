import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../bloc/note/note_bloc.dart';
import '../bloc/note/note_event.dart';
import '../models/note.dart';
import '../models/custom_markdown_shortcut.dart';
import '../utils/text_history_observer.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/markdown_toolbar.dart';
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
  bool _autoSaveEnabled = false;
  Timer? _autoSaveTimer;

  static List<CustomMarkdownShortcut> _getDefaultShortcuts() {
    return [
      const CustomMarkdownShortcut(
        id: 'default_bold',
        label: 'Bold',
        iconCodePoint: 0xe238, // format_bold
        iconFontFamily: 'MaterialIcons',
        beforeText: '**',
        afterText: '**',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_italic',
        label: 'Italic',
        iconCodePoint: 0xe23f, // format_italic
        iconFontFamily: 'MaterialIcons',
        beforeText: '_',
        afterText: '_',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_header',
        label: 'Headers',
        iconCodePoint: 0xe86f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '# ',
        afterText: '',
        isDefault: true,
        insertType: 'header',
      ),
      const CustomMarkdownShortcut(
        id: 'default_point_list',
        label: 'Point List',
        iconCodePoint: 0xe065, // fiber_manual_record (bullet point)
        iconFontFamily: 'MaterialIcons',
        beforeText: '• ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_strikethrough',
        label: 'Strikethrough',
        iconCodePoint: 0xe257, // format_strikethrough
        iconFontFamily: 'MaterialIcons',
        beforeText: '~~',
        afterText: '~~',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_bullet_list',
        label: 'Bullet List',
        iconCodePoint: 0xe241, // format_list_bulleted
        iconFontFamily: 'MaterialIcons',
        beforeText: '- ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_numbered_list',
        label: 'Numbered List',
        iconCodePoint: 0xe242, // format_list_numbered
        iconFontFamily: 'MaterialIcons',
        beforeText: '1. ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_checkbox',
        label: 'Checkbox',
        iconCodePoint: 0xe834, // check_box_outline_blank
        iconFontFamily: 'MaterialIcons',
        beforeText: '- [ ] ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_quote',
        label: 'Quote',
        iconCodePoint: 0xe244, // format_quote
        iconFontFamily: 'MaterialIcons',
        beforeText: '> ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_inline_code',
        label: 'Inline Code',
        iconCodePoint: 0xe86f, // code
        iconFontFamily: 'MaterialIcons',
        beforeText: '`',
        afterText: '`',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_code_block',
        label: 'Code Block',
        iconCodePoint: 0xe86f, // code
        iconFontFamily: 'MaterialIcons',
        beforeText: '```\n',
        afterText: '\n```',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_link',
        label: 'Link',
        iconCodePoint: 0xe157, // link
        iconFontFamily: 'MaterialIcons',
        beforeText: '[',
        afterText: '](url)',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_date',
        label: 'Current Date',
        iconCodePoint: 0xe916, // calendar_today
        iconFontFamily: 'MaterialIcons',
        beforeText: '',
        afterText: '',
        isDefault: true,
        insertType: 'date',
      ),
    ];
  }

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

    if (_autoSaveEnabled) {
      _resetAutoSaveTimer();
    }
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
    return Scaffold(
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
            waitDuration: const Duration(milliseconds: 500),
            child: IconButton(
              icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
              onPressed: () {
                setState(() {
                  _isPreviewMode = !_isPreviewMode;
                  if (!_isPreviewMode) {
                    Future.delayed(const Duration(milliseconds: 100), () {
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
          Tooltip(
            message: _autoSaveEnabled
                ? AppLocalizations.of(context)!.autoSaveOn
                : AppLocalizations.of(context)!.enableAutoSave,
            waitDuration: const Duration(milliseconds: 500),
            child: IconButton(
              icon: Icon(
                _autoSaveEnabled ? Icons.sync : Icons.sync_disabled,
                color: _autoSaveEnabled ? Colors.green : null,
              ),
              onPressed: _toggleAutoSave,
              tooltip: _autoSaveEnabled
                  ? AppLocalizations.of(context)!.autoSaveOn
                  : AppLocalizations.of(context)!.autoSaveOff,
            ),
          ),
          Tooltip(
            message: AppLocalizations.of(context)!.saveNote,
            waitDuration: const Duration(milliseconds: 500),
            child: IconButton(
              icon: const Icon(Icons.save),
              onPressed: _hasChanges || _autoSaveEnabled ? _saveNote : null,
              tooltip: AppLocalizations.of(context)!.save,
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
                  ? Markdown(
                      data: _contentController.text.isEmpty
                          ? AppLocalizations.of(context)!.noContentYet
                          : _contentController.text
                                .split('\n')
                                .map((line) => line.isEmpty ? '&nbsp;' : line)
                                .join('  \n'),
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
    );
  }

  Future<void> _handleReorderComplete(int draggedIndex, int targetIndex) async {
    setState(() {
      final item = _allShortcuts.removeAt(draggedIndex);
      _allShortcuts.insert(targetIndex, item);
    });
    await _saveShortcutsOrder();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)!.noteCannotBeEmpty,
      );
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

    CustomSnackbar.show(context, AppLocalizations.of(context)!.noteSaved);

    Navigator.pop(context);
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

  void _showHeaderMenu() {
    // Get the position of the text field to position the menu
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        16, // Left padding from screen edge
        size.height - 300, // Position above the toolbar
        200,
        size.height,
      ),
      items: [
        PopupMenuItem(
          value: 'h1',
          child: Text(
            AppLocalizations.of(context)!.header1,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: 'h2',
          child: Text(
            AppLocalizations.of(context)!.header2,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: 'h3',
          child: Text(
            AppLocalizations.of(context)!.header3,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: 'h4',
          child: Text(
            AppLocalizations.of(context)!.header4,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: 'h5',
          child: Text(
            AppLocalizations.of(context)!.header5,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: 'h6',
          child: Text(
            AppLocalizations.of(context)!.header6,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'h1':
            _insertMarkdown('# ', '');
            break;
          case 'h2':
            _insertMarkdown('## ', '');
            break;
          case 'h3':
            _insertMarkdown('### ', '');
            break;
          case 'h4':
            _insertMarkdown('#### ', '');
            break;
          case 'h5':
            _insertMarkdown('##### ', '');
            break;
          case 'h6':
            _insertMarkdown('###### ', '');
            break;
        }
      }
    });
  }

  void _insertMarkdown(String before, String after) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    String selectedText = '';
    if (start >= 0 && end >= 0 && start != end) {
      selectedText = text.substring(start, end);
    }

    final newText =
        text.substring(0, start) +
        before +
        selectedText +
        after +
        text.substring(end);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + before.length + selectedText.length,
      ),
    );

    _contentFocusNode.requestFocus();
    _onTextChanged();
  }

  void _handleShortcut(CustomMarkdownShortcut shortcut) {
    if (shortcut.insertType == 'date') {
      _insertCurrentDate(shortcut);
    } else if (shortcut.insertType == 'header') {
      _showHeaderMenu();
    } else {
      _insertMarkdown(shortcut.beforeText, shortcut.afterText);
    }
  }

  void _insertCurrentDate(CustomMarkdownShortcut shortcut) {
    final currentDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.start;

    // Insert before text + date + after text
    final insertText = shortcut.beforeText + currentDate + shortcut.afterText;
    final newText =
        text.substring(0, cursorPos) + insertText + text.substring(cursorPos);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + insertText.length),
    );

    _contentFocusNode.requestFocus();
    _onTextChanged();
  }

  Future<void> _loadCustomShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = prefs.getString('custom_markdown_shortcuts');

    final defaults = _getDefaultShortcuts();

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
      'custom_markdown_shortcuts',
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
        'custom_markdown_shortcuts',
        jsonEncode(shortcutsJson),
      );
    }
  }

  Future<void> _loadAutoSavePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSaveEnabled = prefs.getBool('auto_save_enabled') ?? false;
    });

    if (_autoSaveEnabled) {
      _startAutoSaveTimer();
    }
  }

  Future<void> _toggleAutoSave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSaveEnabled = !_autoSaveEnabled;
    });

    await prefs.setBool('auto_save_enabled', _autoSaveEnabled);

    if (!mounted) return;

    if (_autoSaveEnabled) {
      _startAutoSaveTimer();
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)!.autoSaveEnabled,
      );
    } else {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = null;
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)!.autoSaveDisabled,
      );
    }
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasChanges) {
        _saveNoteQuietly();
      }
    });
  }

  void _resetAutoSaveTimer() {
    if (_autoSaveEnabled) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 5), () {
        if (_hasChanges) {
          _saveNoteQuietly();
        }
      });
    }
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
