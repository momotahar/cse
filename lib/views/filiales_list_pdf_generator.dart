// lib/screens/exports/filiales_list_pdf_generator.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:cse_kch/models/filiale_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

class FilialesListPdfGenerator {
  static Future<void> generate({
    required BuildContext context,
    required List<FilialeModel> filiales,
  }) async {
    try {
      if (filiales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucune filiale à exporter.")),
        );
        return;
      }

      final pdf = pw.Document();
      final now = DateTime.now();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);

      String _safe(String? v) =>
          (v == null || v.trim().isEmpty) ? '-' : v.trim();

      // Tri par abréviation
      final rowsSorted = List<FilialeModel>.from(filiales)
        ..sort((a, b) => a.abreviation.compareTo(b.abreviation));

      // Ajout des colonnes Adresse et Base
      final tableData = rowsSorted
          .map(
            (f) => [
              _safe(f.abreviation),
              _safe(f.designation),
              _safe(f.adresse), // ⬅️ adresse
              _safe(f.base), // ⬅️ base
            ],
          )
          .toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          build: (ctx) => [
            pw.Text(
              'Liste des filiales',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy').format(now)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: const ['Abréviation', 'Désignation', 'Adresse', 'Base'],
              data: tableData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.lightBlue100,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8), // Abréviation
                1: const pw.FlexColumnWidth(2.0), // Désignation
                2: const pw.FlexColumnWidth(3.2), // Adresse (souvent longue)
                3: const pw.FlexColumnWidth(1.4), // Base
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
            ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/filiales_$stamp.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export PDF Filiales : $e')),
      );
    }
  }
}
