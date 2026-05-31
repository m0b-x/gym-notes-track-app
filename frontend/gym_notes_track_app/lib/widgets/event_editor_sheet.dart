import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../constants/calendar_colors.dart';
import '../constants/calendar_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../models/recurrence_rule.dart';
import '../services/event_time_formatter.dart';
import '../services/recurrence_formatter.dart';
import 'category_picker_sheet.dart';
import 'icon_picker_sheet.dart';

/// Result returned by [EventEditorSheet.show]. `null` means cancelled.
sealed class EventEditorResult {
  const EventEditorResult();
}

class EventEditorSaved extends EventEditorResult {
  final CalendarEvent event;
  const EventEditorSaved(this.event);
}

class EventEditorDeleted extends EventEditorResult {
  final String id;
  const EventEditorDeleted(this.id);
}

/// Top-level repeat mode shown as a segmented control.
enum _RepeatMode { oneTime, recurring }

/// Recurring frequency choices. Maps 1:1 onto a concrete [RecurrenceRule]
/// at save time (Weekly carries the user-selected weekday set).
enum _RecurrenceKind {
  daily,
  weekly,
  monthly,
  yearly,
  workdays,
  weekends,
  holidays,
}

/// Bottom-sheet form for creating or editing a [CalendarEvent].
class EventEditorSheet extends StatefulWidget {
  final CalendarEvent? initialEvent;
  final DateTime defaultDate;

  const EventEditorSheet({
    super.key,
    required this.defaultDate,
    this.initialEvent,
  });

