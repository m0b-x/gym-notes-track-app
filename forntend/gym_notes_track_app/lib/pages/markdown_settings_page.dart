import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/custom_snackbar.dart';

// Removed _SettingsConstants class - using AppLocalizations instead

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

  // ========================================
  // Data Persistence
  // ========================================

  Future<void> _saveShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = _shortcuts
        .map((shortcut) => shortcut.toJson())
        .toList();
    await prefs.setString(
      'custom_markdown_shortcuts',
      jsonEncode(shortcutsJson),
    );
  }

  // ========================================
  // CRUD Operations
  // ========================================

  void _addShortcut() {
    showDialog(
      context: context,
      builder: (context) => _ShortcutEditorDialog(
        onSave: (shortcut) {
          setState(() {
            _shortcuts.add(shortcut);
          });
          _saveShortcuts();
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
        onSave: (updatedShortcut) {
          setState(() {
            _shortcuts[index] = updatedShortcut;
          });
          _saveShortcuts();
        },
      ),
    );
  }

  void _toggleVisibility(int index) {
    setState(() {
      _shortcuts[index] = _shortcuts[index].copyWith(
        isVisible: !_shortcuts[index].isVisible,
      );
    });
    _saveShortcuts();
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
            onPressed: () {
              setState(() {
                _shortcuts.removeAt(index);
              });
              _saveShortcuts();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  // ========================================
  // Bulk Operations
  // ========================================

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

  void _resetToDefault() {
    setState(() {
      // Get fresh default shortcuts from the source
      final defaults = _getDefaultShortcuts();
      // Keep custom shortcuts
      final customShortcuts = _shortcuts.where((s) => !s.isDefault).toList();
      // Combine: defaults first, then custom
      _shortcuts = [...defaults, ...customShortcuts];
    });
    _saveShortcuts();
  }

  // Helper method to get default shortcuts
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

  void _removeAllCustom() {
    setState(() {
      _shortcuts = _shortcuts.where((s) => s.isDefault).toList();
    });
    _saveShortcuts();
  }

  // ========================================
  // Helper Methods
  // ========================================

  Widget _buildShortcutIcon(CustomMarkdownShortcut shortcut) {
    // Special rendering for header shortcut
    if (shortcut.id == 'default_header') {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: Text(
          'H',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    // Standard icon rendering
    return Icon(
      IconData(shortcut.iconCodePoint, fontFamily: shortcut.iconFontFamily),
    );
  }

  String _getShortcutSubtitle(CustomMarkdownShortcut shortcut) {
    switch (shortcut.insertType) {
      case 'date':
        return AppLocalizations.of(context)!.insertsCurrentDate;
      case 'header':
        return AppLocalizations.of(context)!.opensHeaderMenu;
      default:
        return AppLocalizations.of(
          context,
        )!.beforeAfterText(shortcut.beforeText, shortcut.afterText);
    }
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
      child: Scaffold(
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
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _shortcuts.removeAt(oldIndex);
                    _shortcuts.insert(newIndex, item);
                  });
                  _saveShortcuts();
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
                            _buildShortcutIcon(shortcut),
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
                          _getShortcutSubtitle(shortcut),
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
  late IconData _selectedIcon;
  late String _insertType;

  final List<IconData> _availableIcons = [
    Icons.tag,
    Icons.star,
    Icons.favorite,
    Icons.lightbulb,
    Icons.warning,
    Icons.info,
    Icons.check_circle,
    Icons.highlight,
    Icons.palette,
    Icons.bookmark,
    Icons.label,
    Icons.flag,
    Icons.push_pin,
    Icons.note,
    Icons.description,
    Icons.article,
    Icons.menu_book,
    Icons.attachment,
    Icons.local_offer,
    Icons.style,
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
    _selectedIcon = widget.shortcut != null
        ? IconData(
            widget.shortcut!.iconCodePoint,
            fontFamily: widget.shortcut!.iconFontFamily,
          )
        : Icons.tag;
    _insertType = widget.shortcut?.insertType ?? 'wrap';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _beforeController.dispose();
    _afterController.dispose();
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
            itemCount: _availableIcons.length,
            itemBuilder: (context, index) {
              final icon = _availableIcons[index];
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
    return AlertDialog(
      title: Text(
        widget.shortcut == null
            ? AppLocalizations.of(context)!.newShortcut
            : AppLocalizations.of(context)!.editShortcut,
      ),
      content: SingleChildScrollView(
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
                    Text(AppLocalizations.of(context)!.tapToChangeIcon),
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
                  child: Text(AppLocalizations.of(context)!.wrapSelectedText),
                ),
                DropdownMenuItem(
                  value: 'date',
                  child: Text(AppLocalizations.of(context)!.insertCurrentDate),
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
                      AppLocalizations.of(context)!.markdownSpaceWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _beforeController,
              decoration: InputDecoration(
                labelText: _insertType == 'date'
                    ? AppLocalizations.of(context)!.beforeDate
                    : AppLocalizations.of(context)!.markdownStart,
                hintText: _insertType == 'date'
                    ? AppLocalizations.of(context)!.optionalTextBeforeDate
                    : AppLocalizations.of(context)!.markdownStartHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _afterController,
              decoration: InputDecoration(
                labelText: _insertType == 'date'
                    ? AppLocalizations.of(context)!.afterDate
                    : AppLocalizations.of(context)!.markdownEnd,
                hintText: _insertType == 'date'
                    ? AppLocalizations.of(context)!.optionalTextAfterDate
                    : AppLocalizations.of(context)!.markdownStartHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _insertType == 'date'
                  ? 'Preview: ${_beforeController.text}${DateFormat('MMMM d, yyyy').format(DateTime.now())}${_afterController.text}'
                  : 'Preview: ${_beforeController.text}text${_afterController.text}',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
