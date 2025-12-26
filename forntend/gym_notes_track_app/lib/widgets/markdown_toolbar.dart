import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/custom_markdown_shortcut.dart';
import '../l10n/app_localizations.dart';

class MarkdownToolbar extends StatefulWidget {
  final List<CustomMarkdownShortcut> shortcuts;
  final bool isPreviewMode;
  final bool canUndo;
  final bool canRedo;
  final double previewFontSize;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDecreaseFontSize;
  final VoidCallback onIncreaseFontSize;
  final VoidCallback onSettings;
  final Function(CustomMarkdownShortcut) onShortcutPressed;
  final Future<void> Function(int draggedIndex, int targetIndex)
  onReorderComplete;

  const MarkdownToolbar({
    super.key,
    required this.shortcuts,
    required this.isPreviewMode,
    required this.canUndo,
    required this.canRedo,
    required this.previewFontSize,
    required this.onUndo,
    required this.onRedo,
    required this.onDecreaseFontSize,
    required this.onIncreaseFontSize,
    required this.onSettings,
    required this.onShortcutPressed,
    required this.onReorderComplete,
  });

  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends State<MarkdownToolbar> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _buttonKeys = {};
  Timer? _autoScrollTimer;
  int? _draggingIndex;
  int? _hoveringIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    _buttonKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleShortcuts = widget.shortcuts
        .where((s) => s.isVisible)
        .toList();

    final keysToRemove = _buttonKeys.keys
        .where((key) => key >= visibleShortcuts.length)
        .toList();
    for (final key in keysToRemove) {
      _buttonKeys.remove(key);
    }
    for (int i = 0; i < visibleShortcuts.length; i++) {
      _buttonKeys.putIfAbsent(i, () => GlobalKey());
    }

