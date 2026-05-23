import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants/calendar_colors.dart';
import '../constants/calendar_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';

/// Result returned by [CalendarFilterSheet] when the user applies a change.
class CalendarFilterResult {
  final CalendarFormat format;
  final Set<CalendarEventCategory> visibleCategories;

  const CalendarFilterResult({
    required this.format,
    required this.visibleCategories,
  });
}

/// Bottom-sheet that lets the user pick the calendar view range (month /
/// two weeks / week) and choose which event categories should appear.
class CalendarFilterSheet extends StatefulWidget {
  final CalendarFormat initialFormat;
  final Set<CalendarEventCategory> initialCategories;

  const CalendarFilterSheet({
    super.key,
    required this.initialFormat,
    required this.initialCategories,
  });

  static Future<CalendarFilterResult?> show(
    BuildContext context, {
    required CalendarFormat format,
    required Set<CalendarEventCategory> categories,
  }) {
    return showModalBottomSheet<CalendarFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: CalendarFilterSheet(
          initialFormat: format,
          initialCategories: categories,
        ),
      ),
    );
  }

  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  late CalendarFormat _format;
  late Set<CalendarEventCategory> _categories;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
    _categories = {...widget.initialCategories};
  }

  String _categoryLabel(AppLocalizations l10n, CalendarEventCategory c) {
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

  String _formatLabel(AppLocalizations l10n, CalendarFormat f) {
    return switch (f) {
      CalendarFormat.month => l10n.calendarFormatMonth,
      CalendarFormat.twoWeeks => l10n.calendarFormatTwoWeeks,
      CalendarFormat.week => l10n.calendarFormatWeek,
    };
  }

  void _toggleCategory(CalendarEventCategory c, bool selected) {
    setState(() {
      if (selected) {
        _categories.add(c);
      } else {
        _categories.remove(c);
      }
    });
  }

  void _selectAll() {
    setState(() => _categories = CalendarEventCategory.values.toSet());
  }

  void _clearAll() {
    setState(() => _categories = <CalendarEventCategory>{});
  }

  void _apply() {
    Navigator.of(context).pop(
      CalendarFilterResult(
        format: _format,
        visibleCategories: Set.unmodifiable(_categories),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allSelected =
        _categories.length == CalendarEventCategory.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            l10n.calendarFiltersTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              _SectionLabel(text: l10n.calendarViewRange),
              const SizedBox(height: 8),
              SegmentedButton<CalendarFormat>(
                segments: [
                  for (final f in CalendarFormat.values)
                    ButtonSegment<CalendarFormat>(
                      value: f,
                      label: Text(_formatLabel(l10n, f)),
                    ),
                ],
                selected: {_format},
                showSelectedIcon: false,
                onSelectionChanged: (sel) {
                  setState(() => _format = sel.first);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SectionLabel(text: l10n.calendarEventCategories),
                  ),
                  TextButton(
                    onPressed: allSelected ? _clearAll : _selectAll,
                    child: Text(
                      allSelected
                          ? l10n.calendarClearAll
                          : l10n.calendarSelectAll,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CalendarEventCategory.values)
                    FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: CalendarColors.forCategory(
                          c,
                        ).withValues(alpha: 0.18),
                        foregroundColor: CalendarColors.forCategory(c),
                        child: Icon(CalendarIcons.forCategory(c), size: 16),
                      ),
                      label: Text(_categoryLabel(l10n, c)),
                      selected: _categories.contains(c),
                      onSelected: (sel) => _toggleCategory(c, sel),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _apply, child: Text(l10n.apply)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
