import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/markdown_bar/markdown_bar_bloc.dart';
import '../l10n/app_localizations.dart';
import '../models/counter.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_loading_bar.dart';
import '../widgets/counter_form_dialog.dart';
import '../widgets/unified_app_bars.dart';
import '../utils/custom_snackbar.dart';

class CounterManagementPage extends StatelessWidget {
  const CounterManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return LoadingScaffold(
      appBar: SettingsAppBar(
        title: l10n.counterSettings,
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCounterDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<MarkdownBarBloc, MarkdownBarState>(
        builder: (context, state) {
          if (state is! MarkdownBarLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final counters = state.counters;
          final values = state.counterValues;

          if (counters.isEmpty) {
            return _buildEmptyState(context, l10n);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 96, // room for FAB
            ),
            itemCount: counters.length,
            itemBuilder: (context, index) {
              final counter = counters[index];
              final currentValue = values[counter.id] ?? counter.startValue;
              return _CounterCard(
                counter: counter,
                currentValue: currentValue,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pin_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.counterEmptyState,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCounterDialog(BuildContext context) async {
    final result = await showCounterFormDialog(context);
    if (result == null || !context.mounted) return;

    context.read<MarkdownBarBloc>().add(
      AddCounter(
        name: result.name,
        startValue: result.startValue,
        step: result.step,
        scope: result.scope,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter card widget
// ---------------------------------------------------------------------------

class _CounterCard extends StatelessWidget {
  final Counter counter;
  final int currentValue;

  const _CounterCard({
    required this.counter,
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isGlobal = counter.scope == CounterScope.global;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + actions
            Row(
              children: [
                // Scope icon
                Container(
                  padding: const EdgeInsets.all(8),
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
                    size: 20,
                    color: isGlobal
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + scope label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counter.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGlobal
                            ? l10n.counterScopeGlobalDesc
                            : l10n.counterScopePerNoteDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Popup menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) =>
                      _handleAction(context, action),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit_rounded),
                        title: Text(l10n.editCounter),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: ListTile(
                        leading: const Icon(Icons.restart_alt_rounded),
                        title: Text(l10n.resetCounter),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_rounded,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          l10n.deleteCounter,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Value chips row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(
                  label: l10n.counterCurrentValue(currentValue),
                  color: colorScheme.primaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                ),
                _InfoChip(
                  label: l10n.counterStepLabel(counter.step),
                  color: colorScheme.secondaryContainer,
                  textColor: colorScheme.onSecondaryContainer,
                ),
                _InfoChip(
                  label: '${l10n.startValue}: ${counter.startValue}',
                  color: colorScheme.surfaceContainerHighest,
                  textColor: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case 'edit':
        final result = await showCounterFormDialog(
          context,
          existing: counter,
        );
        if (result == null || !context.mounted) return;
        context.read<MarkdownBarBloc>().add(
          UpdateCounter(
            counter: counter.copyWith(
              name: result.name,
              startValue: result.startValue,
              step: result.step,
              scope: result.scope,
            ),
          ),
        );
        break;

      case 'reset':
        final confirmed = await AppDialogs.confirm(
          context,
          title: l10n.resetCounter,
          content: l10n.resetCounterConfirm,
          icon: Icons.restart_alt_rounded,
        );
        if (!confirmed || !context.mounted) return;
        context.read<MarkdownBarBloc>().add(
          ResetCounter(counterId: counter.id),
        );
        if (context.mounted) {
          CustomSnackbar.showSuccess(context, l10n.counterResetSuccess);
        }
        break;

      case 'delete':
        final confirmed = await AppDialogs.confirm(
          context,
          title: l10n.deleteCounter,
          content: l10n.deleteCounterConfirm,
          isDestructive: true,
          icon: Icons.delete_rounded,
        );
        if (!confirmed || !context.mounted) return;
        context.read<MarkdownBarBloc>().add(
          DeleteCounter(counterId: counter.id),
        );
        if (context.mounted) {
          CustomSnackbar.showSuccess(context, l10n.counterDeleteSuccess);
        }
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Info chip
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
