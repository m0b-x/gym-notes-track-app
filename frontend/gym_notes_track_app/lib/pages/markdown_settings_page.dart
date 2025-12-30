import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import '../utils/custom_snackbar.dart';
import '../config/available_icons.dart';
import '../widgets/markdown_toolbar.dart';
import '../utils/markdown_settings_utils.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/app_loading_bar.dart';

class MarkdownSettingsPage extends StatefulWidget {
  final List<CustomMarkdownShortcut> allShortcuts;

  const MarkdownSettingsPage({super.key, required this.allShortcuts});

  @override
  State<MarkdownSettingsPage> createState() => _MarkdownSettingsPageState();
}

class _MarkdownSettingsPageState extends State<MarkdownSettingsPage> {
  late List<CustomMarkdownShortcut> _shortcuts;

  @override
  void initState() {
    super.initState();
    _shortcuts = List.from(widget.allShortcuts);
  }

  Future<void> _saveShortcuts() async {
    try {
      await MarkdownSettingsUtils.saveShortcuts(_shortcuts);
      debugPrint(
        '[MarkdownSettings] Shortcuts saved successfully (${_shortcuts.length} items)',
      );
    } catch (e, stackTrace) {
      debugPrint('[MarkdownSettings] ERROR saving shortcuts: $e');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
    }
  }

  void _addShortcut() {
    showDialog(
      context: context,
      builder: (context) => _ShortcutEditorDialog(
        onSave: (shortcut) async {
          setState(() {
            _shortcuts.add(shortcut);
          });
          await _saveShortcuts();
        },
      ),
    );
  }

  void _editShortcut(int index) {
    final shortcut = _shortcuts[index];

    if (shortcut.isDefault) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ShortcutEditorDialog(
        shortcut: shortcut,
        onSave: (updatedShortcut) async {
          setState(() {
            _shortcuts[index] = updatedShortcut;
          });
          await _saveShortcuts();
        },
      ),
    );
  }

  Future<void> _toggleVisibility(int index) async {
    setState(() {
      _shortcuts[index] = _shortcuts[index].copyWith(
        isVisible: !_shortcuts[index].isVisible,
      );
    });
    await _saveShortcuts();
  }

  void _deleteShortcut(int index) {
    final shortcut = _shortcuts[index];

    if (shortcut.isDefault) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteShortcut),
        content: Text(AppLocalizations.of(context)!.deleteShortcutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              setState(() {
                _shortcuts.removeAt(index);
              });
              await _saveShortcuts();
              navigator.pop();
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetDialogTitle),
        content: Text(AppLocalizations.of(context)!.resetDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              _resetToDefault();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.reset),
          ),
        ],
      ),
    );
  }

  void _showRemoveCustomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeCustomDialogTitle),
        content: Text(AppLocalizations.of(context)!.removeCustomDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              _removeAllCustom();
              Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context)!.remove,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _shortcuts = MarkdownSettingsUtils.resetToDefault(_shortcuts);
    });
    await _saveShortcuts();
  }

  Future<void> _removeAllCustom() async {
    setState(() {
      _shortcuts = MarkdownSettingsUtils.removeAllCustom(_shortcuts);
    });
    await _saveShortcuts();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_shortcuts);
        }
      },
      child: LoadingScaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.markdownShortcuts),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'reset_all') {
                  _showResetDialog();
                } else if (value == 'remove_custom') {
                  _showRemoveCustomDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reset_all',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.resetToDefault),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove_custom',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.removeAllCustom),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _shortcuts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noCustomShortcutsYet,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.tapToAddShortcut,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 110, // Extra space at bottom for FAB
                ),
                itemCount: _shortcuts.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _shortcuts.removeAt(oldIndex);
                    _shortcuts.insert(newIndex, item);
                  });
                  await _saveShortcuts();
                },
                itemBuilder: (context, index) {
                  final shortcut = _shortcuts[index];
                  return Opacity(
                    key: ValueKey(shortcut.id),
                    opacity: shortcut.isVisible ? 1.0 : 0.5,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drag_handle,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 8),
                            MarkdownSettingsUtils.buildShortcutIcon(
                              context,
                              shortcut,
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(shortcut.label),
                            if (shortcut.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.defaultLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          MarkdownSettingsUtils.getShortcutSubtitle(
                            context,
                            shortcut,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                shortcut.isVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => _toggleVisibility(index),
                              tooltip: shortcut.isVisible
                                  ? AppLocalizations.of(context)!.hide
                                  : AppLocalizations.of(context)!.show,
                            ),
                            if (!shortcut.isDefault) ...[
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editShortcut(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteShortcut(index),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addShortcut,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ShortcutEditorDialog extends StatefulWidget {
  final CustomMarkdownShortcut? shortcut;
  final Function(CustomMarkdownShortcut) onSave;

  const _ShortcutEditorDialog({this.shortcut, required this.onSave});

  @override
  State<_ShortcutEditorDialog> createState() => _ShortcutEditorDialogState();
}

class _ShortcutEditorDialogState extends State<_ShortcutEditorDialog> {
  late TextEditingController _labelController;
  late TextEditingController _beforeController;
  late TextEditingController _afterController;
  late FocusNode _beforeFocusNode;
  late FocusNode _afterFocusNode;
  late IconData _selectedIcon;
  late String _insertType;
  static const int _maxChars = 250;
  List<CustomMarkdownShortcut> _shortcuts = [];
  TextEditingController? _activeController;
  FocusNode? _activeFocusNode;
  String _previousBeforeText = '';
  String _previousAfterText = '';
  bool _isProcessingTextChange = false;

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

    // Set up focus listeners to track active field
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
    final cursorPos = selection.baseOffset;

    if (cursorPos < 0) return;

    final boldLabel = '**${shortcut.label}**';
    final newText =
        text.substring(0, cursorPos) +
        boldLabel +
        text.substring(selection.extentOffset);

    _activeController!.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + boldLabel.length),
    );

    _activeFocusNode!.requestFocus();
  }

  void _save() {
    if (_labelController.text.isEmpty) {
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)!.labelCannotBeEmpty,
      );
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
      title: Text(
        widget.shortcut == null
            ? AppLocalizations.of(context)!.newShortcut
            : AppLocalizations.of(context)!.editShortcut,
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
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.label,
                          hintText: AppLocalizations.of(context)!.labelHint,
                          border: OutlineInputBorder(),
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
                            // Clear before/after text when switching to date
                            if (_insertType == 'date') {
                              _beforeController.text = '';
                              _afterController.text = '';
                            }
                          });
                        },
                      ),
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
                              ? '${_beforeController.text}${DateFormat('MMMM d, yyyy').format(DateTime.now())}${_afterController.text}'
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
