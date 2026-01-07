import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'scroll_zone_mixin.dart';

/// A modern, reusable note editor widget with smooth scroll zone support.
///
/// Features:
/// - Momentum-based scrolling via right-side touch zone
/// - Haptic feedback on scroll start
/// - Search highlight support via [highlightSpans]
/// - Customizable appearance
class ModernNoteEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double scrollZoneWidth;

  /// Optional highlight spans for search results.
  /// When provided, renders a RichText layer behind the TextField.
  final List<TextSpan>? highlightSpans;

  const ModernNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    this.textStyle,
    this.onChanged,
    this.readOnly = false,
    this.scrollZoneWidth = 80.0,
    this.highlightSpans,
  });

  @override
  State<ModernNoteEditor> createState() => _ModernNoteEditorState();
}

class _ModernNoteEditorState extends State<ModernNoteEditor>
    with SingleTickerProviderStateMixin, ScrollZoneMixin {
  @override
  void initState() {
    super.initState();
    initScrollZone();
  }

  @override
  void dispose() {
    disposeScrollZone();
    super.dispose();
  }

  @override
  ScrollController getScrollController() => widget.scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: widget.highlightSpans != null
                      ? _buildHighlightedEditor(context)
                      : _buildPlainEditor(context),
                ),
              );
            },
          ),
        ),
        buildScrollZone(width: widget.scrollZoneWidth),
      ],
    );
  }

  TextStyle _getTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return widget.textStyle ??
        TextStyle(
          fontSize: 16,
          height: 1.5,
          color: theme.textTheme.bodyLarge?.color,
        );
  }

  Widget _buildPlainEditor(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getTextStyle(context);

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: style,
      cursorColor: theme.colorScheme.primary,
      cursorWidth: 2.5,
      cursorRadius: const Radius.circular(2),
      decoration: _buildInputDecoration(context, style),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildHighlightedEditor(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getTextStyle(context);

    return Stack(
      children: [
        // Highlight layer
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: RichText(
            text: TextSpan(
              style: style.copyWith(color: theme.textTheme.bodyLarge?.color),
              children: widget.highlightSpans,
            ),
          ),
        ),
        // Transparent text field for editing
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: style.copyWith(color: Colors.transparent),
          cursorColor: theme.colorScheme.primary,
          cursorWidth: 2.5,
          cursorRadius: const Radius.circular(2),
          decoration: _buildInputDecoration(context, style),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, TextStyle style) {
    final theme = Theme.of(context);

    return InputDecoration(
      hintText: AppLocalizations.of(context)!.startWriting,
      hintStyle: TextStyle(
        color: theme.hintColor.withValues(alpha: 0.5),
        fontSize: style.fontSize,
        height: style.height,
        fontStyle: FontStyle.italic,
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      filled: false,
    );
  }
}
