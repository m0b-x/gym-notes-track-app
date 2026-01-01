import 'package:flutter/material.dart';

enum GradientStyle { purple, drawer }

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final double? elevation;
  final double? toolbarHeight;
  final GradientStyle gradientStyle;
  final double purpleAlpha;
  final double drawerAlpha;

  const GradientAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.elevation,
    this.toolbarHeight,
    this.gradientStyle = GradientStyle.purple,
    this.purpleAlpha = 0.85,
    this.drawerAlpha = 0.5,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final colors = switch (gradientStyle) {
      GradientStyle.purple => [
        colorScheme.inversePrimary,
        colorScheme.inversePrimary.withValues(alpha: purpleAlpha),
      ],
      GradientStyle.drawer => [
        colorScheme.primaryContainer,
        colorScheme.primary.withValues(alpha: drawerAlpha),
      ],
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: title,
        actions: actions,
        backgroundColor: Colors.transparent,
        elevation: elevation ?? 0,
      ),
    );
  }
}
