import 'package:flutter/material.dart';

import 'unified_app_bars.dart';

/// App bar shown while the folder content page is in selection mode.
/// Mirrors [FolderAppBar] styling so the swap is visually seamless.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;

  const SelectionAppBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onSelectAll,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return UnifiedAppBar.main(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: onCancel,
        tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
      ),
      title: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          onPressed: onSelectAll,
        ),
      ],
    );
  }
}
