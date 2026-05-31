import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/public_holidays.dart';
import '../constants/settings_keys.dart';
import '../l10n/app_localizations.dart';
import '../services/public_holiday_service.dart';
import '../services/settings_service.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/unified_app_bars.dart';

/// Calendar settings page grouping every calendar-specific option
/// (day-bar density, holiday set, …) in one place.
class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({super.key});

  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  SettingsService? _settings;
  bool _isLoading = true;

  int _calendarMaxDayBars = SettingsKeys.defaultCalendarMaxDayBars;
  PublicHolidayService? _holidayService;
  HolidayProfile _holidayProfile = HolidayProfile.generic;
  bool _hapticFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getInstance();
    final calendarMaxDayBars = await settings.getCalendarMaxDayBars();
    final haptic = await settings.getHapticFeedback();
    final holidayService = await PublicHolidayService.getInstance();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _calendarMaxDayBars = calendarMaxDayBars;
      _hapticFeedback = haptic;
      _holidayService = holidayService;
      _holidayProfile = holidayService.profile;
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
      appBar: SettingsAppBar(
        title: l10n.calendarSettings,
        showMenuButton: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionCard(
                  context: context,
                  colorScheme: colorScheme,
                  icon: Icons.calendar_month_rounded,
                  title: l10n.calendarSection,
                  children: [
                    _buildSliderTile(
                      context: context,
                      colorScheme: colorScheme,
                      title: l10n.calendarMaxDayBars,
                      subtitle: l10n.calendarMaxDayBarsDesc(
                        _calendarMaxDayBars,
                      ),
                      value: _calendarMaxDayBars.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      onChanged: (value) async {
                        _onHapticFeedback();
                        setState(() => _calendarMaxDayBars = value.round());
                        await _settings?.setCalendarMaxDayBars(value.round());
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.public_rounded,
                        color: colorScheme.primary,
                      ),
                      title: Text(l10n.holidayProfileTitle),
                      subtitle: Text(
                        PublicHolidays.profileNameOf(_holidayProfile, l10n),
                      ),
                      trailing: DropdownButton<HolidayProfile>(
                        value: _holidayProfile,
                        underline: const SizedBox.shrink(),
                        onChanged: (next) async {
                          if (next == null || next == _holidayProfile) {
                            return;
                          }
                          _onHapticFeedback();
                          // Optimistic UI update — the service mutation is
                          // transactional so a failure leaves the cache in a
                          // consistent state and we can resync from it.
                          setState(() => _holidayProfile = next);
                          try {
                            await _holidayService?.setProfile(next);
                          } catch (e) {
                            if (!context.mounted) return;
                            setState(
                              () => _holidayProfile =
                                  _holidayService?.profile ?? next,
                            );
                            CustomSnackbar.showError(
                              context,
                              'Failed to switch holiday profile: $e',
                            );
                          }
                        },
                        items: [
                          for (final profile in HolidayProfile.values)
                            DropdownMenuItem(
                              value: profile,
                              child: Text(
                                PublicHolidays.profileNameOf(profile, l10n),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
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
            label: '${value.round()}',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.resetToDefaults,
      content: l10n.resetToDefaultsConfirm,
      confirmText: l10n.reset,
      icon: Icons.refresh_rounded,
    );
    if (!confirmed) return;
    await _resetToDefaults();
  }

  Future<void> _resetToDefaults() async {
    await _settings?.setCalendarMaxDayBars(
      SettingsKeys.defaultCalendarMaxDayBars,
    );
    try {
      await _holidayService?.setProfile(HolidayProfile.generic);
    } catch (_) {
      // Keep the previously persisted profile on failure; the dropdown
      // resyncs from the service below.
    }

    if (!mounted) return;
    setState(() {
      _calendarMaxDayBars = SettingsKeys.defaultCalendarMaxDayBars;
      _holidayProfile = _holidayService?.profile ?? HolidayProfile.generic;
    });

    if (!mounted) return;
    CustomSnackbar.showSuccess(
      context,
      AppLocalizations.of(context)!.settingsReset,
    );
  }
}
