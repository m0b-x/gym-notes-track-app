import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../database/database_lifecycle.dart';
import '../database/daos/calendar_event_dao.dart';
import '../models/calendar_event.dart';
import '../models/recurrence_rule.dart';

/// Persists custom calendar events via Drift and exposes a synchronous
/// in-memory cache so `CalendarBloc.eventsForDay` stays O(N) over a
/// pre-loaded list without async hops in the table-calendar event loader.
class CalendarEventService {
  static CalendarEventService? _instance;

  late AppDatabase _db;
  late CalendarEventDao _dao;
  List<CalendarEvent> _cache = const [];

  CalendarEventService._();

  static Future<CalendarEventService> getInstance() async {
    if (_instance != null) return _instance!;
    final service = CalendarEventService._();
    service._db = await AppDatabase.getInstance();
    service._dao = service._db.calendarEventDao;
    await service._load();
    _instance = service;
    DatabaseLifecycle.registerResetHandler(reset);
    return service;
  }

  static void reset() {
    _instance = null;
  }

  List<CalendarEvent> get events => _cache;

  Future<void> reload() => _load();

  Future<void> _load() async {
    try {
      final rows = await _dao.getAll();
      _cache = List.unmodifiable(rows.map(_rowToEvent));
    } catch (e) {
      debugPrint('[CalendarEventService] Load error: $e');
      _cache = const [];
    }
  }

  Future<void> upsert(CalendarEvent event) async {
    // Normalize both bounds to date-only UTC so equality and ordering are
    // calendar-day stable across timezones.
    final normalizedEnd = event.endDate == null
        ? event
        : event.copyWith(endDate: _dateOnlyUtc(event.endDate!));
    final normalized = normalizedEnd.copyWith(
      startDate: _dateOnlyUtc(event.startDate),
    );
    final now = DateTime.now();
    await _dao.upsert(_eventToCompanion(normalized, updatedAt: now));
    _cache = List.unmodifiable([
      for (final e in _cache)
        if (e.id != normalized.id) e,
      normalized,
    ]);
  }

  Future<void> deleteById(String id) async {
    await _dao.deleteById(id);
    _cache = List.unmodifiable(_cache.where((e) => e.id != id));
  }

  // ── Backup export / import ────────────────────────────────────────────

  /// Snapshot of every event row for inclusion in a full-app backup.
  /// Each entry mirrors the on-disk row shape so the import path can
  /// round-trip without re-deriving any value.
  Future<List<Map<String, dynamic>>> exportData() async {
    final rows = await _dao.getAll();
    return [
      for (final row in rows)
        {
          'id': row.id,
          'title': row.title,
          'category': row.category,
          'startDateMs': row.startDate.millisecondsSinceEpoch,
          'allDay': row.allDay,
          'iconKey': row.iconKey,
          'ruleKind': row.ruleKind,
          'rulePayload': row.rulePayload,
          'endDateMs': row.endDate?.millisecondsSinceEpoch,
          'startMinute': row.startMinute,
          'durationMinutes': row.durationMinutes,
          'description': row.description,
          'createdAtMs': row.createdAt.millisecondsSinceEpoch,
          'updatedAtMs': row.updatedAt.millisecondsSinceEpoch,
        },
    ];
  }

