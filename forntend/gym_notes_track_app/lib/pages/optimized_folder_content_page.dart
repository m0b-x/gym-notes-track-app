import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../l10n/app_localizations.dart';
import '../bloc/optimized_folder/optimized_folder_bloc.dart';
import '../bloc/optimized_folder/optimized_folder_event.dart';
import '../bloc/optimized_folder/optimized_folder_state.dart';
import '../bloc/optimized_note/optimized_note_bloc.dart';
import '../bloc/optimized_note/optimized_note_event.dart';
import '../bloc/optimized_note/optimized_note_state.dart';
import '../models/folder.dart';
import '../models/note_metadata.dart';
import '../services/folder_storage_service.dart';
import '../services/note_storage_service.dart';
import '../widgets/infinite_scroll_list.dart';
import '../utils/bloc_helpers.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    debugPrint('Loading data for folder=${widget.folderId}');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
          if (widget.folderId != null)
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
          debugPrint('Folders state -> initial for ${widget.folderId}');
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
          debugPrint('Folders state -> loading for ${widget.folderId}');
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
          debugPrint('Folders state -> error ${state.message}');
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

          debugPrint(
            'Folders state -> loaded count=${folders.length} hasMore=${state.paginatedFolders.hasMore} parent=${widget.folderId}',
          );

          if (folders.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
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
          debugPrint('Notes state -> loading for ${widget.folderId}');
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
          debugPrint('Notes state -> error ${state.message}');
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

          debugPrint(
            'Notes state -> loaded count=${notes?.length ?? 0} hasMore=${state.paginatedNotes.hasMore} folder=${widget.folderId}',
          );

          if (notes == null || notes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
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

          debugPrint(
            'Notes state -> content loaded, showing previous list count=${notes?.length ?? 0} folder=${widget.folderId}',
          );

          if (notes == null || notes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    debugPrint('Navigation -> push create note for folder=${widget.folderId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OptimizedNoteEditorPage(folderId: widget.folderId!),
      ),
    ).then((_) {
      if (mounted) {
        debugPrint('Navigation -> back from create note, reloading');
        _loadData();
      }
    });
  }
}

class _FolderCard extends StatelessWidget {
  final Folder folder;
  final String? parentId;
  final VoidCallback onReturn;

  const _FolderCard({
    required this.folder,
    this.parentId,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.folder, size: 40, color: Colors.amber),
        title: Text(
          folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: () {
          debugPrint(
            'Navigation -> into folder ${folder.id} from parent=$parentId',
          );
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
              debugPrint(
                'Navigation -> back from folder ${folder.id}, reloading parent=$parentId',
              );
              onReturn();
            }
          });
        },
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

  const _NoteCard({
    required this.metadata,
    required this.folderId,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Stack(
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
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: () {
          debugPrint(
            'Navigation -> into note ${metadata.id} in folder=$folderId',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OptimizedNoteEditorPage(
                folderId: folderId,
                noteId: metadata.id,
                metadata: metadata,
              ),
            ),
          ).then((_) {
            if (context.mounted) {
              debugPrint(
                'Navigation -> back from note ${metadata.id}, reloading folder=$folderId',
              );
              onReturn();
            }
          });
        },
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
