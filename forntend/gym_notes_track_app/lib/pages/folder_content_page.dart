import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../l10n/app_localizations.dart';
import '../bloc/folder/folder_bloc.dart';
import '../bloc/folder/folder_event.dart';
import '../bloc/folder/folder_state.dart';
import '../bloc/note/note_bloc.dart';
import '../bloc/note/note_event.dart';
import '../bloc/note/note_state.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'note_editor_page.dart';

class FolderContentPage extends StatefulWidget {
  final String? folderId;
  final String title;

  const FolderContentPage({super.key, this.folderId, required this.title});

  @override
  State<FolderContentPage> createState() => _FolderContentPageState();
}

class _FolderContentPageState extends State<FolderContentPage> {
  @override
  void initState() {
    super.initState();
    if (widget.folderId != null) {
      Future.microtask(() {
        if (mounted) {
          context.read<NoteBloc>().add(LoadNotes(widget.folderId!));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FolderBloc>().add(LoadFolders());
          if (widget.folderId != null) {
            context.read<NoteBloc>().add(LoadNotes(widget.folderId!));
          }
        },
        child: CustomScrollView(
          slivers: [_buildFoldersSection(), _buildNotesSection()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFoldersSection() {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, state) {
        if (state is FolderInitial) {
          context.read<FolderBloc>().add(LoadFolders());
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is FolderLoading) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is FolderError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        if (state is FolderLoaded) {
          final folders = state.folders
              .where((folder) => folder.parentId == widget.folderId)
              .toList();

          if (folders.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final folder = folders[index];
              return _FolderCard(folder: folder);
            }, childCount: folders.length),
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

    return BlocBuilder<NoteBloc, NoteState>(
      builder: (context, state) {
        if (state is NoteLoading) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (state is NoteError) {
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

        if (state is NoteLoaded) {
          final filteredNotes = state.notes
              .where((note) => note.folderId == widget.folderId)
              .toList();

          if (filteredNotes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final note = filteredNotes[index];
              return _NoteCard(note: note, folderId: widget.folderId!);
            }, childCount: filteredNotes.length),
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
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
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.folderName,
            hintText: AppLocalizations.of(context)!.enterFolderName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<FolderBloc>().add(
                  CreateFolder(
                    controller.text.trim(),
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
            NoteEditorPage(folderId: widget.folderId!, note: null),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final Folder folder;

  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.folder, size: 40, color: Colors.amber),
        title: Text(
          folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.created(_formatDate(folder.createdAt)),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDelete(context);
            } else if (value == 'rename') {
              _showRenameDialog(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: Text(AppLocalizations.of(context)!.rename),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FolderContentPage(folderId: folder.id, title: folder.name),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
              context.read<FolderBloc>().add(DeleteFolder(folder.id));
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

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameFolder),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.folderName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<FolderBloc>().add(
                  UpdateFolder(folder.id, controller.text.trim()),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: Text(AppLocalizations.of(context)!.rename),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final String folderId;

  const _NoteCard({required this.note, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.note, size: 40, color: Colors.blue),
        title: Text(
          note.title.isEmpty
              ? AppLocalizations.of(context)!.untitledNote
              : note.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.content.isEmpty
                  ? AppLocalizations.of(context)!.emptyNote
                  : note.content.replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(
                context,
              )!.updated(_formatDate(note.updatedAt)),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  NoteEditorPage(folderId: folderId, note: note),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteNote),
        content: Text(
          AppLocalizations.of(context)!.deleteNoteConfirm(
            note.title.isEmpty
                ? AppLocalizations.of(context)!.deleteThisNote
                : note.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NoteBloc>().add(DeleteNote(note.id));
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
