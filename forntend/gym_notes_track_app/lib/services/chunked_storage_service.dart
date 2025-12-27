import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/compression_utils.dart';

class ContentChunk {
  final String id;
  final String noteId;
  final int index;
  final String content;
  final bool isCompressed;

  const ContentChunk({
    required this.id,
    required this.noteId,
    required this.index,
    required this.content,
    required this.isCompressed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'index': index,
      'content': content,
      'isCompressed': isCompressed,
    };
  }

  factory ContentChunk.fromJson(Map<String, dynamic> json) {
    return ContentChunk(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      index: json['index'] as int,
      content: json['content'] as String,
      isCompressed: json['isCompressed'] as bool? ?? false,
    );
  }
}

class ChunkedStorageService {
  static const String _chunksStorageKey = 'note_chunks';
  static const int defaultChunkSize = 10000;
  static const int compressionThreshold = 5000;

  final int chunkSize;

  ChunkedStorageService({this.chunkSize = defaultChunkSize});

  Future<void> saveContent({
    required String noteId,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingChunks = await _loadAllChunks(prefs);

    existingChunks.removeWhere((chunk) => chunk.noteId == noteId);

    final newChunks = _splitIntoChunks(noteId, content);
    existingChunks.addAll(newChunks);

    await _saveAllChunks(prefs, existingChunks);
  }

  Future<String> loadContent(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final allChunks = await _loadAllChunks(prefs);

    final noteChunks = allChunks
        .where((chunk) => chunk.noteId == noteId)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (noteChunks.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final chunk in noteChunks) {
      if (chunk.isCompressed) {
        buffer.write(CompressionUtils.decompressFromBase64(chunk.content));
      } else {
        buffer.write(chunk.content);
      }
    }

    return buffer.toString();
  }

  Future<String?> loadChunk(String noteId, int chunkIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final allChunks = await _loadAllChunks(prefs);

    final chunk = allChunks.firstWhere(
      (c) => c.noteId == noteId && c.index == chunkIndex,
      orElse: () => ContentChunk(
        id: '',
        noteId: noteId,
        index: chunkIndex,
        content: '',
        isCompressed: false,
      ),
    );

    if (chunk.id.isEmpty) {
      return null;
    }

    if (chunk.isCompressed) {
      return CompressionUtils.decompressFromBase64(chunk.content);
    }

    return chunk.content;
  }

  Future<int> getChunkCount(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final allChunks = await _loadAllChunks(prefs);

    return allChunks.where((chunk) => chunk.noteId == noteId).length;
  }

  Future<void> deleteContent(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingChunks = await _loadAllChunks(prefs);

    existingChunks.removeWhere((chunk) => chunk.noteId == noteId);

    await _saveAllChunks(prefs, existingChunks);
  }

  List<ContentChunk> _splitIntoChunks(String noteId, String content) {
    final chunks = <ContentChunk>[];

    if (content.isEmpty) {
      return chunks;
    }

    int index = 0;
    int position = 0;

    while (position < content.length) {
      final end = (position + chunkSize).clamp(0, content.length);
      final chunkContent = content.substring(position, end);

      final shouldCompress = chunkContent.length > compressionThreshold;
      final processedContent = shouldCompress
          ? CompressionUtils.compressToBase64(chunkContent)
          : chunkContent;

      chunks.add(ContentChunk(
        id: '${noteId}_chunk_$index',
        noteId: noteId,
        index: index,
        content: processedContent,
        isCompressed: shouldCompress,
      ));

      position = end;
      index++;
    }

    return chunks;
  }

  Future<List<ContentChunk>> _loadAllChunks(SharedPreferences prefs) async {
    final chunksString = prefs.getString(_chunksStorageKey);

    if (chunksString == null) {
      return [];
    }

    final List<dynamic> chunksJson = jsonDecode(chunksString);
    return chunksJson
        .map((json) => ContentChunk.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAllChunks(
    SharedPreferences prefs,
    List<ContentChunk> chunks,
  ) async {
    final chunksJson = chunks.map((c) => c.toJson()).toList();
    await prefs.setString(_chunksStorageKey, jsonEncode(chunksJson));
  }

  Future<ContentStats> getContentStats(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final allChunks = await _loadAllChunks(prefs);
    final noteChunks = allChunks.where((c) => c.noteId == noteId).toList();

    int totalSize = 0;
    int compressedSize = 0;
    int compressedChunks = 0;

    for (final chunk in noteChunks) {
      compressedSize += chunk.content.length;
      if (chunk.isCompressed) {
        compressedChunks++;
      }
    }

    final content = await loadContent(noteId);
    totalSize = content.length;

    return ContentStats(
      noteId: noteId,
      totalSize: totalSize,
      compressedSize: compressedSize,
      chunkCount: noteChunks.length,
      compressedChunkCount: compressedChunks,
    );
  }
}

class ContentStats {
  final String noteId;
  final int totalSize;
  final int compressedSize;
  final int chunkCount;
  final int compressedChunkCount;

  const ContentStats({
    required this.noteId,
    required this.totalSize,
    required this.compressedSize,
    required this.chunkCount,
    required this.compressedChunkCount,
  });

  double get compressionRatio =>
      totalSize > 0 ? compressedSize / totalSize : 1.0;
}
