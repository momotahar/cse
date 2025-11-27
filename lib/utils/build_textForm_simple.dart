import 'package:cse_kch/constants/app_constants.dart';
import 'package:flutter/material.dart';

Widget buildTextFormFieldSimple(
  TextEditingController ctrl,
  String labelText, {
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        suffixIcon: IconButton(
          onPressed: () => ctrl.clear(),
          icon: const Icon(
            Icons.close,
            size: 18,
            color: AppConstants.backUpper,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppConstants.backUpper),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(12),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
      ),
      style: const TextStyle(fontSize: 13),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '$labelText ?';
            }
            return null;
          },
    ),
  );
}
