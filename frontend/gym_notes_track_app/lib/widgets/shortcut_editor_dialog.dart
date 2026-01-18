import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/custom_markdown_shortcut.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/overlay_snackbar.dart';
import '../utils/markdown_settings_utils.dart';
import '../widgets/simple_markdown_preview.dart';
import '../constants/settings_keys.dart';
import '../utils/icon_utils.dart';
import '../widgets/icon_picker_dialog.dart';

class ShortcutEditorDialog extends StatefulWidget {
  final CustomMarkdownShortcut? shortcut;
  final Function(CustomMarkdownShortcut) onSave;

  const ShortcutEditorDialog({super.key, this.shortcut, required this.onSave});

  @override
  State<ShortcutEditorDialog> createState() => _ShortcutEditorDialogState();
}

class _ShortcutEditorDialogState extends State<ShortcutEditorDialog> {
  late TextEditingController _labelController;
  late TextEditingController _beforeController;
  late TextEditingController _afterController;
  late FocusNode _beforeFocusNode;
  late FocusNode _afterFocusNode;
  late IconData _selectedIcon;
  late String _insertType;
  late String _selectedDateFormat;
  static const int _maxChars = 250;
  List<CustomMarkdownShortcut> _shortcuts = [];
  TextEditingController? _activeController;
  FocusNode? _activeFocusNode;
  String _previousBeforeText = '';
  String _previousAfterText = '';
  bool _isProcessingTextChange = false;
  String? _labelError;

  // Advanced mode toggle
  late bool _isAdvancedMode;

  // Date offset state
  late int _dateOffsetDays;
  late int _dateOffsetMonths;
  late int _dateOffsetYears;

  // Repeat config state
  late int _repeatCount;
  late bool _incrementDateOnRepeat;
  late int _dateIncrementDays;
  late int _dateIncrementMonths;
  late int _dateIncrementYears;
  late String _repeatSeparator;

  static const List<String> _dateFormats = [
    'MMMM d, yyyy',
    'MMM d, yyyy',
    'd MMMM yyyy',
    'd MMM yyyy',
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd.MM.yyyy',
    'EEEE d MMMM yyyy',
    'EEEE, MMMM d, yyyy',
    'EEE, MMM d, yyyy',
    'd/M/yy',
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.shortcut?.label ?? '',
    );
    _beforeController = TextEditingController(
      text: widget.shortcut?.beforeText ?? '',
    );
    _afterController = TextEditingController(
      text: widget.shortcut?.afterText ?? '',
    );
    _previousBeforeText = _beforeController.text;
    _previousAfterText = _afterController.text;
    _beforeController.addListener(
      () => _handleTextChange(_beforeController, true),
    );
    _beforeController.addListener(() => setState(() {}));
    _afterController.addListener(
      () => _handleTextChange(_afterController, false),
    );
    _afterController.addListener(() => setState(() {}));
    _beforeFocusNode = FocusNode();
    _afterFocusNode = FocusNode();

    _beforeFocusNode.addListener(() {
      if (_beforeFocusNode.hasFocus && _activeController != _beforeController) {
        setState(() {
          _activeController = _beforeController;
          _activeFocusNode = _beforeFocusNode;
        });
      }
    });
    _afterFocusNode.addListener(() {
      if (_afterFocusNode.hasFocus && _activeController != _afterController) {
        setState(() {
          _activeController = _afterController;
          _activeFocusNode = _afterFocusNode;
        });
      }
    });

    _selectedIcon = widget.shortcut != null
        ? IconUtils.getIconFromData(
            widget.shortcut!.iconCodePoint,
            widget.shortcut!.iconFontFamily,
          )
        : Icons.tag;
    _insertType = widget.shortcut?.insertType ?? 'wrap';
    _selectedDateFormat =
        widget.shortcut?.dateFormat ?? SettingsKeys.defaultDateFormat;

    // Initialize date offset
    final dateOffset = widget.shortcut?.dateOffset;
    _dateOffsetDays = dateOffset?.days ?? 0;
    _dateOffsetMonths = dateOffset?.months ?? 0;
    _dateOffsetYears = dateOffset?.years ?? 0;