  /// Replaces every persisted event with the contents of [data] (the list
  /// produced by [exportData]). Tolerates missing/malformed entries: bad
  /// rows are skipped, the rest still imports.
  Future<void> importData(List<dynamic> data) async {
    await _dao.deleteAll();
    for (final raw in data) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      try {
        final id = map['id'] as String?;
        final title = map['title'] as String?;
        final category = map['category'] as String?;
        final startMs = map['startDateMs'];
        final ruleKind = map['ruleKind'] as String?;
        if (id == null ||
            title == null ||
            category == null ||
            startMs is! int ||
            ruleKind == null) {
          continue;
        }
        final createdMs = map['createdAtMs'] is int
            ? map['createdAtMs'] as int
            : startMs;
        final updatedMs = map['updatedAtMs'] is int
            ? map['updatedAtMs'] as int
            : createdMs;
        final endMs = map['endDateMs'];
        await _dao.upsert(
          CalendarEventsCompanion(
            id: Value(id),
            title: Value(title),
            category: Value(category),
            startDate: Value(
              DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
            ),
            allDay: Value(map['allDay'] as bool? ?? true),
            iconKey: Value(map['iconKey'] as String?),
            ruleKind: Value(ruleKind),
            rulePayload: Value(map['rulePayload'] as String?),
            endDate: endMs is int
                ? Value(DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true))
                : const Value.absent(),
            startMinute: map['startMinute'] is int
                ? Value(map['startMinute'] as int)
                : const Value.absent(),
            durationMinutes: map['durationMinutes'] is int
                ? Value(map['durationMinutes'] as int)
                : const Value.absent(),
            description: map['description'] is String
                ? Value(map['description'] as String)
                : const Value.absent(),
            createdAt: Value(
              DateTime.fromMillisecondsSinceEpoch(createdMs, isUtc: true),
            ),
            updatedAt: Value(
              DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true),
            ),
          ),
        );
      } catch (e) {
        debugPrint('[CalendarEventService] Import row error: $e');
      }
    }
    await _load();
  }

  // ── Row ↔ Domain mapping ──────────────────────────────────────────────

  CalendarEvent _rowToEvent(CalendarEventRow row) {
    return CalendarEvent(
      id: row.id,
      title: row.title,
      category: _categoryFromName(row.category),
      startDate: _dateOnlyUtc(row.startDate),
      allDay: row.allDay,
      iconKey: row.iconKey,
      endDate: row.endDate == null ? null : _dateOnlyUtc(row.endDate!),
      description: row.description,
      rule: _decodeRule(row.ruleKind, row.rulePayload),
    );
  }

  /// Drift returns `DateTime` in local time when reading an int-epoch
  /// column, so naive `.year/.month/.day` extraction after we wrote
  /// `DateTime.utc(...)` can shift the date by one day in non-UTC zones.
  /// Recover the original UTC date via the epoch milliseconds.
  static DateTime _dateOnlyUtc(DateTime value) {
    final asUtc = DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    );
    return DateTime.utc(asUtc.year, asUtc.month, asUtc.day);
  }

  CalendarEventsCompanion _eventToCompanion(
    CalendarEvent event, {
    required DateTime updatedAt,
  }) {
    return CalendarEventsCompanion(
      id: Value(event.id),
      title: Value(event.title),
      category: Value(event.category.name),
      startDate: Value(event.startDate),
      allDay: Value(event.allDay),
      iconKey: Value(event.iconKey),
      ruleKind: Value(_ruleKind(event.rule)),
      rulePayload: Value(_rulePayload(event.rule)),
      endDate: Value(event.endDate),
      description: Value(event.description),
      // start_minute / duration_minutes are reserved for future
      // time-of-day events; application code never writes them yet.
      createdAt: Value(updatedAt),
      updatedAt: Value(updatedAt),
    );
  }

  CalendarEventCategory _categoryFromName(String name) {
    for (final value in CalendarEventCategory.values) {
      if (value.name == name) return value;
    }
    return CalendarEventCategory.other;
  }

  // ── Recurrence serialization ──────────────────────────────────────────

  static const String _kOneTime = 'oneTime';
  static const String _kDaily = 'daily';
  static const String _kWeekly = 'weekly';
  static const String _kMonthly = 'monthly';
  static const String _kYearly = 'yearly';
  static const String _kWorkdays = 'workdays';
  static const String _kWeekends = 'weekends';
  static const String _kHolidaysOnly = 'holidaysOnly';

  String _ruleKind(RecurrenceRule rule) {
    return switch (rule) {
      OneTimeRecurrence() => _kOneTime,
      DailyRecurrence() => _kDaily,
      WeeklyRecurrence() => _kWeekly,
      MonthlyRecurrence() => _kMonthly,
      YearlyRecurrence() => _kYearly,
      WorkdaysRecurrence() => _kWorkdays,
      WeekendsRecurrence() => _kWeekends,
      PublicHolidaysOnlyRecurrence() => _kHolidaysOnly,
    };
  }

  String? _rulePayload(RecurrenceRule rule) {
    if (rule is WeeklyRecurrence) {
      final days = rule.weekdays.toList()..sort();
      return jsonEncode({'weekdays': days});
    }
    return null;
  }

  RecurrenceRule _decodeRule(String kind, String? payload) {
    switch (kind) {
      case _kDaily:
        return const DailyRecurrence();
      case _kWeekly:
        final days = <int>{};
        if (payload != null && payload.isNotEmpty) {
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map && decoded['weekdays'] is List) {
              for (final raw in decoded['weekdays'] as List) {
                if (raw is int && raw >= 1 && raw <= 7) days.add(raw);
              }
            }
          } catch (e) {
            debugPrint('[CalendarEventService] Bad weekly payload: $e');
          }
        }
        return WeeklyRecurrence(weekdays: days);
      case _kMonthly:
        return const MonthlyRecurrence();
      case _kYearly:
        return const YearlyRecurrence();
      case _kWorkdays:
        return const WorkdaysRecurrence();
      case _kWeekends:
        return const WeekendsRecurrence();
      case _kHolidaysOnly:
        return const PublicHolidaysOnlyRecurrence();
      case _kOneTime:
      default:
        return const OneTimeRecurrence();
    }
  }
}
