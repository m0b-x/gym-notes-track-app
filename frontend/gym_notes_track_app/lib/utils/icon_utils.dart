import 'package:flutter/material.dart';

/// Utility class for icon handling that supports tree-shaking.
///
/// Flutter's tree-shaking cannot work with dynamic IconData creation
/// (e.g., `IconData(codePoint, fontFamily: 'MaterialIcons')`).
/// This class provides a mapping from code points to constant icon references,
/// allowing Flutter to tree-shake unused icons while still supporting
/// stored icon code points in the database.
class IconUtils {
  IconUtils._();

  /// Map of icon code points to their constant IconData references.
  /// Add new icons here as needed for the app.
  static const Map<int, IconData> _iconMap = {
    // Format icons
    0xe238: Icons.format_bold, // Bold
    0xe23f: Icons.format_italic, // Italic
    0xe257: Icons.strikethrough_s, // Strikethrough

    // List icons
    0xe065: Icons.circle, // Point list (bullet)
    0xe241: Icons.format_list_bulleted, // Bullet list
    0xe242: Icons.format_list_numbered, // Numbered list

    // Text icons
    0xe86f: Icons.tag, // Tag (used for headers, code)
    0xe834: Icons.check_box_outline_blank, // Checkbox
    0xe244: Icons.format_quote, // Quote

    // Other icons
    0xe157: Icons.link, // Link
    0xe916: Icons.today, // Date

    // Icons from AvailableIcons (icon picker)
    0xe8e8: Icons.star,
    0xe87c: Icons.favorite,
    0xe1f6: Icons.lightbulb,
    0xe002: Icons.warning,
    0xe889: Icons.info,
    0xe86c: Icons.check_circle,
    0xe22a: Icons.highlight,
    0xe40a: Icons.palette,
    0xe043: Icons.bookmark,
    0xe892: Icons.label,
    0xe14d: Icons.flag,
    0xe6df: Icons.push_pin,
    0xe838: Icons.note,
    0xe80c: Icons.description,
    0xe866: Icons.article,
    0xf1b7: Icons.menu_book,
    0xe02e: Icons.attachment,
    0xe54a: Icons.local_offer,
    0xe8de: Icons.style,
    0xeb43: Icons.fitness_center,

    // Common picker icons
    0xe0c9: Icons.email,
    0xe0cd: Icons.phone,
    0xe55f: Icons.location_on,
    0xe8b8: Icons.schedule,
    0xe7fd: Icons.person,
    0xe8dc: Icons.settings,
    0xe88a: Icons.home,
    0xe3e4: Icons.image,
    0xe02c: Icons.music_note,
    0xe04b: Icons.videocam,
    0xe873: Icons.edit,
    0xe872: Icons.delete,
    0xe5cd: Icons.close,
    0xe5ca: Icons.check,
    0xe145: Icons.add,
    0xe15b: Icons.remove,
    0xe8b6: Icons.search,
    0xe5d2: Icons.menu,
    0xe5c4: Icons.arrow_back,
    0xe5c8: Icons.arrow_forward,
    0xe5db: Icons.arrow_upward,
    0xe5c5: Icons.arrow_downward,
    0xe5d0: Icons.refresh,
    0xe161: Icons.save,
    0xe2c4: Icons.share,
    0xe14f: Icons.content_copy,
    0xe14e: Icons.content_cut,
    0xe876: Icons.help,
    0xe5ce: Icons.expand_more,
    0xe5cf: Icons.expand_less,
    0xe8f4: Icons.visibility,
    0xe8f5: Icons.visibility_off,
    0xe897: Icons.lock,
    0xe898: Icons.lock_open,
    0xe7f5: Icons.chat,
    0xe63e: Icons.comment,
    0xe2c7: Icons.folder,
    0xe24d: Icons.insert_drive_file,
    0xe2bc: Icons.cloud,
    0xe2c0: Icons.cloud_download,
    0xe2c3: Icons.cloud_upload,
    0xef42: Icons.download,
    0xf090: Icons.upload,
    0xe3af: Icons.camera_alt,
    0xe3f4: Icons.photo,
    0xe417: Icons.play_arrow,
    0xe034: Icons.pause,
    0xe047: Icons.stop,
    0xe8b1: Icons.fast_forward,
    0xe020: Icons.fast_rewind,
    0xe037: Icons.skip_next,
    0xe045: Icons.skip_previous,
    0xe04d: Icons.volume_up,
    0xe04e: Icons.volume_off,
    0xe63f: Icons.brightness_high,
    0xe3ac: Icons.brightness_low,
    0xe1a4: Icons.wifi,
    0xe1ba: Icons.bluetooth,
    0xe325: Icons.battery_full,
    0xe0df: Icons.signal_cellular_4_bar,
    0xefd3: Icons.dark_mode,
    0xe518: Icons.light_mode,
    0xe000: Icons.error,
  };

  /// Gets an IconData from a code point.
  /// If the code point is not in the map, returns a fallback icon.
  static IconData getIcon(int codePoint, {IconData fallback = Icons.tag}) {
    return _iconMap[codePoint] ?? fallback;
  }

  /// Gets an IconData from code point and font family.
  /// This is the replacement for dynamic IconData creation.
  /// Only MaterialIcons are supported for tree-shaking.
  static IconData getIconFromData(int codePoint, String fontFamily) {
    // All icons should be MaterialIcons and in the map
    // Return fallback for any unsupported icon to maintain tree-shaking
    return getIcon(codePoint);
  }

  /// Checks if an icon code point is in the supported map.
  static bool isSupported(int codePoint) {
    return _iconMap.containsKey(codePoint);
  }

  /// Gets all supported icons as a list for icon pickers.
  static List<IconData> get supportedIcons => _iconMap.values.toList();

  /// Gets all supported icon code points.
  static List<int> get supportedCodePoints => _iconMap.keys.toList();
}
