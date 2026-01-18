import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/unified_app_bars.dart';

/// Controls settings page for managing gestures and interactions
class ControlsSettingsPage extends StatefulWidget {
  const ControlsSettingsPage({super.key});

  @override
  State<ControlsSettingsPage> createState() => _ControlsSettingsPageState();
}

class _ControlsSettingsPageState extends State<ControlsSettingsPage> {
  SettingsService? _settings;
  bool _isLoading = true;

  // Settings values
  bool _folderSwipeEnabled = true;
  bool _noteSwipeEnabled = true;
  bool _confirmDelete = true;
  bool _autoSaveEnabled = true;
  int _autoSaveInterval = 5;
  bool _showNotePreview = true;
  bool _showStatsBar = true;
  bool _hapticFeedback = true;
  // Editor settings
  bool _showLineNumbers = false;
  bool _wordWrap = true;
  bool _showCursorLine = false;
  bool _autoBreakLongLines = true;
  bool _previewWhenKeyboardHidden = false;

  // Preview settings
  bool _showPreviewScrollbar = false;

  // Preview performance settings
  int _previewLinesPerChunk = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getInstance();
    final folderSwipe = await settings.getFolderSwipeEnabled();
    final noteSwipe = await settings.getNoteSwipeEnabled();
    final confirmDel = await settings.getConfirmDelete();
    final autoSave = await settings.getAutoSaveEnabled();
    final autoSaveInt = await settings.getAutoSaveInterval();
    final showPreview = await settings.getShowNotePreview();
    final showStats = await settings.getShowStatsBar();
    final haptic = await settings.getHapticFeedback();
    final showLineNumbers = await settings.getShowLineNumbers();
    final wordWrap = await settings.getWordWrap();
    final showCursorLine = await settings.getShowCursorLine();
    final autoBreakLongLines = await settings.getAutoBreakLongLines();
    final previewWhenKeyboardHidden = await settings.getPreviewWhenKeyboardHidden();
    final showPreviewScrollbar = await settings.getShowPreviewScrollbar();
    final previewLinesPerChunk = await settings.getPreviewLinesPerChunk();

