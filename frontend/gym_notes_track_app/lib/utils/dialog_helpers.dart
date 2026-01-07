import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// Helper methods for showing common dialogs and bottom sheets
class DialogHelpers {
  /// Show a confirmation dialog with customizable title and message
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: AppTextStyles.dialogTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isDestructive
                  ? TextButton.styleFrom(foregroundColor: Colors.red)
                  : null,
              child: Text(confirmText ?? 'Confirm'),
            ),
          ],
        );
      },
    );
  }

  /// Show a text input dialog
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    required String hintText,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    FormFieldValidator<String>? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: AppTextStyles.dialogTitle),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(hintText: hintText),
              autofocus: true,
              validator: validator,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text);
                }
              },
              child: Text(confirmText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show a simple alert dialog
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
  }) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: AppTextStyles.dialogTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(buttonText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show a loading dialog
  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: Text(message ?? 'Loading...')),
            ],
          ),
        );
      },
    );
  }

  /// Dismiss any showing dialog
  static void dismissDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
