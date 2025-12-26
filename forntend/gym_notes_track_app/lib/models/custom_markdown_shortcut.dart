import 'package:equatable/equatable.dart';

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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'beforeText': beforeText,
      'afterText': afterText,
      'isDefault': isDefault,
      'isVisible': isVisible,
      'insertType': insertType,
    };
  }

  factory CustomMarkdownShortcut.fromJson(Map<String, dynamic> json) {
    return CustomMarkdownShortcut(
      id: json['id'] as String,
      label: json['label'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      iconFontFamily: json['iconFontFamily'] as String,
      beforeText: json['beforeText'] as String,
      afterText: json['afterText'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      insertType: json['insertType'] as String? ?? 'wrap',
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
  ];
}
