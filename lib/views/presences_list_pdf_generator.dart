// lib/screens/exports/presences_list_pdf_generator.dart
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:cse_kch/models/presence_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // fonts
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:collection/collection.dart';

class PresencesListPdfGenerator {
  static Future<void> generate({
    required BuildContext context,
    required List<PresenceModel> presencesFiltrees,
  }) async {
    try {
      if (presencesFiltrees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucune présence à exporter.")),
        );
        return;
      }

      // Tri global (date desc, heure asc)
      final rows = List<PresenceModel>.from(presencesFiltrees);
      rows.sort((a, b) {
        try {
          final da = DateFormat('dd-MM-yyyy').parse(a.date);
          final db = DateFormat('dd-MM-yyyy').parse(b.date);
          if (da != db) return db.compareTo(da);
        } catch (_) {}
        return a.time.compareTo(b.time);
      });

      // Groupement par type
      final byType = groupBy(rows, (PresenceModel p) => p.reunion.trim());

      // Polices
      final robotoRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      final robotoBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );
      final robotoItalic = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Italic.ttf'),
      );
      final robotoBoldItalic = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-BoldItalic.ttf'),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: robotoRegular,
          bold: robotoBold,
          italic: robotoItalic,
          boldItalic: robotoBoldItalic,
        ),
        version: PdfVersion.pdf_1_5,
        compress: true,
      );

      final now = DateTime.now();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);

      // Réglages d'espacement pour la liste des agents
      const double hSpacing =
          6; // espace horizontal entre noms (réduis à 4/2 si besoin)
      const double vSpacing = 2; // espace vertical entre lignes

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.fromLTRB(12, 16, 12, 16),
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            final widgets = <pw.Widget>[
              pw.Text(
                'Participations – Groupées par type de réunion',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Généré le ${DateFormat('dd/MM/yyyy').format(now)}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(height: 6),
            ];

            final typeEntries = byType.entries.toList()
              ..sort(
                (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
              );

            for (final typeEntry in typeEntries) {
              final typeName = typeEntry.key;
              final presencesOfType = typeEntry.value;

              // Groupement par occurrence (date+heure)
              final byOccurrence = groupBy(
                presencesOfType,
                (p) => '${p.date}_${p.time}',
              );

              // Occurrences triées (date desc, heure asc)
              final occEntries = byOccurrence.entries.toList()
                ..sort((a, b) {
                  final pa = a.value.first;
                  final pb = b.value.first;
                  try {
                    final da = DateFormat('dd-MM-yyyy').parse(pa.date);
                    final db = DateFormat('dd-MM-yyyy').parse(pb.date);
                    if (da != db) return db.compareTo(da);
                  } catch (_) {}
                  return pa.time.compareTo(pb.time);
                });

              // En-tête TYPE
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue300, width: .6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          typeName,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${occEntries.length} réunion${occEntries.length > 1 ? "s" : ""}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 5));

              // Détail par occurrence
              for (final occ in occEntries) {
                final first = occ.value.first;

                // Uniques + consolidation retard (on garde le max de minutes)
                final participantsMap = <String, Map<String, dynamic>>{};
                for (final e in occ.value) {
                  final prev = participantsMap[e.agent];
                  final isLate = e.isLate == true;
                  final lateMin = (e.lateMinutes ?? 0);
                  if (prev == null) {
                    participantsMap[e.agent] = {
                      'isLate': isLate,
                      'lateMinutes': lateMin,
                    };
                  } else {
                    final prevLate = (prev['lateMinutes'] as int?) ?? 0;
                    final prevIsLate = (prev['isLate'] as bool?) ?? false;
                    participantsMap[e.agent] = {
                      'isLate': prevIsLate || isLate,
                      'lateMinutes': lateMin > prevLate ? lateMin : prevLate,
                    };
                  }
                }

                final entries = participantsMap.entries.toList()
                  ..sort(
                    (a, b) =>
                        a.key.toLowerCase().compareTo(b.key.toLowerCase()),
                  );

                // Barre occurrence
                widgets.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: .5,
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          'Date : ${first.date}    Heure : ${first.time}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          'Participants : ${entries.length}',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 4));

                // ---- LISTE COMPACTE DES AGENTS (Wrap) ----
                final items = entries.map((cell) {
                  final name = cell.key;
                  final data = cell.value;
                  final isLate = (data['isLate'] as bool?) ?? false;
                  final lateMin = (data['lateMinutes'] as int?) ?? 0;

                  return pw.RichText(
                    text: pw.TextSpan(
                      text: name,
                      style: const pw.TextStyle(fontSize: 7),
                      children: [
                        if (isLate && lateMin > 0)
                          pw.TextSpan(
                            text: ' ($lateMin min)',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.red,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList();

                widgets.add(
                  pw.Wrap(
                    spacing: hSpacing, // ← contrôle de l’espace horizontal
                    runSpacing: vSpacing,
                    children: items,
                  ),
                );

                widgets.add(pw.SizedBox(height: 5));
              }

              // Séparateur entre types
              widgets.add(pw.Container(height: .4, color: PdfColors.grey400));
              widgets.add(pw.SizedBox(height: 5));
            }

            return widgets;
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/presences_groupes_$stamp.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export PDF (groupé par type) : $e')),
      );
    }
  }
}
