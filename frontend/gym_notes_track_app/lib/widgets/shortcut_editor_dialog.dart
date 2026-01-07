import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import '../config/available_icons.dart';
import '../widgets/markdown_toolbar.dart';
import '../utils/markdown_settings_utils.dart';
import '../widgets/interactive_markdown.dart';
import '../constants/settings_keys.dart';

class ShortcutEditorDialog extends StatefulWidget {
  final CustomMarkdownShortcut? shortcut;
  final Function(CustomMarkdownShortcut) onSave;

  const ShortcutEditorDialog({super.key, this.shortcut, required this.onSave});

  @override
  State<ShortcutEditorDialog> createState() => _ShortcutEditorDialogState();
}

class _ShortcutEditorDialogState extends State<ShortcutEditorDialog> {
  late TextEditingController _labelController;
  late TextEditingController _beforeController;
  late TextEditingController _afterController;
  late FocusNode _beforeFocusNode;
  late FocusNode _afterFocusNode;
  late IconData _selectedIcon;
  late String _insertType;
  late String _selectedDateFormat;
  static const int _maxChars = 250;
  List<CustomMarkdownShortcut> _shortcuts = [];
  TextEditingController? _activeController;
  FocusNode? _activeFocusNode;
  String _previousBeforeText = '';
  String _previousAfterText = '';
  bool _isProcessingTextChange = false;
  String? _labelError;

  static const List<String> _dateFormats = [
    'MMMM d, yyyy',
    'MMM d, yyyy',
    'd MMMM yyyy',
    'd MMM yyyy',
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd.MM.yyyy',
    'EEEE, MMMM d, yyyy',
    'EEE, MMM d, yyyy',
    'd/M/yy',
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.shortcut?.label ?? '',
    );
    _beforeController = TextEditingController(
      text: widget.shortcut?.beforeText ?? '',
    );
    _afterController = TextEditingController(
      text: widget.shortcut?.afterText ?? '',
    );
    _previousBeforeText = _beforeController.text;
    _previousAfterText = _afterController.text;
    _beforeController.addListener(
      () => _handleTextChange(_beforeController, true),
    );
    _beforeController.addListener(() => setState(() {}));
    _afterController.addListener(
      () => _handleTextChange(_afterController, false),
    );
    _afterController.addListener(() => setState(() {}));
    _beforeFocusNode = FocusNode();
    _afterFocusNode = FocusNode();

    _beforeFocusNode.addListener(() {
      setState(() {
        if (_beforeFocusNode.hasFocus) {
          _activeController = _beforeController;
          _activeFocusNode = _beforeFocusNode;
        }
      });
    });
    _afterFocusNode.addListener(() {
      setState(() {
        if (_afterFocusNode.hasFocus) {
          _activeController = _afterController;
          _activeFocusNode = _afterFocusNode;
        }
      });
    });

