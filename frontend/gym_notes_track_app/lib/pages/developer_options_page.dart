import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/dev_options.dart';
import '../services/dev_options_service.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/unified_app_bars.dart';

/// Developer options page for debugging features
class DeveloperOptionsPage extends StatefulWidget {
  const DeveloperOptionsPage({super.key});

  @override
  State<DeveloperOptionsPage> createState() => _DeveloperOptionsPageState();
}

class _DeveloperOptionsPageState extends State<DeveloperOptionsPage> {
  DevOptionsService? _service;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    final service = await DevOptionsService.getInstance();
    if (mounted) {
      setState(() {
        _service = service;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOption() async {
    await _service?.saveOptions();
  }

  void _onHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final devOptions = DevOptions.instance;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.developerOptions),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: devOptions,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Warning banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.developerOptionsWarning,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Visualization / Debug section
                    _buildSectionCard(
                      context: context,
                      colorScheme: colorScheme,
                      icon: Icons.palette_outlined,
                      title: l10n.visualizationDebug,
                      children: [
                        _buildSwitchTile(
                          context: context,
                          title: l10n.colorMarkdownBlocks,
                          subtitle: l10n.colorMarkdownBlocksDesc,
                          value: devOptions.colorMarkdownBlocks,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.colorMarkdownBlocks = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showBlockBoundaries,
                          subtitle: l10n.showBlockBoundariesDesc,
                          value: devOptions.showBlockBoundaries,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showBlockBoundaries = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showWhitespace,
                          subtitle: l10n.showWhitespaceDesc,
                          value: devOptions.showWhitespace,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showWhitespace = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showPreviewLineNumbers,
                          subtitle: l10n.showPreviewLineNumbersDesc,
                          value: devOptions.showPreviewLineNumbers,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showPreviewLineNumbers = value;
                            await _saveOption();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Performance Monitoring section
                    _buildSectionCard(
                      context: context,
                      colorScheme: colorScheme,
                      icon: Icons.speed_outlined,
                      title: l10n.performanceMonitoring,
                      children: [
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showRenderTime,
                          subtitle: l10n.showRenderTimeDesc,
                          value: devOptions.showRenderTime,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showRenderTime = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showFpsCounter,
                          subtitle: l10n.showFpsCounterDesc,
                          value: devOptions.showFpsCounter,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showFpsCounter = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showChunkIndicators,
                          subtitle: l10n.showChunkIndicatorsDesc,
                          value: devOptions.showChunkIndicators,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showChunkIndicators = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showRepaintRainbow,
                          subtitle: l10n.showRepaintRainbowDesc,
                          value: devOptions.showRepaintRainbow,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showRepaintRainbow = value;
                            await _saveOption();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Editor Debug section
                    _buildSectionCard(
                      context: context,
                      colorScheme: colorScheme,
                      icon: Icons.edit_note_outlined,
                      title: l10n.editorDebug,
                      children: [
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showCursorInfo,
                          subtitle: l10n.showCursorInfoDesc,
                          value: devOptions.showCursorInfo,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showCursorInfo = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showSelectionDetails,
                          subtitle: l10n.showSelectionDetailsDesc,
                          value: devOptions.showSelectionDetails,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showSelectionDetails = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.logParserEvents,
                          subtitle: l10n.logParserEventsDesc,
                          value: devOptions.logParserEvents,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.logParserEvents = value;
                            await _saveOption();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Storage / Data section
                    _buildSectionCard(
                      context: context,
                      colorScheme: colorScheme,
                      icon: Icons.storage_outlined,
                      title: l10n.storageData,
                      children: [
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showNoteSize,
                          subtitle: l10n.showNoteSizeDesc,
                          value: devOptions.showNoteSize,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showNoteSize = value;
                            await _saveOption();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          context: context,
                          title: l10n.showDatabaseStats,
                          subtitle: l10n.showDatabaseStatsDesc,
                          value: devOptions.showDatabaseStats,
                          onChanged: (value) async {
                            _onHapticFeedback();
                            devOptions.showDatabaseStats = value;
                            await _saveOption();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Reset button
                    OutlinedButton.icon(
                      onPressed: () async {
                        _onHapticFeedback();
                        await _service?.resetOptions();
                        if (context.mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            l10n.developerOptionsReset,
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.resetToDefaults),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Lock developer mode button
                    FilledButton.icon(
                      onPressed: () async {
                        _onHapticFeedback();
                        devOptions.lockDeveloperMode();
                        await _service?.saveOptions();
                        if (context.mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            l10n.developerModeLocked,
                          );
                          Navigator.pop(context, 'openDrawer');
                        }
                      },
                      icon: const Icon(Icons.lock_rounded),
                      label: Text(l10n.lockDeveloperMode),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                );
              },
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
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
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
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}
