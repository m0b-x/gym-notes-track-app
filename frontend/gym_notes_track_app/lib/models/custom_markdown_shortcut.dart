import 'package:equatable/equatable.dart';

import '../constants/json_keys.dart';

class CustomMarkdownShortcut extends Equatable {
  final String id;
  final String label;
  final int iconCodePoint;
  final String iconFontFamily;
  final String beforeText;
  final String afterText;
  final bool isDefault;
  final bool isVisible;
  final String insertType;
  final String? dateFormat;

  const CustomMarkdownShortcut({
    required this.id,
    required this.label,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.beforeText,
    required this.afterText,
    this.isDefault = false,
    this.isVisible = true,
    this.insertType = 'wrap',
    this.dateFormat,
  });

  Map<String, dynamic> toJson() {
    return {
      JsonKeys.id: id,
      JsonKeys.label: label,
      JsonKeys.iconCodePoint: iconCodePoint,
      JsonKeys.iconFontFamily: iconFontFamily,
      JsonKeys.beforeText: beforeText,
      JsonKeys.afterText: afterText,
      JsonKeys.isDefault: isDefault,
      JsonKeys.isVisible: isVisible,
      JsonKeys.insertType: insertType,
      if (dateFormat != null) JsonKeys.dateFormat: dateFormat,
    };
  }

  factory CustomMarkdownShortcut.fromJson(Map<String, dynamic> json) {
    return CustomMarkdownShortcut(
      id: json[JsonKeys.id] as String,
      label: json[JsonKeys.label] as String,
      iconCodePoint: json[JsonKeys.iconCodePoint] as int,
      iconFontFamily: json[JsonKeys.iconFontFamily] as String,
      beforeText: json[JsonKeys.beforeText] as String,
      afterText: json[JsonKeys.afterText] as String,
      isDefault: json[JsonKeys.isDefault] as bool? ?? false,
      isVisible: json[JsonKeys.isVisible] as bool? ?? true,
      insertType: json[JsonKeys.insertType] as String? ?? 'wrap',
      dateFormat: json[JsonKeys.dateFormat] as String?,
    );
  }

  CustomMarkdownShortcut copyWith({
    String? id,
    String? label,
    int? iconCodePoint,
    String? iconFontFamily,
    String? beforeText,
    String? afterText,
    bool? isDefault,
    bool? isVisible,
    String? insertType,
    String? dateFormat,
  }) {
    return CustomMarkdownShortcut(
      id: id ?? this.id,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      beforeText: beforeText ?? this.beforeText,
      afterText: afterText ?? this.afterText,
      isDefault: isDefault ?? this.isDefault,
      isVisible: isVisible ?? this.isVisible,
      insertType: insertType ?? this.insertType,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }

  @override
  List<Object?> get props => [
    id,
    label,
    iconCodePoint,
    iconFontFamily,
    beforeText,
    afterText,
    isDefault,
    isVisible,
    insertType,
    dateFormat,
  ];
}
