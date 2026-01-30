import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Overlay that draws chunk indicators on top of the code editor.
/// Uses the same debug settings as the preview mode for consistency.
/// Only renders visible chunks for performance.
class EditorChunkOverlay extends StatefulWidget {
  /// The scroll controller to track visible area
  final CodeScrollController scrollController;

  /// The editing controller to get line count
  final CodeLineEditingController editingController;

  /// Number of lines per chunk (should match preview mode)
  final int linesPerChunk;

  /// Font size used in the editor
  final double fontSize;

  /// Line height multiplier
  final double lineHeight;

  /// Whether to show colored backgrounds for chunks
  final bool showColors;

  /// Whether to show borders around chunks
  final bool showBorders;

  /// Padding applied to the editor content
  final EdgeInsets editorPadding;

  const EditorChunkOverlay({
    super.key,
    required this.scrollController,
    required this.editingController,
    required this.linesPerChunk,
    required this.fontSize,
    required this.lineHeight,
    required this.showColors,
    required this.showBorders,
    required this.editorPadding,
  });

  @override
  State<EditorChunkOverlay> createState() => _EditorChunkOverlayState();
}

class _EditorChunkOverlayState extends State<EditorChunkOverlay> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.verticalScroller.addListener(_onScroll);
    widget.editingController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    widget.scrollController.verticalScroller.removeListener(_onScroll);
    widget.editingController.removeListener(_onContentChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorChunkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.verticalScroller.removeListener(_onScroll);
      widget.scrollController.verticalScroller.addListener(_onScroll);
    }
    if (oldWidget.editingController != widget.editingController) {
      oldWidget.editingController.removeListener(_onContentChanged);
      widget.editingController.addListener(_onContentChanged);
    }
  }

  void _onScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showColors && !widget.showBorders) {
      return const SizedBox.shrink();
    }

    // Get scroll offset safely
    final scrollOffset = widget.scrollController.verticalScroller.hasClients
        ? widget.scrollController.verticalScroller.offset
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ChunkOverlayPainter(
            scrollOffset: scrollOffset,
            viewportHeight: constraints.maxHeight,
            lineCount: widget.editingController.lineCount,
            linesPerChunk: widget.linesPerChunk,
            lineHeight: widget.fontSize * widget.lineHeight,
            showColors: widget.showColors,
            showBorders: widget.showBorders,
            editorPadding: widget.editorPadding,
          ),
        );
      },
    );
  }
}

/// Custom painter that draws chunk indicators efficiently.
/// Only draws chunks that are visible in the viewport.
class _ChunkOverlayPainter extends CustomPainter {
  final double scrollOffset;
  final double viewportHeight;
  final int lineCount;
  final int linesPerChunk;
  final double lineHeight;
  final bool showColors;
  final bool showBorders;
  final EdgeInsets editorPadding;

  // Same colors as preview mode for consistency
  static const List<Color> _chunkColors = [
    Color(0x40E91E63), // pink
    Color(0x40FF5722), // deep orange
    Color(0x40FF9800), // orange
    Color(0x40FFEB3B), // yellow
    Color(0x4000E676), // green accent
    Color(0x4000BCD4), // cyan
    Color(0x402196F3), // blue
    Color(0x407C4DFF), // deep purple accent
    Color(0x409C27B0), // purple
    Color(0x40F50057), // pink accent
    Color(0x4000E5FF), // cyan accent
    Color(0x4076FF03), // lime accent
  ];

  static const List<Color> _borderColors = [
    Color(0xFFE91E63), // pink
    Color(0xFFFF5722), // deep orange
    Color(0xFFFF9800), // orange
    Color(0xFFFFEB3B), // yellow
    Color(0xFF00E676), // green accent
    Color(0xFF00BCD4), // cyan
    Color(0xFF2196F3), // blue
    Color(0xFF7C4DFF), // deep purple accent
    Color(0xFF9C27B0), // purple
    Color(0xFFF50057), // pink accent
    Color(0xFF00E5FF), // cyan accent
    Color(0xFF76FF03), // lime accent
  ];

