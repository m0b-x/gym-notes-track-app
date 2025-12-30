import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/custom_markdown_shortcut.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';

class MarkdownSettingsUtils {
  static const String _shortcutsKey = 'markdown_shortcuts';

  static Future<void> saveShortcuts(
    List<CustomMarkdownShortcut> shortcuts,
  ) async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = shortcuts
        .map((shortcut) => shortcut.toJson())
        .toList();
    await db.userSettingsDao.setValue(_shortcutsKey, jsonEncode(shortcutsJson));
  }

  static List<CustomMarkdownShortcut> getDefaultShortcuts() {
    return [
      const CustomMarkdownShortcut(
        id: 'default_bold',
        label: 'Bold',
        iconCodePoint: 0xe238,
        iconFontFamily: 'MaterialIcons',
        beforeText: '**',
        afterText: '**',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_italic',
        label: 'Italic',
        iconCodePoint: 0xe23f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '_',
        afterText: '_',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_header',
        label: 'Headers',
        iconCodePoint: 0xe86f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '# ',
        afterText: '',
        isDefault: true,
        insertType: 'header',
      ),
      const CustomMarkdownShortcut(
        id: 'default_point_list',
        label: 'Point List',
        iconCodePoint: 0xe065,
        iconFontFamily: 'MaterialIcons',
        beforeText: '• ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_strikethrough',
        label: 'Strikethrough',
        iconCodePoint: 0xe257,
        iconFontFamily: 'MaterialIcons',
        beforeText: '~~',
        afterText: '~~',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_bullet_list',
        label: 'Bullet List',
        iconCodePoint: 0xe241,
        iconFontFamily: 'MaterialIcons',
        beforeText: '- ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_numbered_list',
        label: 'Numbered List',
        iconCodePoint: 0xe242,
        iconFontFamily: 'MaterialIcons',
        beforeText: '1. ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_checkbox',
        label: 'Checkbox',
        iconCodePoint: 0xe834,
        iconFontFamily: 'MaterialIcons',
        beforeText: '- [ ] ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_quote',
        label: 'Quote',
        iconCodePoint: 0xe244,
        iconFontFamily: 'MaterialIcons',
        beforeText: '> ',
        afterText: '',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_inline_code',
        label: 'Inline Code',
        iconCodePoint: 0xe86f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '`',
        afterText: '`',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_code_block',
        label: 'Code Block',
        iconCodePoint: 0xe86f,
        iconFontFamily: 'MaterialIcons',
        beforeText: '```\n',
        afterText: '\n```',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_link',
        label: 'Link',
        iconCodePoint: 0xe157,
        iconFontFamily: 'MaterialIcons',
        beforeText: '[',
        afterText: '](url)',
        isDefault: true,
      ),
      const CustomMarkdownShortcut(
        id: 'default_date',
        label: 'Current Date',
        iconCodePoint: 0xe916,
        iconFontFamily: 'MaterialIcons',
        beforeText: '',
        afterText: '',
        isDefault: true,
        insertType: 'date',
      ),
    ];
  }

  static Widget buildShortcutIcon(
    BuildContext context,
    CustomMarkdownShortcut shortcut,
  ) {
    if (shortcut.id == 'default_header') {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: Text(
          'H',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return Icon(
      IconData(shortcut.iconCodePoint, fontFamily: shortcut.iconFontFamily),
    );
  }

  static String getShortcutSubtitle(
    BuildContext context,
    CustomMarkdownShortcut shortcut,
  ) {
    switch (shortcut.insertType) {
      case 'date':
        return AppLocalizations.of(context)!.insertsCurrentDate;
      case 'header':
        return AppLocalizations.of(context)!.opensHeaderMenu;
      default:
        return AppLocalizations.of(
          context,
        )!.beforeAfterText(shortcut.beforeText, shortcut.afterText);
    }
  }

  static Future<List<CustomMarkdownShortcut>> loadShortcuts() async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = await db.userSettingsDao.getValue(_shortcutsKey);

    final defaults = getDefaultShortcuts();

    if (shortcutsJson != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsJson);
      return decoded
          .map((json) => CustomMarkdownShortcut.fromJson(json))
          .toList();
    }

    return defaults;
  }

  static List<CustomMarkdownShortcut> resetToDefault(
    List<CustomMarkdownShortcut> currentShortcuts,
  ) {
    final defaults = getDefaultShortcuts();
    final customShortcuts = currentShortcuts
        .where((s) => !s.isDefault)
        .toList();
    return [...defaults, ...customShortcuts];
  }

  static List<CustomMarkdownShortcut> removeAllCustom(
    List<CustomMarkdownShortcut> currentShortcuts,
  ) {
    return currentShortcuts.where((s) => s.isDefault).toList();
  }
}
