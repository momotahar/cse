// lib/screens/exports/syndic_event_list_pdf_generator.dart
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:collection/collection.dart';

import 'package:cse_kch/models/syndic_event.dart';

class SyndicEventListPdfGenerator {
  static Future<void> generate({
    required BuildContext context,
    required List<SyndicEvent> events,
    String? titleSuffix,
  }) async {
    try {
      if (events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun évènement à exporter.')),
        );
        return;
      }

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

      // Tri global (date asc, heure asc)
      final rows = List<SyndicEvent>.from(events);
      rows.sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        return a.timeLabel.compareTo(b.timeLabel);
      });

      final byType = groupBy(rows, (SyndicEvent e) => e.type.trim());

      final now = DateTime.now();
      final dDay = DateFormat('dd/MM/yyyy');
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);

      const double hSpacing = 6;
      const double vSpacing = 2;

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.fromLTRB(12, 16, 12, 16),
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            final widgets = <pw.Widget>[
              pw.Text(
                'Planification Délégation ${titleSuffix != null ? ' – $titleSuffix' : ''}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 3),
            ];

            final typeEntries = byType.entries.toList()
              ..sort(
                (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
              );

            for (final typeEntry in typeEntries) {
              final typeName = typeEntry.key;
              final typeEvents = typeEntry.value;

              final byOccurrence = groupBy(
                typeEvents,
                (SyndicEvent e) =>
                    '${e.date.year.toString().padLeft(4, '0')}-'
                    '${e.date.month.toString().padLeft(2, '0')}-'
                    '${e.date.day.toString().padLeft(2, '0')}_${e.timeLabel}_${e.depotLabel}',
              );

              final occEntries = byOccurrence.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));

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
                          typeName.isEmpty ? 'Type inconnu' : typeName,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
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
                final dateLabel = dDay.format(first.date);
                final hLabel = first.timeLabel;
                final depot = first.depotLabel;
                final adresse = first.depotAdresse;

                final participants = <String>{};
                for (final e in occ.value) {
                  if (e.agentNoms.isEmpty) continue;
                  participants.addAll(
                    e.agentNoms.map((s) => s.trim()).where((s) => s.isNotEmpty),
                  );
                }
                final items = participants.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              'Date : $dateLabel    Heure : $hLabel',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                            pw.Spacer(),
                            pw.Text(
                              'Participants : ${items.length}',
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                depot.isEmpty ? 'Dépôt : -' : 'Dépôt : $depot',
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Expanded(
                              child: pw.Text(
                                adresse.isEmpty
                                    ? 'Adresse : -'
                                    : 'Adresse : $adresse',
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 4));

                widgets.add(
                  pw.Wrap(
                    spacing: hSpacing,
                    runSpacing: vSpacing,
                    children: items
                        .map(
                          (name) => pw.Text(
                            name,
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        )
                        .toList(),
                  ),
                );
                widgets.add(pw.SizedBox(height: 5));
              }

              widgets.add(pw.Container(height: .4, color: PdfColors.grey400));
              widgets.add(pw.SizedBox(height: 5));
            }

            return widgets;
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/syndic_groupes_$stamp.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF : $e')));
    }
  }
}
