import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../l10n/app_localizations.dart';
import '../models/folder.dart';
import '../services/folder_storage_service.dart';
import '../services/app_navigator.dart';
import '../constants/app_colors.dart';

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
  final List<_BreadcrumbEntry> _breadcrumbs = [];
  List<Folder>? _folders;
  bool _isLoading = true;

  String? get _currentParentId =>
      _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;

  @override
  void initState() {
    super.initState();
    _loadFolders();
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
    if (mounted) {
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    }
  }

  void _navigateInto(Folder folder) {
    _breadcrumbs.add(_BreadcrumbEntry(id: folder.id, name: folder.name));
    _loadFolders();
  }

  void _navigateUp() {
    if (_breadcrumbs.isNotEmpty) {
      _breadcrumbs.removeLast();
      _loadFolders();
    }
  }

  void _navigateToBreadcrumb(int index) {
    if (index < 0) {
      _breadcrumbs.clear();
    } else {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
    }
    _loadFolders();
  }

  bool get _canSelectCurrent {
    final currentId = _currentParentId ?? '';
    if (currentId != widget.currentFolderId) {
      if (currentId.isEmpty && !widget.allowRoot) return false;
      return true;
    }
    return false;
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
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBreadcrumbs(l10n, colorScheme),
            const Divider(height: 1),
            Expanded(child: _buildFolderList(l10n, colorScheme)),
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
              ? () => AppNavigator.pop(context, _currentParentId ?? '')
              : null,
          child: Text(l10n.moveHere),
        ),
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
