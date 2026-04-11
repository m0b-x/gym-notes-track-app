import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/counter.dart';
import 'counter_form_dialog.dart';

/// A searchable dialog that lists available counters and lets the user
/// pick one to insert its current value into the editor.
///
/// If [onCounterCreated] is provided, a "Create new counter" button is shown.
/// The callback receives the [CounterFormResult] and should return the updated
/// counter list so the dialog can refresh inline.
class CounterPickerDialog extends StatefulWidget {
  final List<Counter> counters;
  final Map<String, int> counterValues;
  final Future<List<Counter>> Function(CounterFormResult)? onCounterCreated;

  const CounterPickerDialog({
    super.key,
    required this.counters,
    required this.counterValues,
    this.onCounterCreated,
  });

  @override
  State<CounterPickerDialog> createState() => _CounterPickerDialogState();
}

class _CounterPickerDialogState extends State<CounterPickerDialog> {
  final _searchController = TextEditingController();
  late List<Counter> _allCounters;
  late List<Counter> _filtered;
  late Map<String, int> _values;

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
    });
  }

  Future<void> _createCounter() async {
    final result = await showCounterFormDialog(context);
    if (result == null || !mounted) return;

    if (widget.onCounterCreated != null) {
      final updated = await widget.onCounterCreated!(result);
      setState(() {
        _allCounters = updated;
        _values = {
          ..._values,
          for (final c in updated)
            if (!_values.containsKey(c.id)) c.id: c.startValue,
        };
        _onSearch(); // re-filter
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.pickCounter),
      contentPadding: const EdgeInsets.only(top: 12, bottom: 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field (shown when enough counters to warrant it)
            if (_allCounters.length > 3)
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
            if (_allCounters.length > 3) const SizedBox(height: 8),

            // Counter list or empty state
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
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
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
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
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final counter = _filtered[index];
                        final currentVal =
                            _values[counter.id] ?? counter.startValue;
                        final isGlobal =
                            counter.scope == CounterScope.global;

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
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
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
            ),
          ],
        ),
      ),
      actions: [
        // Create new counter button
        if (widget.onCounterCreated != null)
          TextButton.icon(
            onPressed: _createCounter,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.createCounterInline),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
