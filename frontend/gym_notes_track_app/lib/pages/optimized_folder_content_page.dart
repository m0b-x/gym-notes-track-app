import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../bloc/optimized_folder/optimized_folder_bloc.dart';
import '../bloc/optimized_folder/optimized_folder_event.dart';
import '../bloc/optimized_folder/optimized_folder_state.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/folder.dart';
import '../models/note_metadata.dart';
import '../repositories/note_repository.dart';
import '../services/folder_storage_service.dart';
import '../services/note_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/infinite_scroll_list.dart';
import '../widgets/app_drawer.dart';
import '../widgets/gradient_app_bar.dart';
import '../utils/bloc_helpers.dart';
import '../utils/custom_snackbar.dart';
import 'optimized_note_editor_page.dart';
import 'search_page.dart';

class OptimizedFolderContentPage extends StatefulWidget {
  final String? folderId;
  final String title;

  const OptimizedFolderContentPage({
    super.key,
    this.folderId,
    required this.title,
  });

  @override
  State<OptimizedFolderContentPage> createState() =>
      _OptimizedFolderContentPageState();
}

class _OptimizedFolderContentPageState
    extends State<OptimizedFolderContentPage> {
  final ScrollController _scrollController = ScrollController();
  NotesSortOrder _notesSortOrder = NotesSortOrder.updatedDesc;
  final FoldersSortOrder _foldersSortOrder = FoldersSortOrder.nameAsc;
  bool _isReorderMode = false;
  bool _folderSwipeEnabled = true;

  NoteRepository get _noteRepository => GetIt.I<NoteRepository>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadData();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getInstance();
    if (mounted) {
      setState(() {
        _folderSwipeEnabled = settings.folderSwipeEnabled;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when returning from settings page
    _loadSettings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleReorderMode() {
    setState(() {
      _isReorderMode = !_isReorderMode;
    });
  }

  void _preloadNoteContent(List<String> noteIds) {
    _noteRepository.preloadContent(noteIds);
  }

  void _loadData() {
    context.read<OptimizedFolderBloc>().add(
      LoadFoldersPaginated(
        parentId: widget.folderId,
        sortOrder: _foldersSortOrder,
      ),
    );
    if (widget.folderId != null) {
      context.read<OptimizedNoteBloc>().add(
        LoadNotesPaginated(
          folderId: widget.folderId,
          sortOrder: _notesSortOrder,
        ),
      );
    }
  }

  void _onNotesSortChanged(NotesSortOrder? newOrder) {
    if (newOrder == null) return;
    setState(() {
      _notesSortOrder = newOrder;
    });
    context.read<OptimizedNoteBloc>().add(
      LoadNotesPaginated(folderId: widget.folderId, sortOrder: newOrder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRootPage = widget.folderId == null;

    final scaffold = Scaffold(
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: _folderSwipeEnabled,
      appBar: GradientAppBar(
        automaticallyImplyLeading: false,
        purpleAlpha: 0.7,
        leading: !isRootPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Reorder mode toggle
          IconButton(
            icon: Icon(_isReorderMode ? Icons.check : Icons.swap_vert),
            tooltip: AppLocalizations.of(context)!.reorderMode,
            onPressed: _toggleReorderMode,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: widget.folderId != null
                ? AppLocalizations.of(context)!.searchInFolder
                : AppLocalizations.of(context)!.searchAll,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(folderId: widget.folderId),
                ),
              );
            },
          ),
          if (widget.folderId != null && !_isReorderMode)
            PopupMenuButton<NotesSortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: AppLocalizations.of(context)!.sortBy,
              onSelected: _onNotesSortChanged,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: NotesSortOrder.updatedDesc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByUpdated,
                    AppLocalizations.of(context)!.descending,
                    NotesSortOrder.updatedDesc,
                  ),
                ),
                PopupMenuItem(
                  value: NotesSortOrder.updatedAsc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByUpdated,
                    AppLocalizations.of(context)!.ascending,
                    NotesSortOrder.updatedAsc,
                  ),
                ),
                PopupMenuItem(
                  value: NotesSortOrder.createdDesc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByCreated,
                    AppLocalizations.of(context)!.descending,
                    NotesSortOrder.createdDesc,
                  ),
                ),
                PopupMenuItem(
                  value: NotesSortOrder.createdAsc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByCreated,
                    AppLocalizations.of(context)!.ascending,
                    NotesSortOrder.createdAsc,
                  ),
                ),
                PopupMenuItem(
                  value: NotesSortOrder.titleAsc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByTitle,
                    AppLocalizations.of(context)!.ascending,
                    NotesSortOrder.titleAsc,
                  ),
                ),
                PopupMenuItem(
                  value: NotesSortOrder.titleDesc,
                  child: _buildNotesSortMenuItem(
                    context,
                    AppLocalizations.of(context)!.sortByTitle,
                    AppLocalizations.of(context)!.descending,
                    NotesSortOrder.titleDesc,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildFoldersSection(),
            _buildNotesSection(),
            _buildEmptyStateSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add),
      ),
    );

    // Wrap with PopScope to disable iOS swipe-back gesture in subfolders
    // so that drawer swipe gesture works instead
    if (!isRootPage && _folderSwipeEnabled) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: scaffold,
      );
    }

    return scaffold;
  }

  Widget _buildNotesSortMenuItem(
    BuildContext context,
    String label,
    String order,
    NotesSortOrder value,
  ) {
    final isSelected = _notesSortOrder == value;
    return Row(
      children: [
        if (isSelected)
          Icon(
            Icons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          )
        else
          const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text('$label ($order)'),
      ],
    );
  }

  Widget _buildFoldersSection() {
    return BlocBuilder<OptimizedFolderBloc, OptimizedFolderState>(
      buildWhen: FolderBlocFilters.forParentFolder(widget.folderId),
      builder: (context, state) {
        if (state is OptimizedFolderInitial) {
          context.read<OptimizedFolderBloc>().add(
            LoadFoldersPaginated(
              parentId: widget.folderId,
              sortOrder: _foldersSortOrder,
            ),
          );
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is OptimizedFolderLoading) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is OptimizedFolderError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  AppLocalizations.of(context)!.error(state.message),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        if (state is OptimizedFolderLoaded) {
          final folders = state.paginatedFolders.folders;

          if (folders.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          if (_isReorderMode) {
            return SliverReorderableList(
              itemCount: folders.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final reorderedFolders = List<Folder>.from(folders);
                final item = reorderedFolders.removeAt(oldIndex);
                reorderedFolders.insert(newIndex, item);
                context.read<OptimizedFolderBloc>().add(
                  ReorderFolders(
                    parentId: widget.folderId,
                    orderedIds: reorderedFolders.map((f) => f.id).toList(),
                  ),
                );
              },
              itemBuilder: (context, index) {
                final folder = folders[index];
                return _FolderCard(
                  key: ValueKey(folder.id),
                  folder: folder,
                  parentId: widget.folderId,
                  onReturn: _loadData,
                  isReorderMode: true,
                  index: index,
                );
              },
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= folders.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final folder = folders[index];
                return _FolderCard(
                  folder: folder,
                  parentId: widget.folderId,
                  onReturn: _loadData,
                );
              },
              childCount:
                  folders.length + (state.paginatedFolders.hasMore ? 1 : 0),
            ),
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildNotesSection() {
    if (widget.folderId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return BlocBuilder<OptimizedNoteBloc, OptimizedNoteState>(
      buildWhen: NoteBlocFilters.forFolder(widget.folderId),
      builder: (context, state) {
        if (state is OptimizedNoteLoading) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is OptimizedNoteError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  AppLocalizations.of(context)!.error(state.message),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        if (state is OptimizedNoteLoaded) {
          final notes = NoteStateHelper.getNotesForFolder(
            state,
            widget.folderId,
          );

          if (notes == null || notes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          _preloadNoteContent(notes.take(3).map((n) => n.id).toList());

          if (_isReorderMode) {
            return SliverReorderableList(
              itemCount: notes.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final reorderedNotes = List<NoteMetadata>.from(notes);
                final item = reorderedNotes.removeAt(oldIndex);
                reorderedNotes.insert(newIndex, item);
                context.read<OptimizedNoteBloc>().add(
                  ReorderNotes(
                    folderId: widget.folderId!,
                    orderedIds: reorderedNotes.map((n) => n.id).toList(),
                  ),
                );
              },
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(
                  key: ValueKey(note.id),
                  metadata: note,
                  folderId: widget.folderId!,
                  onReturn: _loadData,
                  isReorderMode: true,
                  index: index,
                );
              },
            );
          }

          return InfiniteScrollSliver<NoteMetadata>(
            items: notes,
            hasMore: NoteStateHelper.hasMoreForFolder(state, widget.folderId),
            isLoadingMore: NoteStateHelper.isLoadingMore(state),
            controller: _scrollController,
            onLoadMore: () {
              context.read<OptimizedNoteBloc>().add(
                LoadMoreNotes(folderId: widget.folderId),
              );
            },
            itemBuilder: (context, note, index) {
              return _NoteCard(
                metadata: note,
                folderId: widget.folderId!,
                onReturn: _loadData,
              );
            },
          );
        }

        if (state is OptimizedNoteContentLoaded) {
          final notes = NoteStateHelper.getNotesForFolder(
            state,
            widget.folderId,
          );

          if (notes == null || notes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          _preloadNoteContent(notes.take(3).map((n) => n.id).toList());

          if (_isReorderMode) {
            return SliverReorderableList(
              itemCount: notes.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final reorderedNotes = List<NoteMetadata>.from(notes);
                final item = reorderedNotes.removeAt(oldIndex);
                reorderedNotes.insert(newIndex, item);
                context.read<OptimizedNoteBloc>().add(
                  ReorderNotes(
                    folderId: widget.folderId!,
                    orderedIds: reorderedNotes.map((n) => n.id).toList(),
                  ),
                );
              },
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(
                  key: ValueKey(note.id),
                  metadata: note,
                  folderId: widget.folderId!,
                  onReturn: _loadData,
                  isReorderMode: true,
                  index: index,
                );
              },
            );
          }

          return InfiniteScrollSliver<NoteMetadata>(
            items: notes,
            hasMore: NoteStateHelper.hasMoreForFolder(state, widget.folderId),
            isLoadingMore: false,
            controller: _scrollController,
            onLoadMore: () {
              context.read<OptimizedNoteBloc>().add(
                LoadMoreNotes(folderId: widget.folderId),
              );
            },
            itemBuilder: (context, note, index) {
              return _NoteCard(
                metadata: note,
                folderId: widget.folderId!,
                onReturn: _loadData,
              );
            },
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildEmptyStateSection() {
    return BlocBuilder<OptimizedFolderBloc, OptimizedFolderState>(
      builder: (context, folderState) {
        return BlocBuilder<OptimizedNoteBloc, OptimizedNoteState>(
          buildWhen: NoteBlocFilters.forEmptyState(widget.folderId),
          builder: (context, noteState) {
            bool foldersEmpty = true;
            if (folderState is OptimizedFolderLoaded) {
              foldersEmpty = folderState.paginatedFolders.folders.isEmpty;
            }

            bool notesEmpty = true;
            if (widget.folderId != null) {
              final notes = NoteStateHelper.getNotesForFolder(
                noteState,
                widget.folderId,
              );
              notesEmpty = notes == null || notes.isEmpty;
            }

            if (foldersEmpty &&
                notesEmpty &&
                folderState is OptimizedFolderLoaded &&
                (widget.folderId == null ||
                    noteState is OptimizedNoteLoaded ||
                    noteState is OptimizedNoteContentLoaded)) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.folderId != null
                              ? Icons.note_add
                              : Icons.folder_open,
                          size: 80,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.folderId != null
                              ? AppLocalizations.of(context)!.emptyNotesHint
                              : AppLocalizations.of(context)!.emptyFoldersHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.tapPlusToCreate,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        );
      },
    );
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: Text(AppLocalizations.of(context)!.createFolder),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showCreateFolderDialog();
                },
              ),
              if (widget.folderId != null)
                ListTile(
                  leading: const Icon(Icons.note, color: Colors.blue),
                  title: Text(AppLocalizations.of(context)!.createNote),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _createNewNote();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.createFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterFolderName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<OptimizedFolderBloc>().add(
                  CreateOptimizedFolder(
                    name: controller.text.trim(),
                    parentId: widget.folderId,
                  ),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: Text(AppLocalizations.of(context)!.create),
          ),
        ],
      ),
    );
  }

  void _createNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OptimizedNoteEditorPage(folderId: widget.folderId!),
      ),
    ).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }
}

class _FolderCard extends StatelessWidget {
  final Folder folder;
  final String? parentId;
  final VoidCallback onReturn;
  final bool isReorderMode;
  final int? index;

  const _FolderCard({
    super.key,
    required this.folder,
    this.parentId,
    required this.onReturn,
    this.isReorderMode = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: isReorderMode
            ? ReorderableDragStartListener(
                index: index ?? 0,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              )
            : const Icon(Icons.folder, size: 40, color: Colors.amber),
        title: Text(
          folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: isReorderMode
            ? const Icon(Icons.folder, size: 24, color: Colors.amber)
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context);
                      break;
                    case 'delete':
                      _confirmDelete(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.rename),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: isReorderMode
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OptimizedFolderContentPage(
                      folderId: folder.id,
                      title: folder.name,
                    ),
                  ),
                ).then((_) {
                  if (context.mounted) {
                    onReturn();
                  }
                });
              },
        onLongPress: isReorderMode ? null : () => _showRenameDialog(context),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterNewName,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              context.read<OptimizedFolderBloc>().add(
                UpdateOptimizedFolder(folderId: folder.id, name: value.trim()),
              );
              Navigator.pop(dialogContext);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<OptimizedFolderBloc>().add(
                  UpdateOptimizedFolder(
                    folderId: folder.id,
                    name: controller.text.trim(),
                  ),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteFolder),
        content: Text(
          AppLocalizations.of(context)!.deleteFolderConfirm(folder.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<OptimizedFolderBloc>().add(
                DeleteOptimizedFolder(folderId: folder.id, parentId: parentId),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteMetadata metadata;
  final String folderId;
  final VoidCallback onReturn;
  final bool isReorderMode;
  final int? index;

  const _NoteCard({
    super.key,
    required this.metadata,
    required this.folderId,
    required this.onReturn,
    this.isReorderMode = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: isReorderMode
            ? ReorderableDragStartListener(
                index: index ?? 0,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              )
            : Stack(
                children: [
                  const Icon(Icons.note, size: 40, color: Colors.blue),
                  if (metadata.isCompressed)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.compress,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
        title: Text(
          metadata.title.isEmpty
              ? AppLocalizations.of(context)!.untitledNote
              : metadata.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metadata.preview.isEmpty
                  ? AppLocalizations.of(context)!.emptyNote
                  : metadata.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(metadata.updatedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSize(metadata.contentLength),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isReorderMode
            ? const Icon(Icons.note, size: 24, color: Colors.blue)
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context);
                      break;
                    case 'share':
                      _showExportFormatDialog(context);
                      break;
                    case 'delete':
                      _confirmDelete(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.rename),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        const Icon(Icons.share, size: 20),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.shareNote),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: isReorderMode
            ? null
            : () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return OptimizedNoteEditorPage(
                        folderId: folderId,
                        noteId: metadata.id,
                        metadata: metadata,
                      );
                    },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: const Duration(
                      milliseconds: 150,
                    ),
                  ),
                ).then((_) {
                  if (context.mounted) {
                    onReturn();
                  }
                });
              },
        onLongPress: isReorderMode
            ? null
            : () => _showOptionsBottomSheet(context),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                metadata.title.isEmpty
                    ? AppLocalizations.of(context)!.untitledNote
                    : metadata.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(AppLocalizations.of(context)!.rename),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(AppLocalizations.of(context)!.shareNote),
              onTap: () {
                Navigator.pop(sheetContext);
                _showExportFormatDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: colorScheme.error),
              title: Text(
                AppLocalizations.of(context)!.delete,
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showExportFormatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chooseExportFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsMarkdown),
              onTap: () {
                Navigator.pop(dialogContext);
                _exportNote(context, 'md');
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsJson),
              onTap: () {
                Navigator.pop(dialogContext);
                _exportNote(context, 'json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_rounded),
              title: Text(AppLocalizations.of(context)!.exportAsText),
              onTap: () {
                Navigator.pop(dialogContext);
                _exportNote(context, 'txt');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _exportNote(BuildContext context, String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(AppLocalizations.of(dialogContext)!.exportingNote),
          ],
        ),
      ),
    );

    try {
      final noteRepository = GetIt.I<NoteRepository>();
      final content = await noteRepository.loadContent(metadata.id);

      String fileContent;
      String extension;

      switch (format) {
        case 'md':
          extension = 'md';
          final title = metadata.title.isEmpty ? 'Untitled' : metadata.title;
          fileContent = '# $title\n\n$content';
          break;
        case 'json':
          extension = 'json';
          final noteJson = {
            'title': metadata.title,
            'content': content,
            'createdAt': metadata.createdAt.toIso8601String(),
            'updatedAt': metadata.updatedAt.toIso8601String(),
            'exportedAt': DateTime.now().toIso8601String(),
          };
          fileContent = const JsonEncoder.withIndent('  ').convert(noteJson);
          break;
        case 'txt':
        default:
          extension = 'txt';
          fileContent = content;
          break;
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = metadata.title.isEmpty
          ? 'note_${metadata.id.substring(0, 8)}'
          : metadata.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '$sanitizedTitle.$extension';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(fileContent);

      if (!context.mounted) return;
      Navigator.pop(context);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);

      CustomSnackbar.showError(
        context,
        '${AppLocalizations.of(context)!.noteExportError}: $e',
      );
    }
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: metadata.title);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterNewName,
          ),
          onSubmitted: (value) {
            context.read<OptimizedNoteBloc>().add(
              UpdateOptimizedNote(noteId: metadata.id, title: value.trim()),
            );
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<OptimizedNoteBloc>().add(
                UpdateOptimizedNote(
                  noteId: metadata.id,
                  title: controller.text.trim(),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteNote),
        content: Text(
          AppLocalizations.of(context)!.deleteNoteConfirm(
            metadata.title.isEmpty
                ? AppLocalizations.of(context)!.deleteThisNote
                : metadata.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<OptimizedNoteBloc>().add(
                DeleteOptimizedNote(metadata.id),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
