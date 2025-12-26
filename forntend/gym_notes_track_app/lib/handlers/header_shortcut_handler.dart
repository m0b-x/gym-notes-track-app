import 'package:flutter/material.dart';
import '../interfaces/markdown_shortcut_handler.dart';
import '../models/custom_markdown_shortcut.dart';
import '../l10n/app_localizations.dart';

class HeaderShortcutHandler implements MarkdownShortcutHandler {
  @override
  void execute({
    required BuildContext context,
    required CustomMarkdownShortcut shortcut,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onTextChanged,
  }) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        16,
        size.height - 300,
        200,
        size.height,
      ),
      items: _buildHeaderMenuItems(context),
    ).then((value) {
      if (value != null) {
        _insertHeader(value, controller, focusNode, onTextChanged);
      }
    });
  }

  List<PopupMenuEntry<String>> _buildHeaderMenuItems(BuildContext context) {
    return [
      PopupMenuItem(
        value: 'h1',
        child: Text(
          AppLocalizations.of(context)!.header1,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      PopupMenuItem(
        value: 'h2',
        child: Text(
          AppLocalizations.of(context)!.header2,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      PopupMenuItem(
        value: 'h3',
        child: Text(
          AppLocalizations.of(context)!.header3,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      PopupMenuItem(
        value: 'h4',
        child: Text(
          AppLocalizations.of(context)!.header4,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      PopupMenuItem(
        value: 'h5',
        child: Text(
          AppLocalizations.of(context)!.header5,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      PopupMenuItem(
        value: 'h6',
        child: Text(
          AppLocalizations.of(context)!.header6,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    ];
  }

  void _insertHeader(
    String headerType,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onTextChanged,
  ) {
    final prefixes = {
      'h1': '# ',
      'h2': '## ',
      'h3': '### ',
      'h4': '#### ',
      'h5': '##### ',
      'h6': '###### ',
    };

    final prefix = prefixes[headerType];
    if (prefix == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    String selectedText = '';
    if (start >= 0 && end >= 0 && start != end) {
      selectedText = text.substring(start, end);
    }

    final newText = text.substring(0, start) + prefix + selectedText + text.substring(end);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + prefix.length + selectedText.length,
      ),
    );

    focusNode.requestFocus();
    onTextChanged();
  }
}
