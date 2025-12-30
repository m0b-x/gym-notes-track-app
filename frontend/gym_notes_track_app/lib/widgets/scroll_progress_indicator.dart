import 'dart:async';

import 'package:flutter/material.dart';

/// A touch-friendly scroll progress indicator optimized for mobile.
/// Features a wide touch area, always visible, and supports edge swipe.
class ScrollProgressIndicator extends StatefulWidget {
  final ScrollController scrollController;
  final double visibleWidth;
  final double touchAreaWidth;
  final Color? activeColor;
  final Duration animationDuration;

  const ScrollProgressIndicator({
    super.key,
    required this.scrollController,
    this.visibleWidth = 6,
    this.touchAreaWidth = 44, // iOS recommended touch target
    this.activeColor,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<ScrollProgressIndicator> createState() =>
      _ScrollProgressIndicatorState();
}

class _ScrollProgressIndicatorState extends State<ScrollProgressIndicator> {
  bool _isDragging = false;
  bool _isExpanded = false;
  double _thumbHeight = 40;
  double _trackHeight = 0;
  double _maxScroll = 0;
  Timer? _collapseTimer;
  Timer? _metricsCheckTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    // Periodically check for content dimension changes
    _startMetricsCheck();
  }

  void _startMetricsCheck() {
    _metricsCheckTimer?.cancel();
    _metricsCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (widget.scrollController.hasClients) {
        // Use positions (plural) to safely handle multiple attached views
        for (final pos in widget.scrollController.positions) {
          if (pos.hasContentDimensions) {
            final newMaxScroll = pos.maxScrollExtent;
            if (newMaxScroll != _maxScroll) {
              setState(() {
                _maxScroll = newMaxScroll;
              });
            }
            break;
          }
        }
      }
    });
  }

  @override
  void didUpdateWidget(ScrollProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _metricsCheckTimer?.cancel();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Force rebuild to update progress indicator position
    setState(() {});
    // Expand briefly when scrolling
    if (!_isDragging) {
      _expandTemporarily();
    }
  }

  void _expandTemporarily() {
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
    }
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_isDragging) {
        setState(() => _isExpanded = false);
      }
    });
  }

  void _scrollToPosition(double localY) {
    if (!widget.scrollController.hasClients) return;

    // Use positions (plural) to safely handle multiple attached views
    ScrollPosition? activePosition;
    for (final pos in widget.scrollController.positions) {
      if (pos.hasContentDimensions) {
        activePosition = pos;
        _maxScroll = pos.maxScrollExtent;
        break;
      }
    }

    if (activePosition == null || _maxScroll <= 0) return;

    final effectiveTrack = _trackHeight - _thumbHeight;
    final adjustedY = (localY - _thumbHeight / 2).clamp(0.0, effectiveTrack);
    final newProgress = effectiveTrack > 0 ? adjustedY / effectiveTrack : 0.0;
    final newOffset = (newProgress * _maxScroll).clamp(0.0, _maxScroll);

    // Jump to position on the active scroll position
    activePosition.jumpTo(newOffset);
  }

  void _onDragStart(DragStartDetails details) {
    _collapseTimer?.cancel();
    setState(() {
      _isDragging = true;
      _isExpanded = true;
    });
    _scrollToPosition(details.localPosition.dy);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _scrollToPosition(details.localPosition.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _expandTemporarily();
  }

  void _onTap(TapUpDetails details) {
    setState(() => _isExpanded = true);
    _scrollToPosition(details.localPosition.dy);
    _expandTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;

    // Dynamic widths based on state
    final barWidth = _isDragging || _isExpanded
        ? widget.visibleWidth * 1.5
        : widget.visibleWidth;

    // Colors - always visible but more prominent when active
    final thumbColor = _isDragging
        ? baseColor
        : _isExpanded
        ? baseColor.withValues(alpha: 0.8)
        : baseColor.withValues(alpha: 0.5);

    final trackColor = _isDragging || _isExpanded
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return LayoutBuilder(
      builder: (context, constraints) {
        _trackHeight = constraints.maxHeight;
        _thumbHeight = (_trackHeight * 0.15).clamp(30.0, 80.0);
        final maxTop = _trackHeight - _thumbHeight;

        return AnimatedBuilder(
          animation: widget.scrollController,
          builder: (context, child) {
            // Calculate progress directly from scroll controller
            // Use positions (plural) to handle multiple attached scroll views gracefully
            double progress = 0;
            if (widget.scrollController.hasClients) {
              // Get the first position that has content dimensions
              ScrollPosition? activePosition;
              for (final pos in widget.scrollController.positions) {
                if (pos.hasContentDimensions) {
                  activePosition = pos;
                  break;
                }
              }

              if (activePosition != null) {
                final maxScroll = activePosition.maxScrollExtent;
                final currentOffset = activePosition.pixels;
                _maxScroll = maxScroll; // Update for drag operations

                if (maxScroll > 0) {
                  progress = (currentOffset / maxScroll).clamp(0.0, 1.0);
                }
              }
            }
            final top = progress * maxTop;

            return GestureDetector(
              onTapUp: _onTap,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onHorizontalDragStart: (_) {
                setState(() => _isExpanded = true);
              },
              behavior: HitTestBehavior.translucent,
              child: Container(
                width: widget.touchAreaWidth,
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: widget.animationDuration,
                    curve: Curves.easeOut,
                    width: barWidth,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(barWidth),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: thumbColor,
                              borderRadius: BorderRadius.circular(barWidth),
                              boxShadow: _isDragging
                                  ? [
                                      BoxShadow(
                                        color: baseColor.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A widget that wraps content with a scroll progress indicator on the right.
class ScrollProgressWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;
  final double indicatorWidth;
  final Color? activeColor;

  const ScrollProgressWrapper({
    super.key,
    required this.child,
    this.scrollController,
    this.indicatorWidth = 6,
    this.activeColor,
  });

  @override
  State<ScrollProgressWrapper> createState() => _ScrollProgressWrapperState();
}

class _ScrollProgressWrapperState extends State<ScrollProgressWrapper> {
  late ScrollController _scrollController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: ScrollProgressIndicator(
            scrollController: _scrollController,
            visibleWidth: widget.indicatorWidth,
            activeColor: widget.activeColor,
          ),
        ),
      ],
    );
  }
}