  static Future<EventEditorResult?> show(
    BuildContext context, {
    required DateTime defaultDate,
    CalendarEvent? initialEvent,
  }) {
    return showModalBottomSheet<EventEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: EventEditorSheet(
          defaultDate: defaultDate,
          initialEvent: initialEvent,
        ),
      ),
    );
  }

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  /// Default start-of-day for newly enabled timed events. 9:00 is a
  /// neutral choice that suits a gym-planner; user can edit immediately.
  static const int _defaultStartMinute = 9 * 60;

  /// Default duration the first time a user enables an end time on a new
  /// timed event (60 minutes — a typical session).
  static const int _defaultDurationMinutes = 60;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late CalendarEventCategory _category;
  String? _iconKey;
  late DateTime _date;
  DateTime? _endDate;
  late _RepeatMode _mode;
  late _RecurrenceKind _kind;
  late Set<int> _weekdays;

  /// Time-of-day state. The trio is the editor's working copy of the
  /// model's [EventTime]; it's serialized back into one on save.
  ///
  /// - `_isAllDay = true`  → [_startMinute] / [_durationMinutes] are
  ///   ignored (kept around so toggling back doesn't lose the previous
  ///   pick).
  /// - `_isAllDay = false` → [_startMinute] is the start;
  ///   [_durationMinutes] is null (no end) or positive.
  late bool _isAllDay;
  late int _startMinute;
  int? _durationMinutes;

  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEvent;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _category = initial?.category ?? CalendarEventCategory.gym;
    _iconKey = initial?.iconKey;
    _date = _normalize(initial?.startDate ?? widget.defaultDate);
    _endDate = initial?.endDate == null ? null : _normalize(initial!.endDate!);
    final initialTime = initial?.time;
    _isAllDay = initialTime == null;
    _startMinute = initialTime?.startMinute ?? _defaultStartMinute;
    _durationMinutes = initialTime?.durationMinutes;
    _initRecurrenceFrom(initial?.rule ?? const OneTimeRecurrence());
  }

  void _initRecurrenceFrom(RecurrenceRule rule) {
    // Sensible default weekday set anchored to the event start date.
    _weekdays = {_date.weekday};
    switch (rule) {
      case OneTimeRecurrence():
        _mode = _RepeatMode.oneTime;
        _kind = _RecurrenceKind.daily;
      case DailyRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.daily;
      case WeeklyRecurrence(:final weekdays):
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.weekly;
        _weekdays = weekdays.isEmpty ? {_date.weekday} : Set.of(weekdays);
      case MonthlyRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.monthly;
      case YearlyRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.yearly;
      case WorkdaysRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.workdays;
      case WeekendsRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.weekends;
      case PublicHolidaysOnlyRecurrence():
        _mode = _RepeatMode.recurring;
        _kind = _RecurrenceKind.holidays;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Pure helpers -------------------------------------------------------

  DateTime _normalize(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  RecurrenceRule _buildRule() {
    if (_mode == _RepeatMode.oneTime) return const OneTimeRecurrence();
    return switch (_kind) {
      _RecurrenceKind.daily => const DailyRecurrence(),
      _RecurrenceKind.weekly => WeeklyRecurrence(
        weekdays: Set.unmodifiable(_weekdays),
      ),
      _RecurrenceKind.monthly => const MonthlyRecurrence(),
      _RecurrenceKind.yearly => const YearlyRecurrence(),
      _RecurrenceKind.workdays => const WorkdaysRecurrence(),
      _RecurrenceKind.weekends => const WeekendsRecurrence(),
      _RecurrenceKind.holidays => const PublicHolidaysOnlyRecurrence(),
    };
  }

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    if (_mode == _RepeatMode.recurring &&
        _kind == _RecurrenceKind.weekly &&
        _weekdays.isEmpty) {
      return false;
    }
    return true;
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

  String _kindLabel(AppLocalizations l10n, _RecurrenceKind k) {
    return switch (k) {
      _RecurrenceKind.daily => l10n.recurrenceDaily,
      _RecurrenceKind.weekly => l10n.recurrenceWeekly,
      _RecurrenceKind.monthly => l10n.recurrenceMonthly,
      _RecurrenceKind.yearly => l10n.recurrenceYearly,
      _RecurrenceKind.workdays => l10n.recurrenceWorkdays,
      _RecurrenceKind.weekends => l10n.recurrenceWeekends,
      _RecurrenceKind.holidays => l10n.recurrenceHolidaysOnly,
    };
  }

  // --- Interactions -------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 20),
      lastDate: DateTime(_date.year + 20),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final next = _normalize(picked);
      // Keep the weekday selection in sync when it was implicitly anchored
      // to the previous date (single weekday matching old _date.weekday).
      if (_kind == _RecurrenceKind.weekly &&
          _weekdays.length == 1 &&
          _weekdays.first == _date.weekday) {
        _weekdays = {next.weekday};
      }
      _date = next;
      // If the recurrence end is now before the new start, drop it rather
      // than silently producing an event that never occurs.
      if (_endDate != null && _endDate!.isBefore(next)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initial = _endDate ?? _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_date) ? _date : initial,
      firstDate: _date,
      lastDate: DateTime(_date.year + 20),
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = _normalize(picked));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinute ~/ 60,
        minute: _startMinute % 60,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final newStart = picked.hour * 60 + picked.minute;
      // Preserve the visible duration: if a duration is set, keep the
      // *length* (so "1 hour" stays "1 hour"). This is what every native
      // calendar app does when you drag the start time.
      _startMinute = newStart;
    });
  }

  Future<void> _pickEndTime() async {
    // Initialize the picker on the current end time, or one hour after
    // start if no end is set yet.
    final currentEnd = _durationMinutes == null
        ? null
        : _startMinute + _durationMinutes!;
    final initial = currentEnd ?? (_startMinute + _defaultDurationMinutes);
    final clamped = initial % EventTime.minutesPerDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60),
    );
    if (picked == null || !mounted) return;
    final endMinute = picked.hour * 60 + picked.minute;
    setState(() {
      // If user picks an end ≤ start, treat it as next-day (cross-midnight).
      // This is the only sane interpretation when the picker has no day
      // concept; the model and formatter both handle it.
      var duration = endMinute - _startMinute;
      if (duration <= 0) duration += EventTime.minutesPerDay;
      _durationMinutes = duration;
    });
  }

  void _clearEndTime() {
    setState(() => _durationMinutes = null);
  }

  void _setAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      // Toggling on: keep _startMinute / _durationMinutes around so a
      // mistaken toggle is reversible. Toggling off: nothing to do — the
      // existing values become live again.
    });
  }

  Future<void> _pickIcon() async {
    final picked = await IconPickerSheet.show(
      context,
      tint: CalendarColors.forCategory(_category),
      initialKey: _iconKey,
    );
    if (picked == null || !mounted) return;
    setState(() => _iconKey = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await CategoryPickerSheet.show(context, selected: _category);
    if (picked == null || !mounted) return;
    setState(() => _category = picked);
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      final next = Set<int>.of(_weekdays);
      if (!next.add(weekday)) next.remove(weekday);
      _weekdays = next;
    });
  }

  void _onSave() {
    if (!_canSave) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final effectiveDescription = description.isEmpty ? null : description;
    final base = widget.initialEvent;
    // One-time events ignore endDate — their start date is their end.
    final effectiveEnd = _mode == _RepeatMode.recurring ? _endDate : null;
    final effectiveTime = _isAllDay
        ? null
        : EventTime(
            startMinute: _startMinute,
            durationMinutes: _durationMinutes,
          );
    final event = base == null
        ? CalendarEvent(
            id: const Uuid().v4(),
            title: title,
            category: _category,
            startDate: _date,
            rule: _buildRule(),
            endDate: effectiveEnd,
            time: effectiveTime,
            description: effectiveDescription,
            iconKey: _iconKey,
          )
        : base.copyWith(
            title: title,
            category: _category,
            startDate: _date,
            rule: _buildRule(),
            endDate: effectiveEnd,
            time: effectiveTime,
            description: effectiveDescription,
            iconKey: _iconKey,
            clearEndDate: effectiveEnd == null,
            clearTime: effectiveTime == null,
            clearDescription: effectiveDescription == null,
            clearIconKey: _iconKey == null,
          );
    Navigator.of(context).pop(EventEditorSaved(event));
  }

  Future<void> _onDelete() async {
    final base = widget.initialEvent;
    if (base == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteEvent),
          content: Text(l10n.deleteEventConfirm(base.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(EventEditorDeleted(base.id));
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final localeName = l10n.localeName;
    final categoryColor = CalendarColors.forCategory(_category);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + inline cancel/save so the action surface is part
          // of the sheet rather than detached at the bottom edge.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _isEditing ? l10n.editEvent : l10n.addEvent,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton(
                    onPressed: _canSave ? _onSave : null,
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: !_isEditing,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.eventTitle,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: l10n.eventDescription,
                      hintText: l10n.eventDescriptionHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  _SectionLabel(text: l10n.eventType),
                  _PickerTile(
                    leading: CircleAvatar(
                      backgroundColor: categoryColor.withValues(alpha: 0.18),
                      foregroundColor: categoryColor,
                      child: Icon(CalendarIcons.forCategory(_category)),
                    ),
                    title: _categoryLabel(l10n, _category),
                    subtitle: l10n.pickCategory,
                    onTap: _pickCategory,
                  ),
                  _SectionLabel(text: l10n.iconLabel),
                  _PickerTile(
                    leading: CircleAvatar(
                      backgroundColor: categoryColor.withValues(alpha: 0.18),
                      foregroundColor: categoryColor,
                      child: Icon(
                        CalendarIcons.forKey(_iconKey) ??
                            CalendarIcons.forCategory(_category),
                      ),
                    ),
                    title: _iconKey == null
                        ? l10n.iconDefault
                        : l10n.iconCustom,
                    subtitle: l10n.pickIcon,
                    trailing: _iconKey == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(
                            tooltip: l10n.resetToDefault,
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () => setState(() => _iconKey = null),
                          ),
                    onTap: _pickIcon,
                  ),
                  _SectionLabel(text: l10n.eventDate),
                  _PickerTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.calendar_today_rounded),
                    ),
                    title: DateFormat.yMMMMEEEEd(localeName).format(_date),
                    subtitle: _mode == _RepeatMode.recurring
                        ? l10n.startsOn
                        : null,
                    onTap: _pickDate,
                  ),
                  _SectionLabel(text: l10n.eventTimeSection),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      value: _isAllDay,
                      onChanged: _setAllDay,
                      secondary: const CircleAvatar(
                        child: Icon(Icons.schedule_rounded),
                      ),
                      title: Text(l10n.eventAllDay),
                      subtitle: Text(l10n.eventAllDayHint),
                    ),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(height: 8),
                    _PickerTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.play_arrow_rounded),
                      ),
                      title: EventTimeFormatter.formatMinute(
                        _startMinute,
                        context,
                      ),
                      subtitle: l10n.eventStartTime,
                      onTap: _pickStartTime,
                    ),
                    const SizedBox(height: 8),
                    _PickerTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.stop_rounded),
                      ),
                      title: _durationMinutes == null
                          ? l10n.eventEndTimeNone
                          : EventTimeFormatter.formatMinute(
                              (_startMinute + _durationMinutes!) %
                                  EventTime.minutesPerDay,
                              context,
                            ),
                      subtitle: _durationMinutes == null
                          ? l10n.eventEndTimeHint
                          : (_startMinute + _durationMinutes! >=
                                    EventTime.minutesPerDay
                                ? l10n.eventCrossesMidnight
                                : l10n.eventEndTime),
                      trailing: _durationMinutes == null
                          ? const Icon(Icons.chevron_right_rounded)
                          : IconButton(
                              tooltip: l10n.resetToDefault,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clearEndTime,
                            ),
                      onTap: _pickEndTime,
                    ),
                  ],
                  _SectionLabel(text: l10n.repeatMode),
                  Center(
                    child: SegmentedButton<_RepeatMode>(
                      segments: [
                        ButtonSegment(
                          value: _RepeatMode.oneTime,
                          label: Text(l10n.repeatOnce),
                          icon: const Icon(Icons.looks_one_rounded),
                        ),
                        ButtonSegment(
                          value: _RepeatMode.recurring,
                          label: Text(l10n.repeatRecurring),
                          icon: const Icon(Icons.repeat_rounded),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                  ),
                  if (_mode == _RepeatMode.recurring) ...[
                    _SectionLabel(text: l10n.frequency),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final k in _RecurrenceKind.values)
                          ChoiceChip(
                            label: Text(_kindLabel(l10n, k)),
                            selected: _kind == k,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                      ],
                    ),
                    if (_kind == _RecurrenceKind.weekly) ...[
                      _SectionLabel(text: l10n.weekdays),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var w = 1; w <= 7; w++)
                            FilterChip(
                              label: Text(
                                RecurrenceFormatter.weekdayShort(w, localeName),
                              ),
                              selected: _weekdays.contains(w),
                              onSelected: (_) => _toggleWeekday(w),
                            ),
                        ],
                      ),
                      if (_weekdays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.weeklyDaysHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                    _SectionLabel(text: l10n.eventUntilLabel),
                    _PickerTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.event_busy_rounded),
                      ),
                      title: _endDate == null
                          ? l10n.eventUntilNone
                          : DateFormat.yMMMMEEEEd(localeName).format(_endDate!),
                      subtitle: _endDate == null ? l10n.eventUntilHint : null,
                      trailing: _endDate == null
                          ? const Icon(Icons.chevron_right_rounded)
                          : IconButton(
                              tooltip: l10n.resetToDefault,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() => _endDate = null),
                            ),
                      onTap: _pickEndDate,
                    ),
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _onDelete,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: Text(l10n.delete),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PickerTile({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
