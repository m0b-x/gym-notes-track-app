import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../l10n/app_localizations.dart';
import '../models/folder.dart' as model;
import '../models/note_metadata.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/folder_picker_dialog.dart';
import 'folder_storage_service.dart';
import 'move_history_service.dart';
import 'note_storage_service.dart';

class MoveCoordinator {
  const MoveCoordinator._();

  static FolderStorageService get _folderService =>
      GetIt.I<FolderStorageService>();
  static NoteStorageService get _noteService => GetIt.I<NoteStorageService>();
  static MoveHistoryService get _historyService =>
      GetIt.I<MoveHistoryService>();

  static Future<void> moveFolder(
    BuildContext context, {
    required model.Folder folder,
    required String? currentParentId,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final descendantIds = await _folderService.getDescendantIds(folder.id);
    if (!context.mounted) return;

    final picked = await showFolderPickerDialog(
      context,
      currentFolderId: currentParentId ?? '',
      excludeFolderIds: {folder.id, ...descendantIds},
    );
    if (picked == null || !context.mounted) return;

    if (picked == (currentParentId ?? '')) {
      CustomSnackbar.show(context, l10n.alreadyInThisFolder);
      return;
    }

    final targetParentId = picked.isEmpty ? null : picked;

    final sourceName = currentParentId == null
        ? null
        : (await _folderService.getFolderById(currentParentId))?.name;
    final targetName = targetParentId == null
        ? null
        : (await _folderService.getFolderById(targetParentId))?.name;

    if (!context.mounted) return;

    final result = await _folderService.moveFolder(
      folderId: folder.id,
      targetParentId: targetParentId,
    );
    if (!context.mounted) return;

    if (result == null) {
      CustomSnackbar.showError(context, l10n.folderMoveFailed);
      return;
    }

    _historyService.addMove(
      itemType: MoveItemType.folder,
      itemId: folder.id,
      itemName: folder.name,
      sourceParentId: currentParentId,
      sourceParentName: sourceName,
      targetParentId: targetParentId,
      targetParentName: targetName,
    );
    final entryId = _historyService.history.first.id;

    CustomSnackbar.showWithAction(
      context,
      message: l10n.folderMoved,
      actionLabel: l10n.undo,
      onAction: () => undoEntryById(context, entryId),
    );
  }

  static Future<void> moveNote(
    BuildContext context, {
    required NoteMetadata metadata,
    required String currentFolderId,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final picked = await showFolderPickerDialog(
      context,
      currentFolderId: currentFolderId,
      allowRoot: false,
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;

    if (picked == currentFolderId) {
      CustomSnackbar.show(context, l10n.alreadyInThisFolder);
      return;
    }

    final sourceName = (await _folderService.getFolderById(
      currentFolderId,
    ))?.name;
    final targetName = (await _folderService.getFolderById(picked))?.name;

    if (!context.mounted) return;

    final result = await _noteService.moveNote(
      noteId: metadata.id,
      targetFolderId: picked,
    );
    if (!context.mounted) return;

    if (result == null) {
      CustomSnackbar.showError(context, l10n.noteMoveFailed);
      return;
    }

    final noteName = metadata.title.isEmpty
        ? l10n.untitledNote
        : metadata.title;

    _historyService.addMove(
      itemType: MoveItemType.note,
      itemId: metadata.id,
      itemName: noteName,
      sourceParentId: currentFolderId,
      sourceParentName: sourceName,
      targetParentId: picked,
      targetParentName: targetName,
    );
    final entryId = _historyService.history.first.id;

    CustomSnackbar.showWithAction(
      context,
      message: l10n.noteMoved,
      actionLabel: l10n.undo,
      onAction: () => undoEntryById(context, entryId),
    );
  }

  static Future<void> undoEntryById(
    BuildContext context,
    String entryId,
  ) async {
    final entry = _historyService.history
        .where((e) => e.id == entryId)
        .firstOrNull;
    if (entry == null) return;
    return undoEntry(context, entry);
  }

  static Future<void> undoEntry(
    BuildContext context,
    MoveHistoryEntry entry,
  ) async {
    if (_historyService.isEntryUndone(entry.id)) return;

    switch (entry.itemType) {
      case MoveItemType.folder:
        await _undoFolderMove(context, entry);
      case MoveItemType.note:
        await _undoNoteMove(context, entry);
    }
  }

  static Future<void> _undoFolderMove(
    BuildContext context,
    MoveHistoryEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    String? destination = entry.sourceParentId;

    if (destination != null) {
      final exists = await _folderService.getFolderById(destination);
      if (exists == null) {
        if (!context.mounted) return;
        CustomSnackbar.show(context, l10n.originalLocationGone);
        final descendantIds = await _folderService.getDescendantIds(
          entry.itemId,
        );
        if (!context.mounted) return;
        final picked = await showFolderPickerDialog(
          context,
          currentFolderId: '',
          excludeFolderIds: {entry.itemId, ...descendantIds},
        );
        destination = (picked == null || picked.isEmpty) ? null : picked;
      }
    }

    if (!context.mounted) return;

    final result = await _folderService.moveFolder(
      folderId: entry.itemId,
      targetParentId: destination,
    );
    if (!context.mounted) return;

    if (result == null) {
      CustomSnackbar.showError(context, l10n.folderMoveFailed);
      return;
    }

    _historyService.markUndone(entry.id);
    CustomSnackbar.show(context, l10n.moveUndone);
  }

  static Future<void> _undoNoteMove(
    BuildContext context,
    MoveHistoryEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    String? destination = entry.sourceParentId;

    final needsPrompt =
        destination == null ||
        (await _folderService.getFolderById(destination)) == null;

    if (needsPrompt) {
      if (!context.mounted) return;
      CustomSnackbar.show(context, l10n.originalLocationGone);
      if (!context.mounted) return;
      final picked = await showFolderPickerDialog(
        context,
        currentFolderId: '',
        allowRoot: false,
      );
      if (picked == null || picked.isEmpty) {
        destination = await _firstAvailableFolderId();
        if (destination == null) {
          if (context.mounted) {
            CustomSnackbar.show(context, l10n.moveUndoCanceled);
          }
          return;
        }
      } else {
        destination = picked;
      }
    }

    if (!context.mounted) return;

    final result = await _noteService.moveNote(
      noteId: entry.itemId,
      targetFolderId: destination,
    );
    if (!context.mounted) return;

    if (result == null) {
      CustomSnackbar.showError(context, l10n.noteMoveFailed);
      return;
    }

    _historyService.markUndone(entry.id);
    CustomSnackbar.show(context, l10n.moveUndone);
  }

  static Future<String?> _firstAvailableFolderId() async {
    final rootFolders = await _folderService.loadAllFoldersForParent(null);
    if (rootFolders.isNotEmpty) return rootFolders.first.id;
    return null;
  }
}
