import 'package:flutter/material.dart';

// ignore: non_constant_identifier_names
Widget IconSphere(BuildContext context) {
  return Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [
          Color(0xFFEFEFEF),
          Color.fromARGB(255, 41, 1, 101),
          Color(0xFF1C2B3A),
        ],
        center: Alignment(-0.4, -0.4),
        radius: 1.0,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6)),
      ],
    ),
    child: ClipOval(
      child: Image.asset('assets/images/suivi_image.png', fit: BoxFit.cover),
    ),
  );
}
