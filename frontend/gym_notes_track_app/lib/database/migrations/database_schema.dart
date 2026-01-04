import 'package:drift/drift.dart';

abstract class DatabaseSchema {
  static const int currentVersion = 5;

  static const int v1Initial = 1;
  static const int v2UserSettings = 2;
  static const int v3ContentChunksIsDeleted = 3;
  static const int v4ManualOrdering = 4;
  static const int v5FolderSortPreferences = 5;
}

typedef MigrationStep = Future<void> Function(Migrator m, GeneratedDatabase db);

class Migration {
  final int fromVersion;
  final int toVersion;
  final MigrationStep migrate;

  const Migration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  });
}
