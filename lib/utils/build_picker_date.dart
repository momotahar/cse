import 'package:cse_kch/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sélecteur de date
Future<DateTime?> selectDate(
  BuildContext context,
  TextEditingController ctrl, {
  required Color primaryColor,
  required Color backgroundColor,
  required Color textColor,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    locale: const Locale('fr', 'FR'),
    builder: (context, child) => Theme(
      data: ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          surface: backgroundColor,
          onSurface: textColor,
        ),
        // dialogTheme: DialogTheme(backgroundColor: backgroundColor),
      ),
      child: child!,
    ),
  );

  if (date != null) {
    ctrl.text = DateFormat('dd-MM-yyyy', 'fr').format(date);
  }

  return date;
}

/// Champ texte avec date picker
Widget buildDatePicker(
  BuildContext context,
  TextEditingController ctrl,
  String label, {
  required void Function(DateTime) onSelected,
  Color primaryColor = Colors.pink,
  Color backgroundColor = Colors.white,
  Color textColor = Colors.black,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: () async {
        final date = await selectDate(
          context,
          ctrl,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
          textColor: textColor,
        );
        if (date != null) onSelected(date);
      },
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        suffixIcon: IconButton(
          onPressed: ctrl.clear,
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
      validator: (value) =>
          (value == null || value.isEmpty) ? '$label ?' : null,
    ),
  );
}
