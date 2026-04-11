import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../l10n/app_localizations.dart';
import '../models/note_metadata.dart';
import '../services/note_storage_service.dart';

/// A searchable dialog that lists available notes and lets the user pick one.
///
/// Returns the selected [NoteMetadata] or `null` if cancelled.
Future<NoteMetadata?> showNotePickerDialog(BuildContext context) {
  return showDialog<NoteMetadata>(
    context: context,
    builder: (_) => const _NotePickerDialog(),
  );
}

class _NotePickerDialog extends StatefulWidget {
  const _NotePickerDialog();

  @override
  State<_NotePickerDialog> createState() => _NotePickerDialogState();
}

class _NotePickerDialogState extends State<_NotePickerDialog> {
  final _searchController = TextEditingController();
  List<NoteMetadata> _allNotes = [];
  List<NoteMetadata> _filtered = [];
  bool _isLoading = true;
  Timer? _debounce;

  static const _kPageSize = 6;
  int _page = 0;

  int get _totalPages => (_filtered.length / _kPageSize).ceil().clamp(1, 999);

  List<NoteMetadata> get _pageItems {
    final start = _page * _kPageSize;
    final end = (start + _kPageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final storageService = GetIt.I<NoteStorageService>();
    final paginated = await storageService.loadNotesPaginated(
      pageSize: 1000,
      sortOrder: NotesSortOrder.updatedDesc,
    );
    if (!mounted) return;
    setState(() {
      _allNotes = paginated.notes;
      _filtered = _allNotes;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final query = _searchController.text.toLowerCase().trim();
      setState(() {
        if (query.isEmpty) {
          _filtered = _allNotes;
        } else {
          _filtered = _allNotes.where((n) {
            return n.title.toLowerCase().contains(query) ||
                n.preview.toLowerCase().contains(query);
          }).toList();
        }
        _page = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final showPagination = _filtered.length > _kPageSize;

    return AlertDialog(
      title: Text(l10n.selectNote),
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
                  hintText: l10n.searchNotes,
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

            // Content
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _allNotes.isEmpty
                                ? Icons.note_outlined
                                : Icons.search_off_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _allNotes.isEmpty
                                ? l10n.noNotesAvailable
                                : l10n.noNotesMatchSearch,
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
                        final note = _pageItems[index];
                        return ListTile(
                          leading: Icon(
                            Icons.note_alt_rounded,
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            note.title.isEmpty ? l10n.untitledNote : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: note.preview.isNotEmpty
                              ? Text(
                                  note.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, note),
                        );
                      },
                    ),
            ),

            // Pagination
            if (showPagination)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      visualDensity: VisualDensity.compact,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousPageTooltip,
                    ),
                    Text(
                      '${_page + 1} / $_totalPages',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      onPressed: _page < _totalPages - 1
                          ? () => setState(() => _page++)
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