    _selectedIcon = widget.shortcut != null
        ? IconData(
            widget.shortcut!.iconCodePoint,
            fontFamily: widget.shortcut!.iconFontFamily,
          )
        : Icons.tag;
    _insertType = widget.shortcut?.insertType ?? 'wrap';
    _selectedDateFormat =
        widget.shortcut?.dateFormat ?? SettingsKeys.defaultDateFormat;
    _loadShortcuts();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _beforeController.dispose();
    _afterController.dispose();
    _beforeFocusNode.dispose();
    _afterFocusNode.dispose();
    super.dispose();
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectIcon),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: AvailableIcons.all.length,
            itemBuilder: (context, index) {
              final icon = AvailableIcons.all[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIcon = icon;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedIcon == icon
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 32),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadShortcuts() async {
    final loaded = await MarkdownSettingsUtils.loadShortcuts();
    setState(() {
      _shortcuts = loaded;
    });
  }

  void _handleTextChange(TextEditingController controller, bool isBefore) {
    if (_isProcessingTextChange) return;

    final text = controller.text;
    final selection = controller.selection;
    final previousText = isBefore ? _previousBeforeText : _previousAfterText;

    final textLengthIncreased = text.length > previousText.length;
    if (isBefore) {
      _previousBeforeText = text;
    } else {
      _previousAfterText = text;
    }

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
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
        if (isBefore) {
          _previousBeforeText = newText;
        } else {
          _previousAfterText = newText;
        }
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

          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newOffset),
          );
          if (isBefore) {
            _previousBeforeText = newText;
          } else {
            _previousAfterText = newText;
          }
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

    if (line.startsWith('• ')) {
      return '• ';
    }

    if (line.startsWith('- ') && !line.startsWith('- [')) {
      return '- ';
    }

    if (line.startsWith('- [ ] ')) {
      return '- [ ] ';
    }
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      return '- [ ] ';
    }

    final numberedMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (numberedMatch != null) {
      final currentNumber = int.parse(numberedMatch.group(1)!);
      return '${currentNumber + 1}. ';
    }

    return null;
  }

  void _handleShortcut(CustomMarkdownShortcut shortcut) {
    if (_activeController == null || _activeFocusNode == null) return;

    final text = _activeController!.text;
    final selection = _activeController!.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) return;

    String newText = text;
    int newCursor = end;

    if (shortcut.insertType == 'date') {
      final now = DateTime.now();
      final formatted = DateFormat(
        shortcut.dateFormat ?? 'yyyy-MM-dd',
      ).format(now);
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

    _activeController!.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _activeFocusNode!.requestFocus();
  }

  void _save() {
    if (_labelController.text.isEmpty) {
      setState(() {
        _labelError = AppLocalizations.of(context)!.labelCannotBeEmpty;
      });
      return;
    }

    final shortcut = CustomMarkdownShortcut(
      id: widget.shortcut?.id ?? const Uuid().v4(),
      label: _labelController.text,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily ?? 'MaterialIcons',
      beforeText: _beforeController.text,
      afterText: _afterController.text,
      insertType: _insertType,
      dateFormat: _insertType == 'date' ? _selectedDateFormat : null,
    );

    widget.onSave(shortcut);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool showToolbar =
        _beforeFocusNode.hasFocus || _afterFocusNode.hasFocus;

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.shortcut == null
              ? AppLocalizations.of(context)!.newShortcut
              : AppLocalizations.of(context)!.editShortcut,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _beforeFocusNode.unfocus();
                  _afterFocusNode.unfocus();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.icon),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showIconPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(_selectedIcon, size: 32),
                              const SizedBox(width: 16),
                              Text(
                                AppLocalizations.of(context)!.tapToChangeIcon,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _labelController,
                        onChanged: (_) {
                          if (_labelError != null) {
                            setState(() => _labelError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.label,
                          hintText: AppLocalizations.of(context)!.labelHint,
                          border: OutlineInputBorder(),
                          errorText: _labelError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.insertType),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _insertType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'wrap',
                            child: Text(
                              AppLocalizations.of(context)!.wrapSelectedText,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'date',
                            child: Text(
                              AppLocalizations.of(context)!.insertCurrentDate,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _insertType = value ?? 'wrap';
                            if (_insertType == 'date') {
                              _beforeController.text = '';
                              _afterController.text = '';
                            }
                          });
                        },
                      ),
                      if (_insertType == 'date') ...[
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.dateFormatSettings),
                        const SizedBox(height: 8),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _dateFormats.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            itemBuilder: (context, index) {
                              final format = _dateFormats[index];
                              final isSelected = format == _selectedDateFormat;
                              final formattedDate = DateFormat(
                                format,
                              ).format(DateTime.now());
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                selected: isSelected,
                                selectedTileColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                leading: Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  size: 20,
                                ),
                                title: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  format,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDateFormat = format);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.markdownSpaceWarning,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _beforeController,
                        focusNode: _beforeFocusNode,
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLength: _maxChars,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        decoration: InputDecoration(
                          labelText: _insertType == 'date'
                              ? AppLocalizations.of(context)!.beforeDate
                              : AppLocalizations.of(context)!.markdownStart,
                          hintText: _insertType == 'date'
                              ? AppLocalizations.of(
                                  context,
                                )!.optionalTextBeforeDate
                              : AppLocalizations.of(context)!.markdownStartHint,
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!.charactersCount(
                            _beforeController.text.length,
                            _maxChars,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _afterController,
                        focusNode: _afterFocusNode,
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLength: _maxChars,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        decoration: InputDecoration(
                          labelText: _insertType == 'date'
                              ? AppLocalizations.of(context)!.afterDate
                              : AppLocalizations.of(context)!.markdownEnd,
                          hintText: _insertType == 'date'
                              ? AppLocalizations.of(
                                  context,
                                )!.optionalTextAfterDate
                              : AppLocalizations.of(context)!.markdownStartHint,
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!.charactersCount(
                            _afterController.text.length,
                            _maxChars,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.preview,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: InteractiveMarkdown(
                          data: _insertType == 'date'
                              ? '${_beforeController.text}${DateFormat(_selectedDateFormat).format(DateTime.now())}${_afterController.text}'
                              : '${_beforeController.text}text${_afterController.text}',
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 14),
                            h1: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showToolbar && _shortcuts.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: MarkdownToolbar(
                  shortcuts: _shortcuts.where((s) => s.isVisible).toList(),
                  isPreviewMode: false,
                  canUndo: false,
                  canRedo: false,
                  previewFontSize: 16,
                  onUndo: () {},
                  onRedo: () {},
                  onDecreaseFontSize: () {},
                  onIncreaseFontSize: () {},
                  onSettings: () {},
                  onShortcutPressed: _handleShortcut,
                  showSettings: false,
                  showBackground: false,
                  showReorder: false,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }
}
