// lib/screens/exports/agents_list_pdf_generator.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:cse_kch/models/agent_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

class AgentsListPdfGenerator {
  static Future<void> generate({
    required BuildContext context,
    required List<AgentModel> agents, // passez ici la liste filtrée depuis l’UI
  }) async {
    try {
      if (agents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun agent à exporter.")),
        );
        return;
      }

      // Polices embarquées (accents, etc.)
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );

      final now = DateTime.now();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);

      // TRI : ordre ASC -> filiale (abbr) -> NOM -> PRÉNOM
      final rowsSorted = List<AgentModel>.from(agents)
        ..sort((a, b) {
          int c = a.ordre.compareTo(b.ordre);
          if (c != 0) return c;
          c = a.filiale.abreviation.compareTo(b.filiale.abreviation);
          if (c != 0) return c;
          c = a.name.compareTo(b.name);
          if (c != 0) return c;
          return a.surname.compareTo(b.surname);
        });

      // Données du tableau (ajout de la colonne Base)
      final tableData = rowsSorted.map((a) {
        final ordre = a.ordre.toString();
        final fullName = '${a.name} ${a.surname}';
        final statut = a.statut;
        final filiale = a.filiale.abreviation;
        final base = a.filiale.base; // 👈 NEW
        return [ordre, fullName, statut, filiale, base];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          build: (ctx) => [
            pw.Text(
              'Liste des agents',
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
              headers: const [
                'Ordre',
                'Agent',
                'Statut',
                'Filiale',
                'Base',
              ], // 👈 NEW
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
                0: const pw.FlexColumnWidth(0.6), // Ordre
                1: const pw.FlexColumnWidth(2.2), // Agent
                2: const pw.FlexColumnWidth(1.1), // Statut
                3: const pw.FlexColumnWidth(1.4), // Filiale
                4: const pw.FlexColumnWidth(1.0), // Base  👈 NEW
              },
            ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/agents_$stamp.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF Agents : $e')));
    }
  }
}
