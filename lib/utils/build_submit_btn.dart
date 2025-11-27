import 'dart:async';

import 'package:flutter/material.dart';

Widget buildSubmitButton({
  required BuildContext context,
  required GlobalKey<FormState> formKey,
  required FutureOr<void> Function() onValidSubmit,
  String label = 'Enregistrer',
  IconData icon = Icons.check,
  bool isLoading = false,
  bool enabled = true,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed:
          (!enabled || isLoading)
              ? null
              : () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await onValidSubmit();
              },
      icon:
          isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
  );
}
