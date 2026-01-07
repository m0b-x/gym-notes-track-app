import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';

class CustomSnackbar {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool withToolbarOffset = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: AppSpacing.snackbarMargin(withToolbarOffset: withToolbarOffset),
        duration: duration,
        showCloseIcon: true,
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    bool withToolbarOffset = false,
  }) {
    show(
      context,
      message,
      duration: const Duration(seconds: 4),
      withToolbarOffset: withToolbarOffset,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    bool withToolbarOffset = false,
  }) {
    show(
      context,
      message,
      duration: const Duration(seconds: 2),
      withToolbarOffset: withToolbarOffset,
    );
  }
}
