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
  final Function(List<CustomMarkdownShortcut>)? onReorderComplete;
  final bool showSettings;
  final bool showBackground;
  final bool showReorder;

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
    this.onReorderComplete,
    this.showSettings = true,
    this.showBackground = true,
    this.showReorder = true,
  });

  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends State<MarkdownToolbar> {
  bool _isReorderMode = false;
  late List<CustomMarkdownShortcut> _reorderableShortcuts;

  @override
  void initState() {
    super.initState();
    _reorderableShortcuts = List.from(widget.shortcuts);
  }

  @override
  void didUpdateWidget(MarkdownToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReorderMode) {
      _reorderableShortcuts = List.from(widget.shortcuts);
    }
  }

  void _enterReorderMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isReorderMode = true;
      _reorderableShortcuts = List.from(widget.shortcuts);
    });
  }

  void _exitReorderMode() {
    HapticFeedback.lightImpact();
    widget.onReorderComplete?.call(_reorderableShortcuts);
    setState(() {
      _isReorderMode = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _reorderableShortcuts.removeAt(oldIndex);
      _reorderableShortcuts.insert(newIndex, item);
    });
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isReorderMode) {
      return _buildReorderMode(context);
    }
    return _buildNormalMode(context);
  }

  Widget _buildNormalMode(BuildContext context) {
    final visibleShortcuts = widget.shortcuts
        .where((s) => s.isVisible)
        .toList();

    return Container(
      decoration: widget.showBackground
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            )
          : null,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isPreviewMode) ...[
              ...visibleShortcuts.map(
                (shortcut) => _ShortcutButton(
                  shortcut: shortcut,
                  onTap: () {
                    if (shortcut.id == 'default_header') {
                      _showHeaderMenu(context);
                    } else {
                      widget.onShortcutPressed(shortcut);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildVerticalDivider(context),
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
            if (widget.showReorder &&
                !widget.isPreviewMode &&
                widget.onReorderComplete != null)
              _ToolbarButton(
                icon: Icons.swap_horiz,
                tooltip: AppLocalizations.of(context)!.reorderShortcuts,
                onPressed: _enterReorderMode,
              ),
            if (widget.showSettings)
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

  void _showHeaderMenu(BuildContext context) {
    final headerShortcuts = List.generate(6, (i) {
      final level = i + 1;
      return CustomMarkdownShortcut(
        id: 'header_level_$level',
        label: 'H$level',
        iconCodePoint: 0xe86f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '${'#' * level} ',
        afterText: '',
        insertType: 'header',
      );
    });

    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<CustomMarkdownShortcut>(
      context: context,
      position: position,
      items: headerShortcuts.map((s) {
        final level = s.label.substring(1);
        return PopupMenuItem<CustomMarkdownShortcut>(
          value: s,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Header $level'), Text(s.beforeText.trim())],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        widget.onShortcutPressed(selected);
      }
    });
  }

  Widget _buildReorderMode(BuildContext context) {
    final visibleShortcuts = _reorderableShortcuts
        .where((s) => s.isVisible)
        .toList();

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.reorderShortcuts,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _exitReorderMode,
                  child: Text(AppLocalizations.of(context)!.doneReordering),
                ),
              ],
            ),
          ),
          HorizontalReorderableList(
            itemCount: visibleShortcuts.length,
            onReorder: (oldIndex, newIndex) {
              final oldFullIndex = _reorderableShortcuts.indexOf(
                visibleShortcuts[oldIndex],
              );
              final newFullIndex = newIndex >= visibleShortcuts.length
                  ? _reorderableShortcuts.indexOf(visibleShortcuts.last) + 1
                  : _reorderableShortcuts.indexOf(visibleShortcuts[newIndex]);
              _onReorder(oldFullIndex, newFullIndex);
            },
            itemBuilder: (context, index) =>
                _ReorderableShortcutItem(shortcut: visibleShortcuts[index]),
          ),
        ],
      ),
    );
  }
}

class HorizontalReorderableList extends StatefulWidget {
  final int itemCount;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemsPerRow;

  const HorizontalReorderableList({
    super.key,
    required this.itemCount,
    required this.onReorder,
    required this.itemBuilder,
    this.itemsPerRow = 3,
  });

  @override
  State<HorizontalReorderableList> createState() =>
      _HorizontalReorderableListState();
}