    // Initialize repeat config
    final repeatConfig = widget.shortcut?.repeatConfig;
    _repeatCount = repeatConfig?.count ?? 1;
    _incrementDateOnRepeat = repeatConfig?.incrementDate ?? false;
    _dateIncrementDays = repeatConfig?.dateIncrementDays ?? 1;
    _dateIncrementMonths = repeatConfig?.dateIncrementMonths ?? 0;
    _dateIncrementYears = repeatConfig?.dateIncrementYears ?? 0;
    _repeatSeparator = repeatConfig?.separator ?? '\n';

    // Auto-enable advanced mode if any advanced features are configured
    _isAdvancedMode = _hasAdvancedFeatures();

    _loadShortcuts();
  }

  bool _hasAdvancedFeatures() {
    return _repeatCount > 1 ||
        _dateOffsetDays != 0 ||
        _dateOffsetMonths != 0 ||
        _dateOffsetYears != 0;
  }

  void _resetAdvancedFeatures() {
    setState(() {
      _repeatCount = 1;
      _incrementDateOnRepeat = false;
      _dateIncrementDays = 1;
      _dateIncrementMonths = 0;
      _dateIncrementYears = 0;
      _repeatSeparator = '\n';
      _dateOffsetDays = 0;
      _dateOffsetMonths = 0;
      _dateOffsetYears = 0;
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _beforeController.dispose();
    _afterController.dispose();
    _beforeFocusNode.dispose();
    _afterFocusNode.dispose();
    super.dispose();
  }

  void _showIconPicker() async {
    final selectedIcon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerDialog(currentIcon: _selectedIcon),
    );

    if (selectedIcon != null && mounted) {
      setState(() {
        _selectedIcon = selectedIcon;
      });
    }
  }

  Future<void> _loadShortcuts() async {
    final loaded = await MarkdownSettingsUtils.loadShortcuts();
    if (!mounted) return;
    setState(() {
      _shortcuts = loaded;
    });
  }

  void _handleTextChange(TextEditingController controller, bool isBefore) {
    if (_isProcessingTextChange) return;

    final text = controller.text;
    final selection = controller.selection;
    final previousText = isBefore ? _previousBeforeText : _previousAfterText;

    final textLengthIncreased = text.length > previousText.length;
    if (isBefore) {
      _previousBeforeText = text;
    } else {
      _previousAfterText = text;
    }

    if (!textLengthIncreased) return;

    if (selection.baseOffset > 0 &&
        selection.baseOffset <= text.length &&
        text[selection.baseOffset - 1] == '\n') {
      _isProcessingTextChange = true;
      int prevLineStart;
      if (selection.baseOffset < 2) {
        prevLineStart = 0;
      } else {
        prevLineStart = text.lastIndexOf('\n', selection.baseOffset - 2);
        if (prevLineStart == -1) {
          prevLineStart = 0;
        } else {
          prevLineStart++;
        }
      }

      String prevLine = text.substring(prevLineStart, selection.baseOffset - 1);

      if (_isEmptyListItem(prevLine.trim())) {
        final newText =
            text.substring(0, prevLineStart) +
            text.substring(selection.baseOffset);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
        if (isBefore) {
          _previousBeforeText = newText;
        } else {
          _previousAfterText = newText;
        }
        _isProcessingTextChange = false;
        return;
      }

      String? listPrefix = _getListPrefix(prevLine);
      if (listPrefix != null) {
        final beforeCursor = text.substring(0, selection.baseOffset);
        final afterCursor = text.substring(selection.baseOffset);

        if (!afterCursor.startsWith(listPrefix)) {
          final newText = beforeCursor + listPrefix + afterCursor;
          final newOffset = selection.baseOffset + listPrefix.length;

          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newOffset),
          );
          if (isBefore) {
            _previousBeforeText = newText;
          } else {
            _previousAfterText = newText;
          }
        }
      }
      _isProcessingTextChange = false;
    }
  }

  bool _isEmptyListItem(String line) {
    line = line.trim();

    final emptyPatterns = ['•', '-', '- [ ]', '- [x]', '- [X]'];

    for (var pattern in emptyPatterns) {
      if (line == pattern) return true;
    }

    final numberedPattern = RegExp(r'^\d+\.$');
    return numberedPattern.hasMatch(line);
  }

  String? _getListPrefix(String line) {
    line = line.trimLeft();

    if (line.startsWith('• ')) {
      return '• ';
    }

    if (line.startsWith('- ') && !line.startsWith('- [')) {
      return '- ';
    }

    if (line.startsWith('- [ ] ')) {
      return '- [ ] ';
    }
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      return '- [ ] ';
    }

    final numberedMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (numberedMatch != null) {
      final currentNumber = int.parse(numberedMatch.group(1)!);
      return '${currentNumber + 1}. ';
    }

    return null;
  }

  void _handleShortcut(CustomMarkdownShortcut shortcut) {
    if (_activeController == null || _activeFocusNode == null) return;

    final text = _activeController!.text;
    final selection = _activeController!.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) return;

    String newText = text;
    int newCursor = end;

    if (shortcut.insertType == 'date') {
      final now = DateTime.now();
      final formatted = DateFormat(
        shortcut.dateFormat ?? 'yyyy-MM-dd',
      ).format(now);
      final middle = start != end ? text.substring(start, end) : formatted;
      final wrapped = '${shortcut.beforeText}$middle${shortcut.afterText}';
      newText = text.replaceRange(start, end, wrapped);
      newCursor = start + wrapped.length;
    } else if (shortcut.insertType == 'header') {
      final lineStart = text.lastIndexOf('\n', start - 1) + 1;
      int lineEnd = text.indexOf('\n', lineStart);
      if (lineEnd == -1) lineEnd = text.length;
      final lineText = text.substring(lineStart, lineEnd);

      final headerMatch = RegExp(r'^(#{1,6})\s').firstMatch(lineText);
      String newLineText;

      if (headerMatch != null) {
        final currentHashes = headerMatch.group(1)!;
        final textWithoutHeader = lineText.substring(headerMatch.end);

        if (currentHashes.length >= 6) {
          newLineText = textWithoutHeader;
        } else {
          newLineText = '$currentHashes# $textWithoutHeader';
        }
      } else {
        newLineText = '# $lineText';
      }

      newText = text.replaceRange(lineStart, lineEnd, newLineText);
      newCursor = lineStart + newLineText.length;
    } else {
      final before = shortcut.beforeText;
      final after = shortcut.afterText;

      if (start != end) {
        final replaced = '$before${text.substring(start, end)}$after';
        newText = text.replaceRange(start, end, replaced);
        newCursor = start + replaced.length;
      } else {
        final inserted = '$before$after';
        newText = text.replaceRange(start, end, inserted);
        newCursor = start + before.length;
      }
    }

    _activeController!.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _activeFocusNode!.requestFocus();
  }

  void _save() {
    if (_labelController.text.isEmpty) {
      setState(() {
        _labelError = AppLocalizations.of(context)!.labelCannotBeEmpty;
      });
      OverlaySnackbar.show(
        context,
        AppLocalizations.of(context)!.formHasErrors,
      );
      return;
    }

    // Build date offset if any values are set
    DateOffset? dateOffset;
    if (_insertType == 'date' &&
        (_dateOffsetDays != 0 ||
            _dateOffsetMonths != 0 ||
            _dateOffsetYears != 0)) {
      dateOffset = DateOffset(
        days: _dateOffsetDays,
        months: _dateOffsetMonths,
        years: _dateOffsetYears,
      );
    }

    // Build repeat config if repeat count > 1
    RepeatConfig? repeatConfig;
    if (_repeatCount > 1) {
      repeatConfig = RepeatConfig(
        count: _repeatCount,
        incrementDate: _incrementDateOnRepeat,
        dateIncrementDays: _dateIncrementDays,
        dateIncrementMonths: _dateIncrementMonths,
        dateIncrementYears: _dateIncrementYears,
        separator: _repeatSeparator,
      );
    }

    final shortcut = CustomMarkdownShortcut(
      id: widget.shortcut?.id ?? const Uuid().v4(),
      label: _labelController.text,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily ?? 'MaterialIcons',
      beforeText: _beforeController.text,
      afterText: _afterController.text,
      insertType: _insertType,
      dateFormat: _insertType == 'date' ? _selectedDateFormat : null,
      dateOffset: dateOffset,
      repeatConfig: repeatConfig,
      isVisible: widget.shortcut?.isVisible ?? true,
    );

    widget.onSave(shortcut);
    Navigator.pop(context);
  }

  Widget _buildAdvancedModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isAdvancedMode
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAdvancedMode
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune,
            size: 20,
            color: _isAdvancedMode
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.advancedOptions,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _isAdvancedMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.advancedOptionsDescription,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAdvancedMode,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() {
                _isAdvancedMode = value;
                if (!value) {
                  _resetAdvancedFeatures();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDateOffsetRow() {
    return Row(
      children: [
        Expanded(
          child: _buildOffsetField(
            label: AppLocalizations.of(context)!.days,
            value: _dateOffsetDays,
            onChanged: (v) => setState(() => _dateOffsetDays = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildOffsetField(
            label: AppLocalizations.of(context)!.monthsLabel,
            value: _dateOffsetMonths,
            onChanged: (v) => setState(() => _dateOffsetMonths = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildOffsetField(
            label: AppLocalizations.of(context)!.yearsLabel,
            value: _dateOffsetYears,
            onChanged: (v) => setState(() => _dateOffsetYears = v),
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(value - 1),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.remove, size: 18),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value != 0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(value + 1),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRepeatCountRow() {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)!.repeatCount,
          style: TextStyle(fontSize: 14),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _repeatCount > 1 ? () => setState(() => _repeatCount--) : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.remove,
              size: 20,
              color: _repeatCount > 1 ? null : Theme.of(context).disabledColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$_repeatCount×',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _repeatCount > 1
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _repeatCount < 100
              ? () => setState(() => _repeatCount++)
              : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add,
              size: 20,
              color: _repeatCount < 100
                  ? null
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeparatorSelector() {
    final separators = [
      ('\n', AppLocalizations.of(context)!.newLine),
      ('\n\n', AppLocalizations.of(context)!.blankLine),
      ('', AppLocalizations.of(context)!.noSeparator),
      (' ', AppLocalizations.of(context)!.space),
      ('\u00A0', AppLocalizations.of(context)!.nbspSpace),
      (', ', AppLocalizations.of(context)!.comma),
      (' | ', AppLocalizations.of(context)!.pipe),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.separator,
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: separators.map((sep) {
            final isSelected = _repeatSeparator == sep.$1;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _repeatSeparator = sep.$1);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  sep.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateIncrementSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _incrementDateOnRepeat
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.incrementDateOnRepeat,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Switch(
                value: _incrementDateOnRepeat,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _incrementDateOnRepeat = value);
                },
              ),
            ],
          ),
          if (_incrementDateOnRepeat) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.incrementByEachRepeat,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildIncrementField(
                    label: AppLocalizations.of(context)!.days,
                    value: _dateIncrementDays,
                    onChanged: (v) => setState(() => _dateIncrementDays = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildIncrementField(
                    label: AppLocalizations.of(context)!.monthsLabel,
                    value: _dateIncrementMonths,
                    onChanged: (v) => setState(() => _dateIncrementMonths = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildIncrementField(
                    label: AppLocalizations.of(context)!.yearsLabel,
                    value: _dateIncrementYears,
                    onChanged: (v) => setState(() => _dateIncrementYears = v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncrementField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.remove,
                  size: 16,
                  color: value > 0 ? null : Theme.of(context).disabledColor,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: value > 0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(value + 1),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _getPreviewDate() {
    var date = DateTime.now();
    date = DateTime(
      date.year + _dateOffsetYears,
      date.month + _dateOffsetMonths,
      date.day + _dateOffsetDays,
    );
    return date;
  }

  String _generatePreviewText() {
    if (_insertType == 'date') {
      final baseDate = _getPreviewDate();
      final results = <String>[];

      for (int i = 0; i < _repeatCount; i++) {
        var date = baseDate;
        if (_incrementDateOnRepeat && i > 0) {
          date = DateTime(
            date.year + (_dateIncrementYears * i),
            date.month + (_dateIncrementMonths * i),
            date.day + (_dateIncrementDays * i),
          );
        }
        final formatted = DateFormat(_selectedDateFormat).format(date);
        results.add(
          '${_beforeController.text}$formatted${_afterController.text}',
        );
      }

      return results.join(_repeatSeparator);
    } else {
      final single = '${_beforeController.text}text${_afterController.text}';
      if (_repeatCount > 1) {
        return List.filled(_repeatCount, single).join(_repeatSeparator);
      }
      return single;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showToolbar =
        _beforeFocusNode.hasFocus || _afterFocusNode.hasFocus;

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.shortcut == null
              ? AppLocalizations.of(context)!.newShortcut
              : AppLocalizations.of(context)!.editShortcut,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _beforeFocusNode.unfocus();
                    _afterFocusNode.unfocus();
                  },
                  child: SingleChildScrollView(
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.icon),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _showIconPicker,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(_selectedIcon, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.tapToChangeIcon,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _labelController,
                          onChanged: (_) {
                            if (_labelError != null) {
                              setState(() => _labelError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.label,
                            hintText: AppLocalizations.of(context)!.labelHint,
                            border: OutlineInputBorder(),
                            errorText: _labelError,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.insertType),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _insertType,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'wrap',
                              child: Text(
                                AppLocalizations.of(context)!.wrapSelectedText,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'date',
                              child: Text(
                                AppLocalizations.of(context)!.insertCurrentDate,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _insertType = value ?? 'wrap';
                              if (_insertType == 'date') {
                                _beforeController.text = '';
                                _afterController.text = '';
                              }
                            });
                          },
                        ),
                        if (_insertType == 'date') ...[
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.dateFormatSettings,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Material(
                                color: Colors.transparent,
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _dateFormats.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                  itemBuilder: (context, index) {
                                    final format = _dateFormats[index];
                                    final isSelected =
                                        format == _selectedDateFormat;
                                    final formattedDate = DateFormat(
                                      format,
                                    ).format(DateTime.now());
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      selected: isSelected,
                                      selectedTileColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3),
                                      leading: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.outline,
                                        size: 20,
                                      ),
                                      title: Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : null,
                                        ),
                                      ),
                                      subtitle: Text(
                                        format,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(
                                          () => _selectedDateFormat = format,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Advanced mode toggle
                        const SizedBox(height: 16),
                        _buildAdvancedModeToggle(),
                        // Advanced features (date offset and repeat)
                        if (_isAdvancedMode) ...[
                          // Date offset section (only for date insert type)
                          if (_insertType == 'date') ...[
                            const SizedBox(height: 16),
                            _buildSectionHeader(
                              AppLocalizations.of(context)!.dateOffset,
                              Icons.calendar_today,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.dateOffsetDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDateOffsetRow(),
                          ],
                          // Repeat section (for all insert types)
                          const SizedBox(height: 16),
                          _buildSectionHeader(
                            AppLocalizations.of(context)!.repeatSettings,
                            Icons.repeat,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.repeatDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildRepeatCountRow(),
                          if (_repeatCount > 1) ...[
                            const SizedBox(height: 12),
                            _buildSeparatorSelector(),
                            if (_insertType == 'date') ...[
                              const SizedBox(height: 12),
                              _buildDateIncrementSection(),
                            ],
                          ],
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.markdownSpaceWarning,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _beforeController,
                          focusNode: _beforeFocusNode,
                          maxLines: null,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLength: _maxChars,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          decoration: InputDecoration(
                            labelText: _insertType == 'date'
                                ? AppLocalizations.of(context)!.beforeDate
                                : AppLocalizations.of(context)!.markdownStart,
                            hintText: _insertType == 'date'
                                ? AppLocalizations.of(
                                    context,
                                  )!.optionalTextBeforeDate
                                : AppLocalizations.of(
                                    context,
                                  )!.markdownStartHint,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(context)!.charactersCount(
                              _beforeController.text.length,
                              _maxChars,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _afterController,
                          focusNode: _afterFocusNode,
                          maxLines: null,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLength: _maxChars,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          decoration: InputDecoration(
                            labelText: _insertType == 'date'
                                ? AppLocalizations.of(context)!.afterDate
                                : AppLocalizations.of(context)!.markdownEnd,
                            hintText: _insertType == 'date'
                                ? AppLocalizations.of(
                                    context,
                                  )!.optionalTextAfterDate
                                : AppLocalizations.of(
                                    context,
                                  )!.markdownStartHint,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(context)!.charactersCount(
                              _afterController.text.length,
                              _maxChars,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.preview,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: SimpleMarkdownPreview(
                            data: _generatePreviewText(),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showToolbar && _shortcuts.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: MarkdownToolbar(
                    shortcuts: _shortcuts.where((s) => s.isVisible).toList(),
                    isPreviewMode: false,
                    canUndo: false,
                    canRedo: false,
                    previewFontSize: 16,
                    onUndo: () {},
                    onRedo: () {},
                    onDecreaseFontSize: () {},
                    onIncreaseFontSize: () {},
                    onSettings: () {},
                    onShortcutPressed: _handleShortcut,
                    showSettings: false,
                    showBackground: false,
                    showReorder: false,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }
}
