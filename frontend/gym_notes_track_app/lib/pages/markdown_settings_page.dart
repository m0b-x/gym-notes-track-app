import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/settings_keys.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import '../models/utility_button_config.dart';
import '../services/settings_service.dart';
import '../utils/markdown_settings_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_loading_bar.dart';
import '../widgets/markdown_toolbar.dart';
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
  double _toolbarRatio = SettingsKeys.defaultToolbarShortcutRatio;
  bool _toolbarSplitEnabled = SettingsKeys.defaultToolbarSplitEnabled;
  List<UtilityButtonConfig> _utilityConfigs = UtilityButtonConfig.defaults();
  SettingsService? _settingsService;

  @override
  void initState() {
    super.initState();
    _shortcuts = List.from(widget.allShortcuts);
    _loadToolbarSettings();
  }

  Future<SettingsService> _getSettingsService() async {
    return _settingsService ??= await SettingsService.getInstance();
  }

  Future<void> _loadToolbarSettings() async {
    final settings = await _getSettingsService();
    final ratio = await settings.getToolbarShortcutRatio();
    final splitEnabled = await settings.getToolbarSplitEnabled();
    final utilityConfigs = await settings.getToolbarUtilityConfig();
    if (mounted) {
      setState(() {
        _toolbarRatio = ratio;
        _toolbarSplitEnabled = splitEnabled;
        _utilityConfigs = utilityConfigs;
      });
    }
  }

  Future<void> _saveToolbarRatio(double value) async {
    final settings = await _getSettingsService();
    await settings.setToolbarShortcutRatio(value);
  }

  Future<void> _saveToolbarSplitEnabled(bool value) async {
    final settings = await _getSettingsService();
    await settings.setToolbarSplitEnabled(value);
  }

  Future<void> _saveUtilityConfigs() async {
    final settings = await _getSettingsService();
    await settings.setToolbarUtilityConfig(_utilityConfigs);
  }

  void _toggleUtilityVisibility(int index) {
    final config = _utilityConfigs[index];
    // Prevent hiding locked buttons (e.g. settings).
    if (UtilityButtonId.locked.contains(config.id)) return;
    setState(() {
      _utilityConfigs[index] = config.copyWith(isVisible: !config.isVisible);
    });
    _saveUtilityConfigs();
  }

  void _reorderUtility(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _utilityConfigs.removeAt(oldIndex);
      _utilityConfigs.insert(newIndex, item);
    });
    _saveUtilityConfigs();
  }

  /// Returns a user-friendly label for a utility button ID.
  String _utilityLabel(String id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case UtilityButtonId.undo:
        return l10n.undo;
      case UtilityButtonId.redo:
        return l10n.redo;
      case UtilityButtonId.paste:
        return l10n.paste;
      case UtilityButtonId.decreaseFont:
        return l10n.decreaseFontSize;
      case UtilityButtonId.increaseFont:
        return l10n.increaseFontSize;
      case UtilityButtonId.reorder:
        return l10n.reorderShortcuts;
      case UtilityButtonId.share:
        return l10n.shareNote;
      case UtilityButtonId.settings:
        return l10n.settings;
      default:
        return id;
    }
  }

  /// Returns the icon for a utility button ID.
  IconData _utilityIcon(String id) {
    switch (id) {
      case UtilityButtonId.undo:
        return Icons.undo;
      case UtilityButtonId.redo:
        return Icons.redo;
      case UtilityButtonId.paste:
        return Icons.content_paste;
      case UtilityButtonId.decreaseFont:
        return Icons.text_decrease;
      case UtilityButtonId.increaseFont:
        return Icons.text_increase;
      case UtilityButtonId.reorder:
        return Icons.swap_horiz;
      case UtilityButtonId.share:
        return Icons.share;
      case UtilityButtonId.settings:
        return Icons.settings;
      default:
        return Icons.help_outline;
    }
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

  Widget _buildToolbarRatioAdjuster(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final ratio = _toolbarRatio.clamp(
      AppConstants.minToolbarRatio,
      AppConstants.maxToolbarRatio,
    );
    final percentLeft = (ratio * 100).round();
    final percentRight = 100 - percentLeft;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.view_column,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.toolbarLayout,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Split toolbar toggle
              Text(
                l10n.splitToolbar,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: Switch(
                  value: _toolbarSplitEnabled,
                  onChanged: (value) {
                    setState(() {
                      _toolbarSplitEnabled = value;
                    });
                    _saveToolbarSplitEnabled(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Live toolbar preview
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: MarkdownToolbar(
              shortcuts: _shortcuts,
              isPreviewMode: false,
              canUndo: true,
              canRedo: false,
              previewFontSize: 14,
              shortcutRatio: ratio,
              splitEnabled: _toolbarSplitEnabled,
              utilityConfigs: _utilityConfigs,
              showBackground: false,
              showReorder: false,
              showSettings: true,
              onUndo: () {},
              onRedo: () {},
              onDecreaseFontSize: () {},
              onIncreaseFontSize: () {},
              onSettings: () {},
              onShortcutPressed: (_) {},
              onReorderComplete: (_) {},
            ),
          ),
          // Show ratio adjuster only when split mode is enabled
          if (_toolbarSplitEnabled) ...[
            const SizedBox(height: 12),
            // Ratio label
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${l10n.shortcuts} $percentLeft%  ·  ${l10n.utilities} $percentRight%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Slider for ratio adjustment
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.outline.withValues(
                  alpha: 0.2,
                ),
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: ratio,
                min: AppConstants.minToolbarRatio,
                max: AppConstants.maxToolbarRatio,
                onChanged: (value) {
                  setState(() {
                    _toolbarRatio = value;
                  });
                },
                onChangeEnd: (value) {
                  _saveToolbarRatio(value);
                },
              ),
            ),
          ],
          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildUtilityButtonsSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.utilityButtons,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.utilityButtonsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _utilityConfigs.length,
            onReorder: _reorderUtility,
            itemBuilder: (context, index) {
              final config = _utilityConfigs[index];
              final isLocked = UtilityButtonId.locked.contains(config.id);
              return Opacity(
                key: ValueKey(config.id),
                opacity: config.isVisible ? 1.0 : 0.5,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _utilityIcon(config.id),
                          size: 20,
                          color: config.isVisible
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                        ),
                      ],
                    ),
                    title: Text(
                      _utilityLabel(config.id),
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: isLocked
                        ? Icon(
                            Icons.lock,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              config.isVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20,
                            ),
                            onPressed: () => _toggleUtilityVisibility(index),
                            tooltip: config.isVisible ? l10n.hide : l10n.show,
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ],
      ),
    );
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
      body: Column(
        children: [
          _buildToolbarRatioAdjuster(context),
          _buildUtilityButtonsSection(context),
          Expanded(
            child: _shortcuts.isEmpty
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
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.defaultLabel,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addShortcut,
        child: const Icon(Icons.add),
      ),
    );
  }
}
