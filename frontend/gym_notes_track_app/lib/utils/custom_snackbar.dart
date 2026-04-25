import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';

class CustomSnackbar {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool withToolbarOffset = false,
  }) {
    _showSnackBar(
      context,
      message: message,
      duration: duration,
      withToolbarOffset: withToolbarOffset,
      showCloseIcon: true,
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

  static void showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 4),
    bool withToolbarOffset = false,
  }) {
    // Cap at 4s so an undo prompt never lingers indefinitely on screen.
    final capped = duration > const Duration(seconds: 4)
        ? const Duration(seconds: 4)
        : duration;
    _showSnackBar(
      context,
      message: message,
      duration: capped,
      withToolbarOffset: withToolbarOffset,
      // Close (X) lets the user dismiss the snackbar without invoking the
      // action; the action button itself remains for the primary intent
      // (e.g. Undo).
      showCloseIcon: true,
      action: SnackBarAction(label: actionLabel, onPressed: onAction),
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Duration duration,
    required bool withToolbarOffset,
    bool showCloseIcon = false,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: AppSpacing.snackbarMargin(withToolbarOffset: withToolbarOffset),
        duration: duration,
        showCloseIcon: showCloseIcon,
        action: action,
      ),
    );
  }
}
