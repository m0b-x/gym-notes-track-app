import 'dart:async';

import 'package:flutter/material.dart';

class _HistoryEntry {
  final String text;
  final TextSelection selection;

  _HistoryEntry({required this.text, required this.selection});

  _HistoryEntry.full(TextEditingValue value)
    : text = value.text,
      selection = value.selection;

  TextEditingValue toValue() =>
      TextEditingValue(text: text, selection: selection);
}

class TextHistoryObserver {
  final TextEditingController controller;
  final int maxHistoryLength;
  final Duration debounceDuration;
  final int largePasteThreshold;
  final int diffThreshold;

  final List<_HistoryEntry> _history = [];
  int _currentIndex = -1;
  bool _isUndoRedoing = false;
  Timer? _debounceTimer;
  TextEditingValue? _pendingValue;
  bool _isDisposed = false;

  TextHistoryObserver(
    this.controller, {
    this.maxHistoryLength = 100,
    this.debounceDuration = const Duration(milliseconds: 400),
    this.largePasteThreshold = 20,
    this.diffThreshold = 10000,
  }) {
    _history.add(_HistoryEntry.full(controller.value));
    _currentIndex = 0;
    controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isUndoRedoing || _isDisposed) return;

    final currentValue = controller.value;
    final lastText = _currentIndex >= 0 ? _history[_currentIndex].text : '';

    if (currentValue.text == lastText) return;

    final lengthDiff = (currentValue.text.length - lastText.length).abs();
    final isLargePaste = lengthDiff >= largePasteThreshold;

    if (isLargePaste) {
      _commitPendingIfNeeded();
      _addToHistory(currentValue);
      return;
    }

    _pendingValue = currentValue;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, _commitPending);
  }

  void _commitPending() {
    if (_isDisposed || _pendingValue == null) return;

    final pending = _pendingValue!;
    _pendingValue = null;

    if (_currentIndex < 0 || pending.text != _history[_currentIndex].text) {
      _addToHistory(pending);
    }
  }

  void _commitPendingIfNeeded() {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_pendingValue != null &&
        (_currentIndex < 0 ||
            _pendingValue!.text != _history[_currentIndex].text)) {
      _addToHistory(_pendingValue!);
      _pendingValue = null;
    }
  }

  void _addToHistory(TextEditingValue value) {
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _history.add(_HistoryEntry.full(value));
    _currentIndex = _history.length - 1;

    _trimHistory();
  }

  void _trimHistory() {
    while (_history.length > maxHistoryLength) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  bool get canUndo {
    _commitPendingIfNeeded();
    return _currentIndex > 0;
  }

  bool get canRedo {
    _commitPendingIfNeeded();
    return _currentIndex < _history.length - 1;
  }

  void undo() {
    _commitPendingIfNeeded();
    if (!canUndo) return;

    _isUndoRedoing = true;
    _currentIndex--;

    final entry = _history[_currentIndex];
    final targetValue = entry.toValue();
    controller.value = targetValue.copyWith(
      selection: _clampSelection(targetValue.selection, targetValue.text),
    );

    _isUndoRedoing = false;
  }

  void redo() {
    _commitPendingIfNeeded();
    if (!canRedo) return;

    _isUndoRedoing = true;
    _currentIndex++;

    final entry = _history[_currentIndex];
    final targetValue = entry.toValue();
    controller.value = targetValue.copyWith(
      selection: _clampSelection(targetValue.selection, targetValue.text),
    );

    _isUndoRedoing = false;
  }

  TextSelection _clampSelection(TextSelection selection, String text) {
    final maxOffset = text.length;
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, maxOffset),
      extentOffset: selection.extentOffset.clamp(0, maxOffset),
    );
  }

  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingValue = null;
    _history.clear();
    _history.add(_HistoryEntry.full(controller.value));
    _currentIndex = 0;
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingValue = null;
    controller.removeListener(_onTextChanged);
  }
}
