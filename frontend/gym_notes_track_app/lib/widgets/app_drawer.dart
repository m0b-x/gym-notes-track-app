import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_settings/app_settings_bloc.dart';
import '../l10n/app_localizations.dart';
import '../pages/database_settings_page.dart';
import '../pages/controls_settings_page.dart';
import '../pages/markdown_settings_page.dart';
import '../utils/markdown_settings_utils.dart';

/// Global navigation drawer for app-wide settings
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          // Header
          _buildHeader(context, colorScheme),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),

                // Database settings
                _buildMenuItem(
                  context: context,
                  icon: Icons.storage_rounded,
                  title: AppLocalizations.of(context)!.databaseSettings,
                  subtitle: AppLocalizations.of(context)!.databaseSettingsDesc,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DatabaseSettingsPage(),
                      ),
                    );
                  },
                ),

                // Controls settings
                _buildMenuItem(
                  context: context,
                  icon: Icons.touch_app_rounded,
                  title: AppLocalizations.of(context)!.controlsSettings,
                  subtitle: AppLocalizations.of(context)!.controlsSettingsDesc,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ControlsSettingsPage(),
                      ),
                    );
                  },
                ),

                // Markdown shortcuts
                _buildMenuItem(
                  context: context,
                  icon: Icons.text_format_rounded,
                  title: AppLocalizations.of(context)!.markdownShortcuts,
                  subtitle: AppLocalizations.of(context)!.markdownShortcutsDesc,
                  onTap: () async {
                    Navigator.pop(context);
                    final shortcuts =
                        await MarkdownSettingsUtils.loadShortcuts();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MarkdownSettingsPage(allShortcuts: shortcuts),
                        ),
                      );
                    }
                  },
                ),

                const Divider(indent: 16, endIndent: 16),

                // Language settings
                _buildMenuItem(
                  context: context,
                  icon: Icons.language_rounded,
                  title: AppLocalizations.of(context)!.languageSettings,
                  subtitle: AppLocalizations.of(context)!.languageSettingsDesc,
                  onTap: () {
                    Navigator.pop(context);
                    _showLanguageDialog(context);
                  },
                ),

                // Theme settings
                _buildMenuItem(
                  context: context,
                  icon: Icons.palette_rounded,
                  title: AppLocalizations.of(context)!.themeSettings,
                  subtitle: AppLocalizations.of(context)!.themeSettingsDesc,
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeDialog(context);
                  },
                ),

                const Divider(indent: 16, endIndent: 16),

                // About section
                _buildMenuItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: AppLocalizations.of(context)!.about,
                  subtitle: 'Gym Notes v1.0.0',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Footer
          _buildFooter(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.appTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.settings,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.copyright_rounded,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '2025 Gym Notes',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Gym Notes',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.fitness_center_rounded,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'A powerful note-taking app designed for gym enthusiasts to track workouts and progress.',
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsBloc = context.read<AppSettingsBloc>();
    final currentLocale = settingsBloc.state.localeCode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.language_rounded,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(l10n.selectLanguage),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context: dialogContext,
                title: l10n.systemDefault,
                subtitle: null,
                localeCode: null,
                currentLocale: currentLocale,
                settingsBloc: settingsBloc,
              ),
              _buildLanguageOption(
                context: dialogContext,
                title: l10n.english,
                subtitle: 'English',
                localeCode: 'en',
                currentLocale: currentLocale,
                settingsBloc: settingsBloc,
              ),
              _buildLanguageOption(
                context: dialogContext,
                title: l10n.german,
                subtitle: 'Deutsch',
                localeCode: 'de',
                currentLocale: currentLocale,
                settingsBloc: settingsBloc,
              ),
              _buildLanguageOption(
                context: dialogContext,
                title: l10n.romanian,
                subtitle: 'Română',
                localeCode: 'ro',
                currentLocale: currentLocale,
                settingsBloc: settingsBloc,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String title,
    String? subtitle,
    required String? localeCode,
    required String? currentLocale,
    required AppSettingsBloc settingsBloc,
  }) {
    final isSelected = localeCode == currentLocale;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: () {
        settingsBloc.add(ChangeLocale(localeCode));
        Navigator.pop(context);
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsBloc = context.read<AppSettingsBloc>();
    final currentTheme = settingsBloc.state.themeMode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.palette_rounded,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(l10n.selectTheme),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context: dialogContext,
                title: l10n.systemTheme,
                icon: Icons.settings_brightness_rounded,
                themeMode: ThemeMode.system,
                currentTheme: currentTheme,
                settingsBloc: settingsBloc,
              ),
              _buildThemeOption(
                context: dialogContext,
                title: l10n.lightTheme,
                icon: Icons.light_mode_rounded,
                themeMode: ThemeMode.light,
                currentTheme: currentTheme,
                settingsBloc: settingsBloc,
              ),
              _buildThemeOption(
                context: dialogContext,
                title: l10n.darkTheme,
                icon: Icons.dark_mode_rounded,
                themeMode: ThemeMode.dark,
                currentTheme: currentTheme,
                settingsBloc: settingsBloc,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required ThemeMode themeMode,
    required ThemeMode currentTheme,
    required AppSettingsBloc settingsBloc,
  }) {
    final isSelected = themeMode == currentTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: () {
        settingsBloc.add(ChangeThemeMode(themeMode));
        Navigator.pop(context);
      },
    );
  }
}
