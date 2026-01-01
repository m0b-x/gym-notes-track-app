import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../widgets/gradient_app_bar.dart';

/// Database settings page for managing database location and operations
class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  String? _databasePath;
  int? _databaseSizeBytes;
  DateTime? _lastModified;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() => _isLoading = true);

    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'gym_notes', 'gym_notes.db');
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        final stats = await dbFile.stat();
        setState(() {
          _databasePath = dbPath;
          _databaseSizeBytes = stats.size;
          _lastModified = stats.modified;
          _isLoading = false;
        });
      } else {
        setState(() {
          _databasePath = dbPath;
          _databaseSizeBytes = null;
          _lastModified = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _databasePath = 'Error loading path';
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(AppLocalizations.of(context)!.databaseSettings),
        gradientStyle: GradientStyle.drawer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDatabaseInfo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Database location card
                  _buildInfoCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.folder_rounded,
                    title: AppLocalizations.of(context)!.databaseLocation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            _databasePath ?? 'Unknown',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _copyPath(context),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text(
                                  AppLocalizations.of(context)!.copyPath,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _openInFinder(context),
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  AppLocalizations.of(context)!.openInFinder,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Database stats card
                  _buildInfoCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.analytics_rounded,
                    title: AppLocalizations.of(context)!.databaseStats,
                    child: Column(
                      children: [
                        _buildStatRow(
                          context: context,
                          colorScheme: colorScheme,
                          icon: Icons.storage_rounded,
                          label: AppLocalizations.of(context)!.size,
                          value: _databaseSizeBytes != null
                              ? _formatFileSize(_databaseSizeBytes!)
                              : 'N/A',
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context: context,
                          colorScheme: colorScheme,
                          icon: Icons.update_rounded,
                          label: AppLocalizations.of(context)!.lastModified,
                          value: _lastModified != null
                              ? _formatDate(_lastModified!)
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Maintenance card
                  _buildInfoCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.build_rounded,
                    title: AppLocalizations.of(context)!.maintenance,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.maintenanceDesc,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _optimizeDatabase(context),
                            icon: const Icon(Icons.speed_rounded, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.optimizeDatabase,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Share database card
                  _buildInfoCard(
                    context: context,
                    colorScheme: colorScheme,
                    icon: Icons.share_rounded,
                    title: AppLocalizations.of(context)!.shareDatabase,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.shareDatabaseDesc,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _shareDatabase(context),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.shareDatabase,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Danger zone card
                  _buildDangerCard(context, colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required BuildContext context,
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDangerCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.dangerZone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.dangerZoneDesc,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.deleteAllData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyPath(BuildContext context) {
    if (_databasePath != null) {
      Clipboard.setData(ClipboardData(text: _databasePath!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pathCopied),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openInFinder(BuildContext context) async {
    if (_databasePath == null) return;

    final directory = p.dirname(_databasePath!);

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [directory]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [directory]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.notSupportedOnPlatform),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(this.context)!.errorOpeningFolder}: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareDatabase(BuildContext context) async {
    if (_databasePath == null) return;

    final dbFile = File(_databasePath!);
    if (!await dbFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(this.context)!.databaseNotFound),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(AppLocalizations.of(dialogContext)!.preparingShare),
          ],
        ),
      ),
    );

    try {
      final xFile = XFile(_databasePath!);

      if (!mounted) return;
      Navigator.pop(this.context);

      await SharePlus.instance.share(ShareParams(files: [xFile]));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(this.context);

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(this.context)!.shareError}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _optimizeDatabase(BuildContext context) async {
    // Capture size before optimization
    final sizeBefore = _databaseSizeBytes;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(AppLocalizations.of(context)!.optimizing),
          ],
        ),
      ),
    );

    try {
      final db = await AppDatabase.getInstance();
      await db.vacuum();
      await db.rebuildFtsIndex();

      if (!mounted) return;
      Navigator.pop(this.context); // Close loading dialog

      // Refresh stats to get new size
      await _loadDatabaseInfo();

      if (!mounted) return;

      // Calculate size difference
      final sizeAfter = _databaseSizeBytes;
      String message;
      if (sizeBefore != null && sizeAfter != null) {
        final savedBytes = sizeBefore - sizeAfter;
        if (savedBytes > 0) {
          message =
              '${AppLocalizations.of(this.context)!.optimizationComplete} (${_formatFileSize(savedBytes)} ${AppLocalizations.of(this.context)!.saved})';
        } else {
          message =
              '${AppLocalizations.of(this.context)!.optimizationComplete} (${AppLocalizations.of(this.context)!.alreadyOptimized})';
        }
      } else {
        message = AppLocalizations.of(this.context)!.optimizationComplete;
      }

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(this.context);

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(this.context)!.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          size: 48,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(AppLocalizations.of(dialogContext)!.deleteAllData),
        content: Text(AppLocalizations.of(dialogContext)!.deleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _performDatabaseDeletion();
            },
            child: Text(AppLocalizations.of(dialogContext)!.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _performDatabaseDeletion() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(AppLocalizations.of(dialogContext)!.deletingData),
          ],
        ),
      ),
    );

    try {
      await AppDatabase.deleteAllData();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success and exit app (user needs to restart)
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: Colors.green,
          ),
          title: Text(AppLocalizations.of(dialogContext)!.dataDeleted),
          content: Text(AppLocalizations.of(dialogContext)!.restartRequired),
          actions: [
            FilledButton(
              onPressed: () {
                // Exit the app
                SystemNavigator.pop();
              },
              child: Text(AppLocalizations.of(dialogContext)!.exitApp),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.errorDeletingData}: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