  _ChunkOverlayPainter({
    required this.scrollOffset,
    required this.viewportHeight,
    required this.lineCount,
    required this.linesPerChunk,
    required this.lineHeight,
    required this.showColors,
    required this.showBorders,
    required this.editorPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount == 0) return;

    final chunkCount = (lineCount / linesPerChunk).ceil();
    final contentHeight = lineCount * lineHeight;

    // Calculate visible range (with some buffer for smooth scrolling)
    final visibleStart = scrollOffset - lineHeight * 2;
    final visibleEnd = scrollOffset + viewportHeight + lineHeight * 2;

    // Only draw visible chunks
    for (int chunkIndex = 0; chunkIndex < chunkCount; chunkIndex++) {
      final chunkStartLine = chunkIndex * linesPerChunk;
      final chunkEndLine = ((chunkIndex + 1) * linesPerChunk).clamp(
        0,
        lineCount,
      );
      final linesInChunk = chunkEndLine - chunkStartLine;

      // Calculate chunk position in content coordinates
      final chunkTop = chunkStartLine * lineHeight;
      final chunkHeight = linesInChunk * lineHeight;
      final chunkBottom = chunkTop + chunkHeight;

      // Skip if chunk is outside visible area
      if (chunkBottom < visibleStart || chunkTop > visibleEnd) {
        continue;
      }

      // Convert to viewport coordinates
      final viewportTop = chunkTop - scrollOffset + editorPadding.top;
      final viewportBottom = viewportTop + chunkHeight;

      // Clamp to viewport bounds
      final clampedTop = viewportTop.clamp(0.0, size.height);
      final clampedBottom = viewportBottom.clamp(0.0, size.height);

      if (clampedBottom <= clampedTop) continue;

      final colorIndex = chunkIndex % _chunkColors.length;

      final rect = RRect.fromLTRBR(
        editorPadding.left,
        clampedTop,
        size.width - editorPadding.right,
        clampedBottom,
        const Radius.circular(8),
      );

      // Draw background color
      if (showColors) {
        final fillPaint = Paint()
          ..color = _chunkColors[colorIndex]
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rect, fillPaint);
      }

      // Draw border
      if (showBorders) {
        final borderPaint = Paint()
          ..color = _borderColors[colorIndex]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rect, borderPaint);

        // Draw chunk label
        _drawChunkLabel(
          canvas,
          chunkIndex,
          chunkStartLine,
          chunkEndLine,
          clampedTop,
          editorPadding.left,
          colorIndex,
        );
      }
    }
  }

  void _drawChunkLabel(
    Canvas canvas,
    int chunkIndex,
    int startLine,
    int endLine,
    double top,
    double left,
    int colorIndex,
  ) {
    final labelText = 'Chunk $chunkIndex (L${startLine + 1}-$endLine)';

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Label background
    final labelRect = RRect.fromLTRBR(
      left + 4,
      top + 4,
      left + 4 + textPainter.width + 12,
      top + 4 + textPainter.height + 4,
      const Radius.circular(4),
    );

    final labelBgPaint = Paint()
      ..color = _borderColors[colorIndex]
      ..style = PaintingStyle.fill;
    canvas.drawRRect(labelRect, labelBgPaint);

    // Label text
    textPainter.paint(canvas, Offset(left + 10, top + 6));
  }

  @override
  bool shouldRepaint(_ChunkOverlayPainter oldDelegate) {
    return scrollOffset != oldDelegate.scrollOffset ||
        viewportHeight != oldDelegate.viewportHeight ||
        lineCount != oldDelegate.lineCount ||
        linesPerChunk != oldDelegate.linesPerChunk ||
        lineHeight != oldDelegate.lineHeight ||
        showColors != oldDelegate.showColors ||
        showBorders != oldDelegate.showBorders ||
        editorPadding != oldDelegate.editorPadding;
  }
}
