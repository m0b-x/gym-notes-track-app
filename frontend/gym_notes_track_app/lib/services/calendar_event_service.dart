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
    final normalized = event.copyWith(startDate: _dateOnlyUtc(event.startDate));
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

  // ── Row ↔ Domain mapping ──────────────────────────────────────────────

  CalendarEvent _rowToEvent(CalendarEventRow row) {
    return CalendarEvent(
      id: row.id,
      title: row.title,
      category: _categoryFromName(row.category),
      startDate: _dateOnlyUtc(row.startDate),
      allDay: row.allDay,
      iconKey: row.iconKey,
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
