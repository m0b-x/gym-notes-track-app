import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/counter.dart';

/// Items shown per page in the counter picker.
const _kPageSize = 5;

/// Debounce duration for page arrow buttons.
const _kArrowDebounce = Duration(milliseconds: 200);

/// A searchable, paginated dialog that lists available counters and lets the
/// user pick one to insert its current value into the editor.
///
/// If [onManageCounters] is provided, a "Manage counters" button is shown
/// that navigates to the counter settings page. The callback must push the
/// page and return fresh counter data so the dialog can refresh in-place.
class CounterPickerDialog extends StatefulWidget {
  final List<Counter> counters;
  final Map<String, int> counterValues;
  final Future<({List<Counter> counters, Map<String, int> counterValues})?>
  Function()?
  onManageCounters;

  const CounterPickerDialog({
    super.key,
    required this.counters,
    required this.counterValues,
    this.onManageCounters,
  });

  @override
  State<CounterPickerDialog> createState() => _CounterPickerDialogState();
}

class _CounterPickerDialogState extends State<CounterPickerDialog> {
  final _searchController = TextEditingController();
  late List<Counter> _allCounters;
  late List<Counter> _filtered;
  late Map<String, int> _values;
  int _page = 0;
  Timer? _arrowDebounce;

  int get _totalPages => (_filtered.length / _kPageSize).ceil().clamp(1, 999);

  List<Counter> get _pageItems {
    final start = _page * _kPageSize;
    final end = (start + _kPageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _allCounters = List.of(widget.counters);
    _values = Map.of(widget.counterValues);
    _filtered = _allCounters;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _arrowDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allCounters;
      } else {
        _filtered = _allCounters
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();
      }
      _page = 0; // reset to first page on every query change
    });
  }

  void _goToPage(int page) {
    // Debounce rapid taps on the arrow buttons.
    if (_arrowDebounce?.isActive ?? false) return;
    _arrowDebounce = Timer(_kArrowDebounce, () {});
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final showPagination = _filtered.length > _kPageSize;

    return AlertDialog(
      title: Text(l10n.pickCounter),
      contentPadding: const EdgeInsets.only(top: 12, bottom: 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchCounters,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Counter list or empty state
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _allCounters.isEmpty
                                ? Icons.pin_rounded
                                : Icons.search_off_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _allCounters.isEmpty
                                ? l10n.noCountersYet
                                : l10n.noCountersMatchSearch,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _pageItems.length,
                      itemBuilder: (context, index) {
                        final counter = _pageItems[index];
                        final currentVal =
                            _values[counter.id] ?? counter.startValue;
                        final isGlobal = counter.scope == CounterScope.global;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isGlobal
                                  ? colorScheme.primaryContainer
                                  : colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isGlobal
                                  ? Icons.public_rounded
                                  : Icons.note_alt_rounded,
                              size: 18,
                              color: isGlobal
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onTertiaryContainer,
                            ),
                          ),
                          title: Text(
                            counter.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${l10n.counterCurrentValue(currentVal)} · ${l10n.counterStepLabel(counter.step)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$currentVal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, counter),
                        );
                      },
                    ),
            ),

            // Pagination controls
            if (showPagination)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
                      visualDensity: VisualDensity.compact,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousPageTooltip,
                    ),
                    Text(
                      l10n.counterPickerPage(_page + 1, _totalPages),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      onPressed: _page < _totalPages - 1
                          ? () => _goToPage(_page + 1)
                          : null,
                      visualDensity: VisualDensity.compact,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).nextPageTooltip,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Manage counters button
        if (widget.onManageCounters != null)
          TextButton.icon(
            onPressed: () async {
              final result = await widget.onManageCounters!();
              if (result == null || !mounted) return;
              setState(() {
                _allCounters = List.of(result.counters);
                _values = Map.of(result.counterValues);
                _page = 0;
                final query = _searchController.text.toLowerCase();
                _filtered = query.isEmpty
                    ? _allCounters
                    : _allCounters
                          .where((c) => c.name.toLowerCase().contains(query))
                          .toList();
              });
            },
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: Text(l10n.manageCounters),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
