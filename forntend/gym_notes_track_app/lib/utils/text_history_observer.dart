import 'package:flutter/material.dart';

class TextHistoryObserver {
  final TextEditingController controller;
  final List<TextEditingValue> _history = [];
  final List<TextEditingValue> _redoStack = [];
  int _currentIndex = -1;
  bool _isUndoRedoing = false;

  TextHistoryObserver(this.controller) {
    _history.add(controller.value);
    _currentIndex = 0;
    controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isUndoRedoing) return;

    final currentValue = controller.value;

    if (_currentIndex >= 0 &&
        _history[_currentIndex].text == currentValue.text) {
      return;
    }

    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _redoStack.clear();

    _history.add(currentValue);
    _currentIndex = _history.length - 1;

    if (_history.length > 100) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  bool get canUndo => _currentIndex > 0;

  bool get canRedo =>
      _currentIndex < _history.length - 1 || _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;

    _isUndoRedoing = true;
    _currentIndex--;
    controller.value = _history[_currentIndex];
    _isUndoRedoing = false;
  }

  void redo() {
    if (_currentIndex < _history.length - 1) {
      _isUndoRedoing = true;
      _currentIndex++;
      controller.value = _history[_currentIndex];
      _isUndoRedoing = false;
    }
  }

  void dispose() {
    controller.removeListener(_onTextChanged);
  }
}