    final List<Widget> shortcutWidgets = [];
    for (int index = 0; index < visibleShortcuts.length; index++) {
      final shortcut = visibleShortcuts[index];
      final isDragging = _draggingIndex == index;
      final isHovering = _hoveringIndex == index;

      if (isHovering && _draggingIndex != null && !isDragging) {
        shortcutWidgets.add(_DropIndicator(key: ValueKey('drop_$index')));
      }

      shortcutWidgets.add(
        _DraggableButton(
          key: _buttonKeys[index],
          shortcut: shortcut,
          index: index,
          isDragging: isDragging,
          onTap: () => widget.onShortcutPressed(shortcut),
          onDragStarted: () => _onDragStarted(index),
          onDragUpdate: _onDragUpdate,
          onDragEnd: _onDragEnd,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isPreviewMode) ...[
              ...shortcutWidgets,
              const SizedBox(width: 8),
            ],
            _ToolbarButton(
              icon: Icons.undo,
              tooltip: AppLocalizations.of(context)!.undo,
              onPressed: widget.canUndo ? widget.onUndo : null,
            ),
            _ToolbarButton(
              icon: Icons.redo,
              tooltip: AppLocalizations.of(context)!.redo,
              onPressed: widget.canRedo ? widget.onRedo : null,
            ),
            if (widget.isPreviewMode) ...[
              const SizedBox(width: 8),
              _ToolbarButton(
                icon: Icons.text_decrease,
                tooltip: AppLocalizations.of(context)!.decreaseFontSize,
                onPressed: widget.onDecreaseFontSize,
              ),
              _ToolbarButton(
                icon: Icons.text_increase,
                tooltip: AppLocalizations.of(context)!.increaseFontSize,
                onPressed: widget.onIncreaseFontSize,
              ),
            ],
            const SizedBox(width: 16),
            _ToolbarButton(
              icon: Icons.settings,
              tooltip: AppLocalizations.of(context)!.settings,
              onPressed: widget.onSettings,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _onDragStarted(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingIndex = index;
      _hoveringIndex = null;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    
    final globalPosition = details.globalPosition;
    _updateHoverIndex(globalPosition);
    _handleAutoScroll(globalPosition);
  }

  void _onDragEnd(DraggableDetails details) async {
    _stopAutoScroll();

    final draggedIndex = _draggingIndex;
    final targetIndex = _hoveringIndex;

    setState(() {
      _draggingIndex = null;
      _hoveringIndex = null;
    });

    if (draggedIndex != null &&
        targetIndex != null &&
        draggedIndex != targetIndex) {
      await widget.onReorderComplete(draggedIndex, targetIndex);
    }
  }

  void _updateHoverIndex(Offset globalPosition) {
    if (!mounted) return;

    final visibleShortcuts = widget.shortcuts
        .where((s) => s.isVisible)
        .toList();

    int? newHoverIndex;
    for (int i = 0; i < visibleShortcuts.length; i++) {
      if (i == _draggingIndex) continue;

      final key = _buttonKeys[i];
      if (key?.currentContext?.mounted != true) continue;

      final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) continue;

      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final buttonSize = renderBox.size;
      final buttonCenter = buttonPosition.dx + buttonSize.width / 2;

      if (globalPosition.dx < buttonCenter) {
        newHoverIndex = i;
        break;
      }
    }

    newHoverIndex ??= visibleShortcuts.length;

    if (newHoverIndex != _hoveringIndex && mounted) {
      setState(() {
        _hoveringIndex = newHoverIndex;
      });
    }
  }

  void _handleAutoScroll(Offset globalPosition) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final screenWidth = MediaQuery.of(context).size.width;
    const edgeThreshold = 80.0;
    const scrollSpeed = 10.0;

    if (localPosition.dx < edgeThreshold) {
      _startAutoScroll(-scrollSpeed);
    } else if (localPosition.dx > screenWidth - edgeThreshold) {
      _startAutoScroll(scrollSpeed);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double scrollDelta) {
    if (_autoScrollTimer != null) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scrollController.hasClients) return;

      final currentOffset = _scrollController.offset;
      final newOffset = currentOffset + scrollDelta;
      final maxScroll = _scrollController.position.maxScrollExtent;

      if (newOffset >= 0 && newOffset <= maxScroll) {
        _scrollController.jumpTo(newOffset);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }
}

class _DropIndicator extends StatelessWidget {
  const _DropIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.dropPosition,
      child: Container(
        width: 4,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DraggableButton extends StatelessWidget {
  final CustomMarkdownShortcut shortcut;
  final int index;
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DraggableDetails) onDragEnd;

  const _DraggableButton({
    super.key,
    required this.shortcut,
    required this.index,
    required this.isDragging,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = _buildButtonContent(context);
    final placeholderContent = _buildPlaceholder(context);
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.shortcutButton(shortcut.label),
      hint: l10n.longPressToReorder,
      child: Tooltip(
        message: shortcut.label,
        waitDuration: const Duration(milliseconds: 300),
        child: LongPressDraggable<int>(
          data: index,
          feedback: _buildDragFeedback(context),
          childWhenDragging: placeholderContent,
          onDragStarted: onDragStarted,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          onDraggableCanceled: (_, _) => onDragEnd(
            DraggableDetails(
              wasAccepted: false,
              velocity: Velocity.zero,
              offset: Offset.zero,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: buttonContent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    if (shortcut.id == 'default_header') {
      return Text(
        'H',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return Icon(
      IconData(shortcut.iconCodePoint, fontFamily: shortcut.iconFontFamily),
      size: 24,
      color: Theme.of(context).iconTheme.color,
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Opacity(
      opacity: 0.3,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: _buildButtonContent(context),
      ),
    );
  }

  Widget _buildDragFeedback(BuildContext context) {
    final feedbackContent = shortcut.id == 'default_header'
        ? Text(
            'H',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Icon(
            IconData(
              shortcut.iconCodePoint,
              fontFamily: shortcut.iconFontFamily,
            ),
            size: 24,
            color: Theme.of(context).colorScheme.onPrimary,
          );

    String tooltipText = shortcut.label;
    if (shortcut.insertType == 'wrap') {
      tooltipText = '${shortcut.beforeText}text${shortcut.afterText}';
    } else if (shortcut.insertType == 'date') {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      tooltipText = '${shortcut.beforeText}$formattedDate${shortcut.afterText}';
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: feedbackContent,
          ),
          Positioned(
            bottom: 60,
            left: -50,
            right: -50,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tooltipText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Icon(
                icon,
                size: 24,
                color: onPressed == null
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
