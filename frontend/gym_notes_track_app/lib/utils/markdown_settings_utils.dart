import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/custom_markdown_shortcut.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import 'icon_utils.dart';

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
      CustomMarkdownShortcut(
        id: 'default_bold',
        label: 'Bold',
        iconCodePoint: Icons.format_bold.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '**',
        afterText: '**',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_italic',
        label: 'Italic',
        iconCodePoint: Icons.format_italic.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '_',
        afterText: '_',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_header',
        label: 'Headers',
        iconCodePoint: Icons.tag.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '# ',
        afterText: '',
        isDefault: true,
        insertType: 'header',
      ),
      CustomMarkdownShortcut(
        id: 'default_point_list',
        label: 'Point List',
        iconCodePoint: Icons.circle.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '• ',
        afterText: '',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_strikethrough',
        label: 'Strikethrough',
        iconCodePoint: Icons.strikethrough_s.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '~~',
        afterText: '~~',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_bullet_list',
        label: 'Bullet List',
        iconCodePoint: Icons.format_list_bulleted.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '- ',
        afterText: '',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_numbered_list',
        label: 'Numbered List',
        iconCodePoint: Icons.format_list_numbered.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '1. ',
        afterText: '',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_checkbox',
        label: 'Checkbox',
        iconCodePoint: Icons.check_box_outline_blank.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '- [ ] ',
        afterText: '',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_quote',
        label: 'Quote',
        iconCodePoint: Icons.format_quote.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '> ',
        afterText: '',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_inline_code',
        label: 'Inline Code',
        iconCodePoint: Icons.code.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '`',
        afterText: '`',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_code_block',
        label: 'Code Block',
        iconCodePoint: Icons.code.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '```\n',
        afterText: '\n```',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_link',
        label: 'Link',
        iconCodePoint: Icons.link.codePoint,
        iconFontFamily: 'MaterialIcons',
        beforeText: '[',
        afterText: '](url)',
        isDefault: true,
      ),
      CustomMarkdownShortcut(
        id: 'default_date',
        label: 'Current Date',
        iconCodePoint: Icons.today.codePoint,
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
      IconUtils.getIconFromData(
        shortcut.iconCodePoint,
        shortcut.iconFontFamily,
      ),
    );
  }

  static String getShortcutSubtitle(
    BuildContext context,
    CustomMarkdownShortcut shortcut,
  ) {
    final parts = <String>[];

    switch (shortcut.insertType) {
      case 'date':
        parts.add(AppLocalizations.of(context)!.insertsCurrentDate);

        // Show date offset info if any
        final offset = shortcut.dateOffset;
        if (offset != null && !offset.isEmpty) {
          final offsetParts = <String>[];
          if (offset.days != 0) offsetParts.add('${offset.days}d');
          if (offset.months != 0) offsetParts.add('${offset.months}m');
          if (offset.years != 0) offsetParts.add('${offset.years}y');
          parts.add('(${offsetParts.join(', ')})');
        }
        break;
      case 'header':
        parts.add(AppLocalizations.of(context)!.opensHeaderMenu);
        break;
      default:
        final before = _truncateText(shortcut.beforeText, 15);
        final after = _truncateText(shortcut.afterText, 15);
        parts.add(AppLocalizations.of(context)!.beforeAfterText(before, after));
    }

    // Show repeat info if configured
    final repeatConfig = shortcut.repeatConfig;
    if (repeatConfig != null && repeatConfig.isActive) {
      parts.add('×${repeatConfig.count}');
      if (repeatConfig.incrementDate) {
        parts.add('+date');
      }
    }

    return parts.join(' ');
  }

  static String _truncateText(String text, int maxLength) {
    final escaped = text.replaceAll('\n', '↵').replaceAll('\t', '→');
    if (escaped.length <= maxLength) {
      return escaped;
    }
    return '${escaped.substring(0, maxLength)}…';
  }

  static Future<List<CustomMarkdownShortcut>> loadShortcuts() async {
    final db = await AppDatabase.getInstance();
    final shortcutsJson = await db.userSettingsDao.getValue(_shortcutsKey);

    final defaults = getDefaultShortcuts();
    final defaultsMap = {for (var d in defaults) d.id: d};

    if (shortcutsJson != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsJson);
      final loaded = decoded
          .map((json) => CustomMarkdownShortcut.fromJson(json))
          .toList();

      final migrated = loaded.map((shortcut) {
        if (shortcut.isDefault && defaultsMap.containsKey(shortcut.id)) {
          final defaultShortcut = defaultsMap[shortcut.id]!;
          return shortcut.copyWith(
            iconCodePoint: defaultShortcut.iconCodePoint,
            iconFontFamily: defaultShortcut.iconFontFamily,
          );
        }
        return shortcut;
      }).toList();

      return migrated;
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
