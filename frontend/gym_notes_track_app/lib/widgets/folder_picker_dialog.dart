import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/folder.dart';
import '../services/app_navigator.dart';
import '../services/folder_name_index.dart';
import '../services/folder_storage_service.dart';
import '../services/recent_destinations_service.dart';

/// Show the folder picker dialog and return:
///   - `null` if the user cancels;
///   - `''` (empty string) for the root folder;
///   - the folder id of the chosen folder otherwise.
Future<String?> showFolderPickerDialog(
  BuildContext context, {
  required String currentFolderId,
  Set<String>? excludeFolderIds,
  bool allowRoot = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderPickerDialog(
      currentFolderId: currentFolderId,
      excludeFolderIds: excludeFolderIds ?? const {},
      allowRoot: allowRoot,
    ),
  );
}

class _FolderPickerDialog extends StatefulWidget {
  final String currentFolderId;
  final Set<String> excludeFolderIds;
  final bool allowRoot;

  const _FolderPickerDialog({
    required this.currentFolderId,
    required this.excludeFolderIds,
    required this.allowRoot,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  final FolderStorageService _folderService = GetIt.I<FolderStorageService>();
  final FolderNameIndex _index = GetIt.I<FolderNameIndex>();
  final RecentDestinationsService _recentsService =
      GetIt.I<RecentDestinationsService>();

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  List<Folder> _searchResults = const [];
  bool _isSearching = false;

  final List<_BreadcrumbEntry> _breadcrumbs = [];
  List<Folder>? _folders;
  bool _isLoading = true;

  // Resolved recent destinations, excluding any that are filtered out by
  // [excludeFolderIds] or no longer exist.
  List<_RecentEntry> _recentEntries = const [];

  String? get _currentParentId =>
      _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _resolveRecents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final raw = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (raw.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = const [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _runSearch(raw);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });
    final results = await _index.search(
      query,
      excludeIds: widget.excludeFolderIds,
      limit: 50,
    );
    if (!mounted || _searchController.text.trim() != query) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    final allFolders = await _folderService.loadAllFoldersForParent(
      _currentParentId,
    );
    final folders = widget.excludeFolderIds.isEmpty
        ? allFolders
        : allFolders
              .where((f) => !widget.excludeFolderIds.contains(f.id))
              .toList();
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<void> _resolveRecents() async {
    final ids = _recentsService.recents;
    if (ids.isEmpty) {
      if (mounted) setState(() => _recentEntries = const []);
      return;
    }
    final entries = <_RecentEntry>[];
    for (final id in ids) {
      if (id == null) {
        if (widget.allowRoot) {
          entries.add(const _RecentEntry(id: null, name: null));
        }
        continue;
      }
      if (widget.excludeFolderIds.contains(id)) continue;
      final folder = await _folderService.getFolderById(id);
      if (folder != null) {
        entries.add(_RecentEntry(id: id, name: folder.name));
      }
    }
    if (!mounted) return;
    setState(() => _recentEntries = entries);
  }

  void _navigateInto(Folder folder) {
    setState(() {
      _breadcrumbs.add(_BreadcrumbEntry(id: folder.id, name: folder.name));
    });
    _loadFolders();
  }

  void _navigateUp() {
    if (_breadcrumbs.isEmpty) return;
    setState(() => _breadcrumbs.removeLast());
    _loadFolders();
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      if (index < 0) {
        _breadcrumbs.clear();
      } else {
        _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      }
    });
    _loadFolders();
  }

  bool get _canSelectCurrent {
    final currentId = _currentParentId ?? '';
    if (currentId == widget.currentFolderId) return false;
    if (currentId.isEmpty && !widget.allowRoot) return false;
    return true;
  }

  void _confirmSelection(String? id) {
    AppNavigator.pop(context, id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.selectDestinationFolder),
      contentPadding: const EdgeInsets.only(top: 12, bottom: 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(l10n, colorScheme),
            const SizedBox(height: 4),
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults(l10n, colorScheme)
                  : _buildBrowseView(l10n, colorScheme),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSelectCurrent
              ? () => _confirmSelection(_currentParentId)
              : null,
          child: Text(l10n.moveHere),
        ),
      ],
    );
  }

  Widget _buildSearchField(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchFolders,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                  visualDensity: VisualDensity.compact,
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noFoldersFound,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final folder = _searchResults[index];
        final isCurrent = folder.id == widget.currentFolderId;
        return ListTile(
          leading: Icon(
            Icons.folder,
            color: isCurrent
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : AppColors.folderIcon(context),
          ),
          title: Text(folder.name),
          dense: true,
          enabled: !isCurrent,
          onTap: isCurrent ? null : () => _confirmSelection(folder.id),
        );
      },
    );
  }

  Widget _buildBrowseView(AppLocalizations l10n, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_recentEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.recentDestinations,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _recentEntries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _recentEntries[index];
                final label = entry.name ?? l10n.rootFolder;
                return ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(label),
                  onPressed: () => _confirmSelection(entry.id),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
        _buildBreadcrumbs(l10n, colorScheme),
        const Divider(height: 1),
        Expanded(child: _buildFolderList(l10n, colorScheme)),
      ],
    );
  }

  Widget _buildBreadcrumbs(AppLocalizations l10n, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _breadcrumbs.isNotEmpty
                ? () => _navigateToBreadcrumb(-1)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                l10n.rootFolder,
                style: TextStyle(
                  fontWeight: _breadcrumbs.isEmpty
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _breadcrumbs.isEmpty
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (int i = 0; i < _breadcrumbs.length; i++) ...[
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: i < _breadcrumbs.length - 1
                  ? () => _navigateToBreadcrumb(i)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _breadcrumbs[i].name,
                  style: TextStyle(
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == _breadcrumbs.length - 1
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderList(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final folders = _folders ?? [];
    if (folders.isEmpty && _breadcrumbs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noFoldersAvailable,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final items = <Widget>[];
    if (_breadcrumbs.isNotEmpty) {
      items.add(
        ListTile(
          leading: const Icon(Icons.arrow_upward, size: 20),
          title: Text(
            '..',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          dense: true,
          onTap: _navigateUp,
        ),
      );
    }

    for (final folder in folders) {
      final isCurrentFolder = folder.id == widget.currentFolderId;
      items.add(
        ListTile(
          leading: Icon(
            Icons.folder,
            color: isCurrentFolder
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : AppColors.folderIcon(context),
          ),
          title: Text(
            folder.name,
            style: TextStyle(
              color: isCurrentFolder
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : null,
            ),
          ),
          trailing: isCurrentFolder
              ? null
              : Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
          dense: true,
          enabled: !isCurrentFolder,
          onTap: isCurrentFolder ? null : () => _navigateInto(folder),
        ),
      );
    }

    return ListView(children: items);
  }
}

class _BreadcrumbEntry {
  final String id;
  final String name;

  const _BreadcrumbEntry({required this.id, required this.name});
}

class _RecentEntry {
  /// `null` means "root".
  final String? id;
  final String? name;

  const _RecentEntry({required this.id, required this.name});
}
