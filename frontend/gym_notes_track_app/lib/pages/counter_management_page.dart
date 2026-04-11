import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/counter/counter_bloc.dart';
import '../l10n/app_localizations.dart';
import '../models/counter.dart';
import '../models/note_metadata.dart';
import '../services/counter_service.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_loading_bar.dart';
import '../widgets/counter_form_dialog.dart';
import '../widgets/note_picker_dialog.dart';
import '../widgets/unified_app_bars.dart';
import '../utils/custom_snackbar.dart';

class CounterManagementPage extends StatelessWidget {
  final String? noteId;

  const CounterManagementPage({super.key, this.noteId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return LoadingScaffold(
      appBar: SettingsAppBar(title: l10n.counterSettings),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCounterDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<CounterBloc, CounterState>(
        builder: (context, state) {
          if (state is CounterError) {
            return _buildErrorState(context, l10n);
          }
          if (state is! CounterLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final counters = state.counters;
          final values = state.counterValues;

          if (counters.isEmpty) {
            return _buildEmptyState(context, l10n);
          }

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 96, // room for FAB
            ),
            itemCount: counters.length,
            onReorder: (oldIndex, newIndex) {
              context.read<CounterBloc>().add(
                ReorderCounters(oldIndex: oldIndex, newIndex: newIndex),
              );
            },
            itemBuilder: (context, index) {
              final counter = counters[index];
              final currentValue = values[counter.id] ?? counter.startValue;
              return _CounterCard(
                key: ValueKey(counter.id),
                counter: counter,
                currentValue: currentValue,
                index: index,
                noteId: noteId,
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
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: colorScheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.counterLoadError,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                context.read<CounterBloc>().add(const LoadCounters()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.counterRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCounterDialog(BuildContext context) async {
    final bloc = context.read<CounterBloc>();
    final result = await showCounterFormDialog(context);
    if (result == null || !context.mounted) return;

    bloc.add(
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

class _CounterCard extends StatefulWidget {
  final Counter counter;
  final int currentValue;
  final int index;
  final String? noteId;

  const _CounterCard({
    super.key,
    required this.counter,
    required this.currentValue,
    required this.index,
    this.noteId,
  });

  @override
  State<_CounterCard> createState() => _CounterCardState();
}

class _CounterCardState extends State<_CounterCard> {
  NoteMetadata? _selectedNote;
  int? _localValue;

  Counter get counter => widget.counter;
  int get index => widget.index;

  /// The effective noteId: either passed from the page or picked by the user.
  String? get _effectiveNoteId => widget.noteId ?? _selectedNote?.id;

  /// True when the user picked a note locally on this card (not passed from page).
  bool get _isLocalNoteMode =>
      widget.noteId == null &&
      _selectedNote != null &&
      counter.scope != CounterScope.global;

  /// Display value: local value when in local-note mode, otherwise from bloc.
  int get _displayValue => _isLocalNoteMode
      ? (_localValue ?? counter.startValue)
      : widget.currentValue;

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
                // Drag handle for reordering
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
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
                    isGlobal ? Icons.public_rounded : Icons.note_alt_rounded,
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
                  onSelected: (action) => _handleAction(context, action),
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
            // Value stepper (global always, per-note when noteId available)
            if (isGlobal || _effectiveNoteId != null)
              _buildStepper(context, colorScheme)
            else
              _buildNotePickerPrompt(context, l10n, colorScheme),
            // Show selected note chip when user picked one
            if (!isGlobal && widget.noteId == null && _selectedNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_alt_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedNote!.title.isEmpty
                            ? l10n.untitledNote
                            : _selectedNote!.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _selectedNote = null;
                        _localValue = null;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Info chips row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
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

  Widget _buildNotePickerPrompt(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => _pickNote(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 18,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.counterSelectNoteToView,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickNote(BuildContext context) async {
    final note = await showNotePickerDialog(context);
    if (note == null || !context.mounted) return;
    // Load this counter's value for the picked note locally,
    // without overwriting the shared bloc state.
    final service = GetIt.I<CounterService>();
    final value = await service.getValueForNote(counter.id, note.id);
    setState(() {
      _selectedNote = note;
      _localValue = value;
    });
  }

  Widget _buildStepper(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove_rounded),
          onPressed: () {
            if (_isLocalNoteMode) {
              GetIt.I<CounterService>().decrementForNote(
                counter.id,
                _selectedNote!.id,
              );
              setState(() {
                _localValue =
                    (_localValue ?? counter.startValue) - counter.step;
              });
            } else {
              context.read<CounterBloc>().add(
                DecrementCounter(
                  counterId: counter.id,
                  noteId: _effectiveNoteId,
                ),
              );
            }
          },
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _setValueDialog(context),
          child: Tooltip(
            message: AppLocalizations.of(context)!.counterSetValue,
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_displayValue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          icon: const Icon(Icons.add_rounded),
          onPressed: () {
            if (_isLocalNoteMode) {
              GetIt.I<CounterService>().increment(
                counter.id,
                noteId: _selectedNote!.id,
              );
              setState(() {
                _localValue =
                    (_localValue ?? counter.startValue) + counter.step;
              });
            } else {
              context.read<CounterBloc>().add(
                IncrementCounter(
                  counterId: counter.id,
                  noteId: _effectiveNoteId,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _setValueDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final raw = await AppDialogs.textInput(
      context,
      title: l10n.counterSetValue,
      initialValue: '$_displayValue',
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
    );
    if (raw == null || !context.mounted) return;
    final value = int.tryParse(raw.trim());
    if (value == null) return;
    if (_isLocalNoteMode) {
      await GetIt.I<CounterService>().setValueForNote(
        counter.id,
        value,
        noteId: _selectedNote!.id,
      );
      setState(() => _localValue = value);
    } else {
      context.read<CounterBloc>().add(
        SetCounterValue(
          counterId: counter.id,
          value: value,
          noteId: _effectiveNoteId,
        ),
      );
    }
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final bloc = context.read<CounterBloc>();
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case 'edit':
        final result = await showCounterFormDialog(context, existing: counter);
        if (result == null || !context.mounted) return;
        bloc.add(
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
        if (_isLocalNoteMode) {
          await GetIt.I<CounterService>().resetForNote(
            counter.id,
            _selectedNote!.id,
          );
          setState(() => _localValue = counter.startValue);
        } else {
          bloc.add(
            ResetCounter(counterId: counter.id, noteId: _effectiveNoteId),
          );
        }
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
        bloc.add(DeleteCounter(counterId: counter.id));
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
