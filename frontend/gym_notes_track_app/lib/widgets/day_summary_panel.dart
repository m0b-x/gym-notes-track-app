import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../models/day_summary_entry.dart';

/// Renders the calendar's bottom panel: a list of [DaySummaryEntry] cards
/// (events, weekend, public holiday, etc.). Shows an empty-state when the
/// resolver returns no entries at all.
class DaySummaryPanel extends StatelessWidget {
  final List<DaySummaryEntry> entries;

  /// Called when the user taps an entry that carries a [CalendarEvent].
  /// Non-event entries (weekend, holiday) are non-interactive.
  final ValueChanged<CalendarEvent>? onEventTap;

  const DaySummaryPanel({super.key, required this.entries, this.onEventTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.calendarNoEventsForDay,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final event = entry.event;
        return Card(
          child: ListTile(
            leading: Icon(entry.icon, color: entry.color),
            title: Text(entry.title),
            subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
            trailing: event == null
                ? null
                : const Icon(Icons.chevron_right_rounded),
            onTap: event == null || onEventTap == null
                ? null
                : () => onEventTap!(event),
          ),
        );
      },
    );
  }
}
