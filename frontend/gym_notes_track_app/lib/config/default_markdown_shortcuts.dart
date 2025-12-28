import '../models/custom_markdown_shortcut.dart';

class DefaultMarkdownShortcuts {
  static List<CustomMarkdownShortcut> get shortcuts => [
    const CustomMarkdownShortcut(
      id: 'default_bold',
      label: 'Bold',
      iconCodePoint: 0xe238, // Icons.format_bold
      iconFontFamily: 'MaterialIcons',
      beforeText: '**',
      afterText: '**',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_italic',
      label: 'Italic',
      iconCodePoint: 0xe23f, // Icons.format_italic
      iconFontFamily: 'MaterialIcons',
      beforeText: '_',
      afterText: '_',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_header',
      label: 'Headers',
      iconCodePoint: 0xe264, // Icons.title
      iconFontFamily: 'MaterialIcons',
      beforeText: '# ',
      afterText: '',
      isDefault: true,
      insertType: 'header',
    ),
    const CustomMarkdownShortcut(
      id: 'default_point_list',
      label: 'Point List',
      iconCodePoint: 0xe061, // Icons.fiber_manual_record (bullet point)
      iconFontFamily: 'MaterialIcons',
      beforeText: '• ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_strikethrough',
      label: 'Strikethrough',
      iconCodePoint: 0xe246, // Icons.format_strikethrough
      iconFontFamily: 'MaterialIcons',
      beforeText: '~~',
      afterText: '~~',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_bullet_list',
      label: 'Bullet List',
      iconCodePoint: 0xe241, // Icons.format_list_bulleted
      iconFontFamily: 'MaterialIcons',
      beforeText: '- ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_numbered_list',
      label: 'Numbered List',
      iconCodePoint: 0xe242, // Icons.format_list_numbered
      iconFontFamily: 'MaterialIcons',
      beforeText: '1. ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_checkbox',
      label: 'Checkbox',
      iconCodePoint: 0xe834, // Icons.check_box_outline_blank
      iconFontFamily: 'MaterialIcons',
      beforeText: '- [ ] ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_quote',
      label: 'Quote',
      iconCodePoint: 0xe244, // Icons.format_quote
      iconFontFamily: 'MaterialIcons',
      beforeText: '> ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_inline_code',
      label: 'Inline Code',
      iconCodePoint: 0xe86f, // Icons.code
      iconFontFamily: 'MaterialIcons',
      beforeText: '`',
      afterText: '`',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_code_block',
      label: 'Code Block',
      iconCodePoint: 0xf054, // Icons.integration_instructions (code file)
      iconFontFamily: 'MaterialIcons',
      beforeText: '```\n',
      afterText: '\n```',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_link',
      label: 'Link',
      iconCodePoint: 0xe157, // Icons.insert_link
      iconFontFamily: 'MaterialIcons',
      beforeText: '[',
      afterText: '](url)',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_checked_checkbox',
      label: 'Checked Checkbox',
      iconCodePoint: 0xe834, // Icons.check_box
      iconFontFamily: 'MaterialIcons',
      beforeText: '- [x] ',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_table',
      label: 'Table',
      iconCodePoint: 0xe8ef, // Icons.table_chart
      iconFontFamily: 'MaterialIcons',
      beforeText: '| Header | Header |\n| --- | --- |\n| ',
      afterText: ' |',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_horizontal_rule',
      label: 'Horizontal Rule',
      iconCodePoint: 0xf108, // Icons.horizontal_rule
      iconFontFamily: 'MaterialIcons',
      beforeText: '\n---\n',
      afterText: '',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_image',
      label: 'Image',
      iconCodePoint: 0xe3f4, // Icons.image
      iconFontFamily: 'MaterialIcons',
      beforeText: '![',
      afterText: '](url)',
      isDefault: true,
    ),
    const CustomMarkdownShortcut(
      id: 'default_date',
      label: 'Current Date',
      iconCodePoint: 0xe916, // Icons.today
      iconFontFamily: 'MaterialIcons',
      beforeText: '',
      afterText: '',
      isDefault: true,
      insertType: 'date',
    ),
  ];
}
