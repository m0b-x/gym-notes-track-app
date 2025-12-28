import 'package:equatable/equatable.dart';

class NoteMetadata extends Equatable {
  final String id;
  final String folderId;
  final String title;
  final String preview;
  final int contentLength;
  final int chunkCount;
  final bool isCompressed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteMetadata({
    required this.id,
    required this.folderId,
    required this.title,
    required this.preview,
    required this.contentLength,
    required this.chunkCount,
    required this.isCompressed,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteMetadata copyWith({
    String? id,
    String? folderId,
    String? title,
    String? preview,
    int? contentLength,
    int? chunkCount,
    bool? isCompressed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteMetadata(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      contentLength: contentLength ?? this.contentLength,
      chunkCount: chunkCount ?? this.chunkCount,
      isCompressed: isCompressed ?? this.isCompressed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folderId': folderId,
      'title': title,
      'preview': preview,
      'contentLength': contentLength,
      'chunkCount': chunkCount,
      'isCompressed': isCompressed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteMetadata.fromJson(Map<String, dynamic> json) {
    return NoteMetadata(
      id: json['id'] as String,
      folderId: json['folderId'] as String,
      title: json['title'] as String,
      preview: json['preview'] as String? ?? '',
      contentLength: json['contentLength'] as int? ?? 0,
      chunkCount: json['chunkCount'] as int? ?? 1,
      isCompressed: json['isCompressed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static String generatePreview(String content, {int maxLength = 200}) {
    if (content.isEmpty) return '';

    final cleaned = content
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length <= maxLength) return cleaned;

    return '${cleaned.substring(0, maxLength)}...';
  }

  @override
  List<Object?> get props => [
    id,
    folderId,
    title,
    preview,
    contentLength,
    chunkCount,
    isCompressed,
    createdAt,
    updatedAt,
  ];
}

class LazyNote extends Equatable {
  final NoteMetadata metadata;
  final String? _loadedContent;
  final bool isContentLoaded;

  const LazyNote({
    required this.metadata,
    String? content,
    this.isContentLoaded = false,
  }) : _loadedContent = content;

  String get id => metadata.id;
  String get folderId => metadata.folderId;
  String get title => metadata.title;
  String get preview => metadata.preview;
  int get contentLength => metadata.contentLength;
  DateTime get createdAt => metadata.createdAt;
  DateTime get updatedAt => metadata.updatedAt;

  String? get content => _loadedContent;

  LazyNote withContent(String content) {
    return LazyNote(
      metadata: metadata,
      content: content,
      isContentLoaded: true,
    );
  }

  LazyNote copyWith({
    NoteMetadata? metadata,
    String? content,
    bool? isContentLoaded,
  }) {
    return LazyNote(
      metadata: metadata ?? this.metadata,
      content: content ?? _loadedContent,
      isContentLoaded: isContentLoaded ?? this.isContentLoaded,
    );
  }

  @override
  List<Object?> get props => [metadata, _loadedContent, isContentLoaded];
}

class PaginatedNotes extends Equatable {
  final List<NoteMetadata> notes;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final bool hasMore;
  final bool isLoading;

  const PaginatedNotes({
    required this.notes,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.hasMore,
    this.isLoading = false,
  });

  PaginatedNotes copyWith({
    List<NoteMetadata>? notes,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    bool? hasMore,
    bool? isLoading,
  }) {
    return PaginatedNotes(
      notes: notes ?? this.notes,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static PaginatedNotes empty() {
    return const PaginatedNotes(
      notes: [],
      currentPage: 0,
      totalPages: 0,
      totalCount: 0,
      hasMore: false,
    );
  }

  @override
  List<Object?> get props => [
    notes,
    currentPage,
    totalPages,
    totalCount,
    hasMore,
    isLoading,
  ];
}
