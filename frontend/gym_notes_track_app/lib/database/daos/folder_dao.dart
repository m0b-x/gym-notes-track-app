import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/folders_table.dart';
import '../crdt/hlc.dart';

part 'folder_dao.g.dart';

@DriftAccessor(tables: [Folders])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Future<List<Folder>> getAllFolders({bool includeDeleted = false}) {
    final query = select(folders);
    if (!includeDeleted) {
      query.where((f) => f.isDeleted.equals(false));
    }
    return query.get();
  }

  Future<List<Folder>> getFoldersByParent(
    String? parentId, {
    bool includeDeleted = false,
  }) {
    final query = select(folders);
    if (parentId == null) {
      query.where((f) => f.parentId.isNull());
    } else {
      query.where((f) => f.parentId.equals(parentId));
    }
    if (!includeDeleted) {
      query.where((f) => f.isDeleted.equals(false));
    }
    return query.get();
  }

  Future<Folder?> getFolderById(String id) {
    return (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<int> getFolderCount(
    String? parentId, {
    bool includeDeleted = false,
  }) async {
    final countExp = folders.id.count();
    final query = selectOnly(folders)..addColumns([countExp]);

    if (parentId == null) {
      query.where(folders.parentId.isNull());
    } else {
      query.where(folders.parentId.equals(parentId));
    }

    if (!includeDeleted) {
      query.where(folders.isDeleted.equals(false));
    }

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<List<Folder>> getFoldersPaginated({
    String? parentId,
    required int limit,
    required int offset,
    required FolderSortField sortField,
    required bool ascending,
  }) {
    final query = select(folders);

    if (parentId == null) {
      query.where((f) => f.parentId.isNull());
    } else {
      query.where((f) => f.parentId.equals(parentId));
    }
    query.where((f) => f.isDeleted.equals(false));

    final orderMode = ascending ? OrderingMode.asc : OrderingMode.desc;

    switch (sortField) {
      case FolderSortField.name:
        query.orderBy([
          (f) => OrderingTerm(expression: f.name, mode: orderMode),
        ]);
      case FolderSortField.createdAt:
        query.orderBy([
          (f) => OrderingTerm(expression: f.createdAt, mode: orderMode),
        ]);
      case FolderSortField.updatedAt:
        query.orderBy([
          (f) => OrderingTerm(expression: f.updatedAt, mode: orderMode),
        ]);
    }

    query.limit(limit, offset: offset);
    return query.get();
  }

  Future<Folder> insertFolder(FoldersCompanion folder) async {
    await into(folders).insert(folder);
    return (select(
      folders,
    )..where((f) => f.id.equals(folder.id.value))).getSingle();
  }

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final now = DateTime.now();
    final id = db.generateId();
    final hlc = db.generateHlc();

    final companion = FoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: Value(parentId),
      createdAt: Value(now),
      updatedAt: Value(now),
      hlcTimestamp: Value(hlc),
      deviceId: Value(db.deviceId),
      version: const Value(1),
      isDeleted: const Value(false),
    );

    return insertFolder(companion);
  }

  Future<Folder?> updateFolder({
    required String id,
    String? name,
    String? parentId,
    bool updateParent = false,
  }) async {
    final existing = await getFolderById(id);
    if (existing == null) return null;

    final now = DateTime.now();
    final hlc = db.generateHlc();

    final companion = FoldersCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      parentId: updateParent ? Value(parentId) : const Value.absent(),
      updatedAt: Value(now),
      hlcTimestamp: Value(hlc),
      deviceId: Value(db.deviceId),
      version: Value(existing.version + 1),
    );

    await (update(folders)..where((f) => f.id.equals(id))).write(companion);
    return getFolderById(id);
  }

  Future<void> softDeleteFolder(String id) async {
    final now = DateTime.now();
    final hlc = db.generateHlc();

    final existing = await getFolderById(id);
    if (existing == null) return;

    await (update(folders)..where((f) => f.id.equals(id))).write(
      FoldersCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
        hlcTimestamp: Value(hlc),
        deviceId: Value(db.deviceId),
        version: Value(existing.version + 1),
      ),
    );
  }

  Future<void> hardDeleteFolder(String id) async {
    await (delete(folders)..where((f) => f.id.equals(id))).go();
  }

  Future<List<String>> getAllDescendantIds(String folderId) async {
    final descendants = <String>[];
    final directChildren = await getFoldersByParent(folderId);

    for (final child in directChildren) {
      descendants.add(child.id);
      descendants.addAll(await getAllDescendantIds(child.id));
    }

    return descendants;
  }

  Future<void> softDeleteFolderWithDescendants(String folderId) async {
    final descendantIds = await getAllDescendantIds(folderId);
    descendantIds.add(folderId);

    for (final id in descendantIds) {
      await softDeleteFolder(id);
    }
  }

  Future<List<Folder>> getFoldersSince(String hlcTimestamp) {
    return (select(
      folders,
    )..where((f) => f.hlcTimestamp.isBiggerThanValue(hlcTimestamp))).get();
  }

  Future<void> mergeFolder(Folder remote) async {
    final local = await getFolderById(remote.id);

    if (local == null) {
      await into(folders).insert(
        FoldersCompanion(
          id: Value(remote.id),
          name: Value(remote.name),
          parentId: Value(remote.parentId),
          createdAt: Value(remote.createdAt),
          updatedAt: Value(remote.updatedAt),
          hlcTimestamp: Value(remote.hlcTimestamp),
          deviceId: Value(remote.deviceId),
          version: Value(remote.version),
          isDeleted: Value(remote.isDeleted),
          deletedAt: Value(remote.deletedAt),
        ),
      );
      return;
    }

    final localHlc = HlcTimestamp.parse(local.hlcTimestamp);
    final remoteHlc = HlcTimestamp.parse(remote.hlcTimestamp);

    if (remoteHlc > localHlc) {
      await (update(folders)..where((f) => f.id.equals(remote.id))).write(
        FoldersCompanion(
          name: Value(remote.name),
          parentId: Value(remote.parentId),
          updatedAt: Value(remote.updatedAt),
          hlcTimestamp: Value(remote.hlcTimestamp),
          deviceId: Value(remote.deviceId),
          version: Value(remote.version),
          isDeleted: Value(remote.isDeleted),
          deletedAt: Value(remote.deletedAt),
        ),
      );
      db.hlc.update(remoteHlc);
    }
  }
}

enum FolderSortField { name, createdAt, updatedAt }
