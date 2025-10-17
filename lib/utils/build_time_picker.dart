import 'package:cse_kch/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Sélecteur d'heure avec style par défaut
Future<TimeOfDay?> selectTime(
  BuildContext context,
  TextEditingController ctrl,
) async {
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (time != null) {
    final now = DateTime.now();
    final formatted = DateFormat(
      'HH:mm',
    ).format(DateTime(now.year, now.month, now.day, time.hour, time.minute));
    ctrl.text = formatted;
  }

  return time;
}

Widget buildTimePicker(
  BuildContext context,
  TextEditingController ctrl,
  String label, {
  Color borderColor = Colors.black54,
  Color focusColor = Colors.orange,
}) {
  return TextFormField(
    controller: ctrl,
    readOnly: true,
    onTap: () => selectTime(context, ctrl),
    decoration: InputDecoration(
      labelText: label,

      labelStyle: const TextStyle(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      suffixIcon: IconButton(
        onPressed: ctrl.clear,
        icon: const Icon(Icons.close, size: 18, color: AppConstants.backUpper),
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
    validator: (value) => (value == null || value.isEmpty) ? '$label ?' : null,
  );
}