class _HorizontalReorderableListState extends State<HorizontalReorderableList> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  Timer? _autoScrollTimer;
  int? _draggingIndex;
  int? _targetIndex;

  static const double _edgeScrollThreshold = 50.0;
  static const double _autoScrollSpeed = 8.0;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateTargetIndex(details.globalPosition);
    _handleAutoScroll(details.globalPosition);
  }

  void _updateTargetIndex(Offset globalPosition) {
    if (!mounted || _draggingIndex == null) return;

    int? newTargetIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < widget.itemCount; i++) {
      if (i == _draggingIndex) continue;

      final key = _itemKeys[i];
      if (key?.currentContext == null) continue;

      final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) continue;

      final itemPosition = renderBox.localToGlobal(Offset.zero);
      final itemSize = renderBox.size;
      final itemCenter = Offset(
        itemPosition.dx + itemSize.width / 2,
        itemPosition.dy + itemSize.height / 2,
      );

      final distance = (globalPosition - itemCenter).distance;
      if (distance < minDistance) {
        minDistance = distance;
        if (globalPosition.dx < itemCenter.dx ||
            (globalPosition.dy < itemCenter.dy &&
                (globalPosition.dx - itemCenter.dx).abs() <
                    itemSize.width / 2)) {
          newTargetIndex = i;
        } else {
          newTargetIndex = i + 1;
        }
      }
    }

    newTargetIndex ??= widget.itemCount;
    newTargetIndex = newTargetIndex.clamp(0, widget.itemCount);

    if (newTargetIndex != _targetIndex && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _targetIndex = newTargetIndex);
    }
  }

  void _handleAutoScroll(Offset globalPosition) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final size = renderBox.size;

    double deltaX = 0;
    double deltaY = 0;

    if (localPosition.dx < _edgeScrollThreshold) {
      deltaX = -_autoScrollSpeed;
    } else if (localPosition.dx > size.width - _edgeScrollThreshold) {
      deltaX = _autoScrollSpeed;
    }

    if (localPosition.dy < _edgeScrollThreshold) {
      deltaY = -_autoScrollSpeed;
    } else if (localPosition.dy > size.height - _edgeScrollThreshold) {
      deltaY = _autoScrollSpeed;
    }

    if (deltaX != 0 || deltaY != 0) {
      _startAutoScroll(deltaX, deltaY);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double deltaX, double deltaY) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (deltaX != 0 && _horizontalScrollController.hasClients) {
        final currentX = _horizontalScrollController.offset;
        final newX = (currentX + deltaX).clamp(
          0.0,
          _horizontalScrollController.position.maxScrollExtent,
        );
        if (newX != currentX) {
          _horizontalScrollController.jumpTo(newX);
        }
      }

      if (deltaY != 0 && _verticalScrollController.hasClients) {
        final currentY = _verticalScrollController.offset;
        final newY = (currentY + deltaY).clamp(
          0.0,
          _verticalScrollController.position.maxScrollExtent,
        );
        if (newY != currentY) {
          _verticalScrollController.jumpTo(newY);
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    for (int i = 0; i < widget.itemCount; i++) {
      _itemKeys.putIfAbsent(i, () => GlobalKey());
    }

    final rows = <List<int>>[];
    for (var i = 0; i < widget.itemCount; i += widget.itemsPerRow) {
      final end = (i + widget.itemsPerRow > widget.itemCount)
          ? widget.itemCount
          : i + widget.itemsPerRow;
      rows.add(List.generate(end - i, (j) => i + j));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final indices = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: rowIndex < rows.length - 1 ? 8 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: indices.asMap().entries.map((itemEntry) {
                    final indexInRow = itemEntry.key;
                    final index = itemEntry.value;
                    final child = widget.itemBuilder(context, index);
                    final isDragging = _draggingIndex == index;
                    final isTarget = _targetIndex == index;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTarget && _draggingIndex != null && !isDragging)
                          Container(
                            width: 4,
                            height: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        DragTarget<int>(
                          key: _itemKeys[index],
                          onWillAcceptWithDetails: (details) =>
                              details.data != index,
                          onAcceptWithDetails: (details) {
                            widget.onReorder(details.data, index);
                            setState(() {
                              _draggingIndex = null;
                              _targetIndex = null;
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            return LongPressDraggable<int>(
                              data: index,
                              onDragStarted: () {
                                HapticFeedback.mediumImpact();
                                setState(() => _draggingIndex = index);
                              },
                              onDragUpdate: _onDragUpdate,
                              onDragEnd: (_) {
                                _stopAutoScroll();
                                setState(() {
                                  _draggingIndex = null;
                                  _targetIndex = null;
                                });
                              },
                              onDraggableCanceled: (_, _) {
                                _stopAutoScroll();
                                setState(() {
                                  _draggingIndex = null;
                                  _targetIndex = null;
                                });
                              },
                              feedback: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).colorScheme.surface,
                                child: child,
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: child,
                              ),
                              child: Opacity(
                                opacity: isDragging ? 0.3 : 1.0,
                                child: child,
                              ),
                            );
                          },
                        ),
                        if (indexInRow < indices.length - 1)
                          const SizedBox(width: 8),
                      ],
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ReorderableShortcutItem extends StatelessWidget {
  final CustomMarkdownShortcut shortcut;

  const _ReorderableShortcutItem({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          _buildIcon(context),
          const SizedBox(width: 8),
          Text(
            shortcut.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    if (shortcut.id == 'default_bold') {
      return Text(
        'B',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    if (shortcut.id == 'default_italic') {
      return Text(
        'I',
        style: TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    if (shortcut.id == 'default_header') {
      return Text(
        'H',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return Icon(
      IconData(shortcut.iconCodePoint, fontFamily: shortcut.iconFontFamily),
      size: 18,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final CustomMarkdownShortcut shortcut;
  final VoidCallback onTap;

  const _ShortcutButton({required this.shortcut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: shortcut.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: _buildButtonContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    if (shortcut.id == 'default_bold') {
      return Text(
        'B',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).iconTheme.color,
        ),
      );
    }
    if (shortcut.id == 'default_italic') {
      return Text(
        'I',
        style: TextStyle(
          fontSize: 20,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).iconTheme.color,
        ),
      );
    }
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
