import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/note_search_controller.dart';

/// A modern, integrated search bar widget for searching within note content
class NoteSearchBar extends StatefulWidget {
  final NoteSearchController searchController;
  final VoidCallback? onClose;
  final Function(int offset)? onNavigateToMatch;
  final bool showReplaceField;
  final Function(String oldContent, String newContent)? onReplace;

  const NoteSearchBar({
    super.key,
    required this.searchController,
    this.onClose,
    this.onNavigateToMatch,
    this.showReplaceField = false,
    this.onReplace,
  });

  @override
  State<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends State<NoteSearchBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchFieldController;
  late TextEditingController _replaceFieldController;
  late FocusNode _searchFocusNode;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _showReplace = false;

  @override
  void initState() {
    super.initState();
    _searchFieldController = TextEditingController(
      text: widget.searchController.query,
    );
    _replaceFieldController = TextEditingController();
    _searchFocusNode = FocusNode();

    // Slide-in animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    // Focus the search field when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchFieldController.dispose();
    _replaceFieldController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    widget.searchController.search(value);
  }

  void _navigateToCurrentMatch() {
    final match = widget.searchController.currentMatch;
    if (match != null && widget.onNavigateToMatch != null) {
      widget.onNavigateToMatch!(match.start);
    }
  }

  void _goToNextMatch() {
    widget.searchController.nextMatch();
    _navigateToCurrentMatch();
  }

  void _goToPreviousMatch() {
    widget.searchController.previousMatch();
    _navigateToCurrentMatch();
  }

  void _handleClose() async {
    await _animationController.reverse();
    widget.searchController.closeSearch();
    widget.onClose?.call();
  }

  void _replaceCurrent() {
    final result = widget.searchController.replaceCurrentMatch(
      _replaceFieldController.text,
    );
    if (result != null && widget.onReplace != null) {
      widget.onReplace!('', result);
    }
  }

  void _replaceAll() {
    if (!widget.searchController.hasMatches) return;

    final result = widget.searchController.replaceAllMatches(
      _replaceFieldController.text,
    );
    widget.onReplace?.call(_replaceFieldController.text, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: ListenableBuilder(
        listenable: widget.searchController,
        builder: (context, _) {
          final matchCount = widget.searchController.matchCount;
          final currentIndex = widget.searchController.currentMatchIndex;
          final hasMatches = widget.searchController.hasMatches;
          final hasQuery = _searchFieldController.text.isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main search row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        // Search input
                        Expanded(
                          child: _buildSearchField(
                            colorScheme,
                            hasQuery,
                            hasMatches,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Match counter badge
                        if (hasQuery)
                          _buildMatchCounter(
                            colorScheme,
                            hasMatches,
                            currentIndex,
                            matchCount,
                          ),

                        // Navigation & action buttons
                        _buildActionButtons(colorScheme, hasMatches),
                      ],
                    ),
                  ),

                  // Replace row (expandable)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _showReplace && widget.showReplaceField
                        ? _buildReplaceRow(colorScheme, hasMatches)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(
    ColorScheme colorScheme,
    bool hasQuery,
    bool hasMatches,
  ) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _handleClose();
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _goToPreviousMatch();
            } else {
              _goToNextMatch();
            }
          }
        }
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasQuery && !hasMatches
                ? colorScheme.error.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchFieldController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Find in note',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: hasQuery
                ? GestureDetector(
                    onTap: () {
                      _searchFieldController.clear();
                      widget.searchController.search('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 10,
            ),
          ),
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _goToNextMatch(),
        ),
      ),
    );
  }

  Widget _buildMatchCounter(
    ColorScheme colorScheme,
    bool hasMatches,
    int currentIndex,
    int matchCount,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasMatches
            ? colorScheme.primaryContainer.withValues(alpha: 0.7)
            : colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hasMatches ? '${currentIndex + 1}/$matchCount' : 'No results',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: hasMatches
              ? colorScheme.onPrimaryContainer
              : colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, bool hasMatches) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Navigation buttons
        _buildIconButton(
          icon: Icons.expand_less_rounded,
          onPressed: hasMatches ? _goToPreviousMatch : null,
          tooltip: 'Previous',
          colorScheme: colorScheme,
        ),
        _buildIconButton(
          icon: Icons.expand_more_rounded,
          onPressed: hasMatches ? _goToNextMatch : null,
          tooltip: 'Next',
          colorScheme: colorScheme,
        ),

        // Divider
        Container(
          height: 24,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),

        // Options button
        _buildOptionsButton(colorScheme),

        // Close button
        _buildIconButton(
          icon: Icons.close_rounded,
          onPressed: _handleClose,
          tooltip: 'Close',
          colorScheme: colorScheme,
          isClose: true,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required ColorScheme colorScheme,
    bool isClose = false,
  }) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: isEnabled
                  ? (isClose
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary)
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsButton(ColorScheme colorScheme) {
    final caseSensitive = widget.searchController.caseSensitive;
    final useRegex = widget.searchController.useRegex;
    final hasActiveOption = caseSensitive || useRegex || _showReplace;

    return PopupMenuButton<String>(
      icon: Stack(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 20,
            color: hasActiveOption
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          if (hasActiveOption)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      tooltip: 'Options',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case 'case':
            widget.searchController.toggleCaseSensitive();
            break;
          case 'regex':
            widget.searchController.toggleRegex();
            break;
          case 'replace':
            setState(() => _showReplace = !_showReplace);
            break;
        }
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          'case',
          'Match case',
          Icons.text_fields_rounded,
          caseSensitive,
          colorScheme,
        ),
        _buildPopupMenuItem(
          'regex',
          'Use regex',
          Icons.code_rounded,
          useRegex,
          colorScheme,
        ),
        if (widget.showReplaceField)
          _buildPopupMenuItem(
            'replace',
            'Find & Replace',
            Icons.find_replace_rounded,
            _showReplace,
            colorScheme,
          ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String label,
    IconData icon,
    bool isActive,
    ColorScheme colorScheme,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isActive)
            Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildReplaceRow(ColorScheme colorScheme, bool hasMatches) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          // Replace input
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _replaceFieldController,
                decoration: InputDecoration(
                  hintText: 'Replace with',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.find_replace_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Replace buttons
          _buildReplaceButton(
            label: 'Replace',
            onPressed: hasMatches ? _replaceCurrent : null,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 4),
          _buildReplaceButton(
            label: 'All',
            onPressed: hasMatches ? _replaceAll : null,
            colorScheme: colorScheme,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReplaceButton({
    required String label,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
    bool isPrimary = false,
  }) {
    final isEnabled = onPressed != null;

    return Material(
      color: isPrimary && isEnabled ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: !isPrimary
                ? Border.all(
                    color: isEnabled
                        ? colorScheme.outline.withValues(alpha: 0.3)
                        : colorScheme.outline.withValues(alpha: 0.1),
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary && isEnabled
                  ? colorScheme.onPrimary
                  : (isEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }
}
