import 'package:flutter/foundation.dart';

/// Global service to manage loading state across the app.
/// Uses ValueNotifier for reactive updates.
class LoadingService {
  static final LoadingService _instance = LoadingService._internal();
  factory LoadingService() => _instance;
  LoadingService._internal();

  /// ValueNotifier that tracks if a database operation is in progress
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  /// Counter to track nested operations
  int _operationCount = 0;

  /// Start a loading operation
  void startLoading() {
    _operationCount++;
    if (_operationCount == 1) {
      isLoading.value = true;
    }
  }

  /// End a loading operation
  void stopLoading() {
    if (_operationCount > 0) {
      _operationCount--;
      if (_operationCount == 0) {
        isLoading.value = false;
      }
    }
  }

  /// Execute an async operation with loading state
  Future<T> withLoading<T>(Future<T> Function() operation) async {
    startLoading();
    try {
      return await operation();
    } finally {
      stopLoading();
    }
  }

  /// Reset the loading state (useful for error recovery)
  void reset() {
    _operationCount = 0;
    isLoading.value = false;
  }
}
