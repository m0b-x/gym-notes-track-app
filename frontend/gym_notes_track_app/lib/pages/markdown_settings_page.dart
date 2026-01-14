import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import '../utils/markdown_settings_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_loading_bar.dart';
import '../widgets/unified_app_bars.dart';
import '../widgets/shortcut_editor_dialog.dart';

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
      builder: (context) => ShortcutEditorDialog(
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
      builder: (context) => ShortcutEditorDialog(
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
    return LoadingScaffold(
        drawer: const AppDrawer(),
        appBar: SettingsAppBar(
          title: AppLocalizations.of(context)!.markdownShortcuts,
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
    );
  }
}
