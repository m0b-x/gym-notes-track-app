import 'package:flutter/material.dart';

import '../constants/calendar_colors.dart';
import '../constants/calendar_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';

/// Bottom-sheet selector for an event [CalendarEventCategory].
class CategoryPickerSheet extends StatelessWidget {
  final CalendarEventCategory selected;

  const CategoryPickerSheet({super.key, required this.selected});

  static Future<CalendarEventCategory?> show(
    BuildContext context, {
    required CalendarEventCategory selected,
  }) {
    return showModalBottomSheet<CalendarEventCategory>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: CategoryPickerSheet(selected: selected),
      ),
    );
  }

  String _label(AppLocalizations l10n, CalendarEventCategory c) {
    return switch (c) {
      CalendarEventCategory.gym => l10n.eventCategoryGym,
      CalendarEventCategory.cardio => l10n.eventCategoryCardio,
      CalendarEventCategory.rest => l10n.eventCategoryRest,
      CalendarEventCategory.holiday => l10n.eventCategoryHoliday,
      CalendarEventCategory.competition => l10n.eventCategoryCompetition,
      CalendarEventCategory.measurement => l10n.eventCategoryMeasurement,
      CalendarEventCategory.other => l10n.eventCategoryOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            l10n.eventType,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: CalendarEventCategory.values.length,
            itemBuilder: (context, index) {
              final c = CalendarEventCategory.values[index];
              final color = CalendarColors.forCategory(c);
              final isSelected = c == selected;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  foregroundColor: color,
                  child: Icon(CalendarIcons.forCategory(c)),
                ),
                title: Text(_label(l10n, c)),
                trailing: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                selected: isSelected,
                onTap: () => Navigator.of(context).pop(c),
              );
            },
          ),
        ),
      ],
    );
  }
}