    setState(() {
      _settings = settings;
      _folderSwipeEnabled = folderSwipe;
      _noteSwipeEnabled = noteSwipe;
      _confirmDelete = confirmDel;
      _autoSaveEnabled = autoSave;
      _autoSaveInterval = autoSaveInt;
      _showNotePreview = showPreview;
      _showStatsBar = showStats;
      _hapticFeedback = haptic;
      _showLineNumbers = showLineNumbers;
      _wordWrap = wordWrap;
      _showCursorLine = showCursorLine;
      _autoBreakLongLines = autoBreakLongLines;
      _previewWhenKeyboardHidden = previewWhenKeyboardHidden;
      _showPreviewScrollbar = showPreviewScrollbar;
      _previewLinesPerChunk = previewLinesPerChunk;
      _isLoading = false;
    });
  }

  void _onHapticFeedback() {
    if (_hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: SettingsAppBar(title: l10n.controlsSettings),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Gestures section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.swipe_rounded,
                    title: l10n.gesturesSection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.folderSwipeGesture,
                        subtitle: l10n.folderSwipeGestureDesc,
                        value: _folderSwipeEnabled,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _folderSwipeEnabled = value);
                          await _settings?.setFolderSwipeEnabled(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.noteSwipeGesture,
                        subtitle: l10n.noteSwipeGestureDesc,
                        value: _noteSwipeEnabled,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _noteSwipeEnabled = value);
                          await _settings?.setNoteSwipeEnabled(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Feedback section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.vibration_rounded,
                    title: l10n.feedbackSection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.hapticFeedback,
                        subtitle: l10n.hapticFeedbackDesc,
                        value: _hapticFeedback,
                        onChanged: (value) async {
                          if (value) HapticFeedback.lightImpact();
                          setState(() => _hapticFeedback = value);
                          await _settings?.setHapticFeedback(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.confirmDelete,
                        subtitle: l10n.confirmDeleteDesc,
                        value: _confirmDelete,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _confirmDelete = value);
                          await _settings?.setConfirmDelete(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Auto-save section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.save_rounded,
                    title: l10n.autoSaveSection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.autoSave,
                        subtitle: l10n.autoSaveDesc,
                        value: _autoSaveEnabled,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _autoSaveEnabled = value);
                          await _settings?.setAutoSaveEnabled(value);
                        },
                      ),
                      if (_autoSaveEnabled) ...[
                        const Divider(height: 1),
                        _buildSliderTile(
                          context: context,
                          colorScheme: colorScheme,
                          title: l10n.autoSaveInterval,
                          subtitle: l10n.autoSaveIntervalDesc(
                            _autoSaveInterval,
                          ),
                          value: _autoSaveInterval.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            setState(() => _autoSaveInterval = value.round());
                            await _settings?.setAutoSaveInterval(value.round());
                          },
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Display section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.visibility_rounded,
                    title: l10n.displaySection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.showNotePreview,
                        subtitle: l10n.showNotePreviewDesc,
                        value: _showNotePreview,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _showNotePreview = value);
                          await _settings?.setShowNotePreview(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.showStatsBar,
                        subtitle: l10n.showStatsBarDesc,
                        value: _showStatsBar,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _showStatsBar = value);
                          await _settings?.setShowStatsBar(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Editor section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.code_rounded,
                    title: l10n.editorSection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.showLineNumbers,
                        subtitle: l10n.showLineNumbersDesc,
                        value: _showLineNumbers,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _showLineNumbers = value);
                          await _settings?.setShowLineNumbers(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.wordWrap,
                        subtitle: l10n.wordWrapDesc,
                        value: _wordWrap,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _wordWrap = value);
                          await _settings?.setWordWrap(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.showCursorLine,
                        subtitle: l10n.showCursorLineDesc,
                        value: _showCursorLine,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _showCursorLine = value);
                          await _settings?.setShowCursorLine(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.autoBreakLongLines,
                        subtitle: l10n.autoBreakLongLinesDesc,
                        value: _autoBreakLongLines,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _autoBreakLongLines = value);
                          await _settings?.setAutoBreakLongLines(value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context: context,
                        title: l10n.previewWhenKeyboardHidden,
                        subtitle: l10n.previewWhenKeyboardHiddenDesc,
                        value: _previewWhenKeyboardHidden,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _previewWhenKeyboardHidden = value);
                          await _settings?.setPreviewWhenKeyboardHidden(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Preview section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.visibility_rounded,
                    title: l10n.previewSection,
                    children: [
                      _buildSwitchTile(
                        context: context,
                        title: l10n.showPreviewScrollbar,
                        subtitle: l10n.showPreviewScrollbarDesc,
                        value: _showPreviewScrollbar,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _showPreviewScrollbar = value);
                          await _settings?.setShowPreviewScrollbar(value);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Preview Performance section
                  _buildSectionCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.speed_rounded,
                    title: l10n.previewPerformanceSection,
                    children: [
                      _buildSliderTile(
                        context: context,
                        colorScheme: colorScheme,
                        title: l10n.previewLinesPerChunk,
                        subtitle: l10n.previewLinesPerChunkDesc(
                          _previewLinesPerChunk,
                        ),
                        value: _previewLinesPerChunk.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        onChanged: (value) async {
                          _onHapticFeedback();
                          setState(() => _previewLinesPerChunk = value.round());
                          await _settings?.setPreviewLinesPerChunk(
                            value.round(),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Reset button
                  Center(
                    child: TextButton.icon(
                      onPressed: _showResetConfirmation,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.resetToDefaults),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()}s',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.refresh_rounded,
          size: 48,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: Text(l10n.resetToDefaults),
        content: Text(l10n.resetToDefaultsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _resetToDefaults();
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    await _settings?.setFolderSwipeEnabled(true);
    await _settings?.setNoteSwipeEnabled(true);
    await _settings?.setConfirmDelete(true);
    await _settings?.setAutoSaveEnabled(true);
    await _settings?.setAutoSaveInterval(5);
    await _settings?.setShowNotePreview(true);
    await _settings?.setShowStatsBar(true);
    await _settings?.setHapticFeedback(true);
    await _settings?.setShowLineNumbers(false);
    await _settings?.setWordWrap(true);
    await _settings?.setShowCursorLine(false);
    await _settings?.setAutoBreakLongLines(true);
    await _settings?.setPreviewWhenKeyboardHidden(false);

    setState(() {
      _folderSwipeEnabled = true;
      _noteSwipeEnabled = true;
      _confirmDelete = true;
      _autoSaveEnabled = true;
      _autoSaveInterval = 5;
      _showNotePreview = true;
      _showStatsBar = true;
      _hapticFeedback = true;
      _showLineNumbers = false;
      _wordWrap = true;
      _showCursorLine = false;
      _autoBreakLongLines = true;
      _previewWhenKeyboardHidden = false;
    });

    if (!mounted) return;
    CustomSnackbar.showSuccess(
      context,
      AppLocalizations.of(context)!.settingsReset,
    );
  }
}
