import 'package:equatable/equatable.dart';

/// Represents a folder that contains notes
class Folder extends Equatable {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final String? noteSortOrder;
  final String? subfolderSortOrder;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.noteSortOrder,
    this.subfolderSortOrder,
  });

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
    String? noteSortOrder,
    String? subfolderSortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      noteSortOrder: noteSortOrder ?? this.noteSortOrder,
      subfolderSortOrder: subfolderSortOrder ?? this.subfolderSortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'noteSortOrder': noteSortOrder,
      'subfolderSortOrder': subfolderSortOrder,
    };
  }

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      noteSortOrder: json['noteSortOrder'] as String?,
      subfolderSortOrder: json['subfolderSortOrder'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    parentId,
    createdAt,
    noteSortOrder,
    subfolderSortOrder,
  ];
}
