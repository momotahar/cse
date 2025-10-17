// lib/screens/exports/presence_stats_pdf_generator.dart
// ignore_for_file: deprecated_member_use, depend_on_referenced_packages, unnecessary_to_list_in_spreads, avoid_print

import 'dart:io';
import 'package:cse_kch/models/presence_model.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:collection/collection.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart' show rootBundle;

class PresenceStatsPdfGenerator {
  static Future<void> generatePresenceStatsPdf(
    List<PresenceModel> presences,
  ) async {
    try {
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

      // Fenêtre année syndicale
      final now = DateTime.now();
      final startYear = now.month < 6 ? now.year - 1 : now.year;
      final startDate = DateTime(startYear, 6, 1);
      final endDate = DateTime(startYear + 1, 6, 1);
      final syndicalYearLabel = "$startYear-${startYear + 1}";

      // Mois
      final months = List.generate(12, (i) {
        final d = DateTime(startDate.year, startDate.month + i, 1);
        return DateFormat('yyyy-MM').format(d);
      });
      final monthLabels = months.map((m) {
        final d = DateFormat('yyyy-MM').parse(m);
        return DateFormat.MMM('fr_FR').format(d);
      }).toList();

      // Filtrage période
      final rows = presences.where((p) {
        try {
          final d = DateFormat('dd-MM-yyyy').parse(p.date);
          return !d.isBefore(startDate) && d.isBefore(endDate);
        } catch (_) {
          return false;
        }
      }).toList();

      // Groupement par type (trim + tri)
      final reunionsByType = groupBy(rows, (p) => (p.reunion).trim());
      final typeEntries = reunionsByType.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

      // Tailles & couleurs
      const fsTitle = 11.5;
      const fsHeader1 = 9.0;
      const fsHeader2 = 8.0;
      const fsCell = 7.8;
      const fsCellStrong = 8.2;
      const fsFoot = 7.6;

      final cBannerBg = PdfColors.blue100;
      final cBannerBorder = PdfColors.blue300;
      final cBannerText = PdfColors.blue800;

      final cHead1Bg = PdfColors.blue600;
      final cHead1Text = PdfColors.white;
      final cHead2Bg = PdfColors.blue100;
      final cHead2Text = PdfColors.blueGrey800;

      final cTableBorder = PdfColors.blue300;
      final cRowAlt = PdfColors.grey100;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(12, 14, 12, 14),
          build: (context) {
            final widgets = <pw.Widget>[];

            for (var idx = 0; idx < typeEntries.length; idx++) {
              final type = typeEntries[idx].key.isEmpty
                  ? 'Sans type'
                  : typeEntries[idx].key;
              final data = typeEntries[idx].value;

              // Occurrences distinctes par mois (date|heure)
              final distinctMeetingsPerMonth = <String, Set<String>>{
                for (final m in months) m: <String>{},
              };
              for (final p in data) {
                try {
                  final d = DateFormat('dd-MM-yyyy').parse(p.date);
                  final key = DateFormat('yyyy-MM').format(d);
                  distinctMeetingsPerMonth[key]!.add('${p.date}|${p.time}');
                } catch (_) {}
              }

              // Agents triés
              final agents = groupBy(data, (p) => p.agent).keys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              // Index agent×mois → set d'occurrences
              final agentMonthSessions = <String, Map<String, Set<String>>>{};
              for (final p in data) {
                try {
                  final d = DateFormat('dd-MM-yyyy').parse(p.date);
                  final mKey = DateFormat('yyyy-MM').format(d);
                  final sess = '${p.date}|${p.time}';
                  agentMonthSessions.putIfAbsent(p.agent, () => {});
                  agentMonthSessions[p.agent]!.putIfAbsent(
                    mKey,
                    () => <String>{},
                  );
                  agentMonthSessions[p.agent]![mKey]!.add(sess);
                } catch (_) {}
              }

              final totalYearOccurrences = distinctMeetingsPerMonth.values
                  .map((s) => s.length)
                  .fold<int>(0, (a, b) => a + b);

              // — Bandeau titre type —
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: cBannerBg,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: cBannerBorder, width: .8),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          "Statistiques des participations : $type – $syndicalYearLabel",
                          style: pw.TextStyle(
                            fontSize: fsTitle,
                            fontWeight: pw.FontWeight.bold,
                            color: cBannerText,
                          ),
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: fsHeader2,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              // — Table pour ce type —
              final headerRows = _tableHeader(
                monthLabels: monthLabels,
                monthsKeys: months,
                distinctMeetingsPerMonth: distinctMeetingsPerMonth,
                totalYearOccurrences: totalYearOccurrences,
                fsHeader1: fsHeader1,
                fsHeader2: fsHeader2,
                cHead1Bg: cHead1Bg,
                cHead1Text: cHead1Text,
                cHead2Bg: cHead2Bg,
                cHead2Text: cHead2Text,
              );

              final dataRows = <pw.TableRow>[];
              for (var i = 0; i < agents.length; i++) {
                final agent = agents[i];

                int totalAgent = 0;
                final monthCells = months.map((m) {
                  final count = agentMonthSessions[agent]?[m]?.length ?? 0;
                  if (count > 0) {
                    totalAgent += count;
                    return _cellCenter(
                      pw.Text(
                        "P",
                        style: pw.TextStyle(
                          fontSize: fsCellStrong,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                      padV: 3,
                    );
                  } else {
                    return _cellCenter(
                      pw.Text(
                        "—",
                        style: pw.TextStyle(
                          fontSize: fsCell,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                      padV: 3,
                    );
                  }
                }).toList();

                dataRows.add(
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : cRowAlt,
                    ),
                    children: [
                      // Agent
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: pw.Text(
                          agent,
                          style: const pw.TextStyle(
                            fontSize: fsCell,
                            color: PdfColors.blueGrey900,
                          ),
                          overflow: pw.TextOverflow.span,
                        ),
                      ),
                      // Mois
                      ...monthCells,
                      // Total agent (nb d'occurrences)
                      _cellCenter(
                        pw.Text(
                          "$totalAgent",
                          style: pw.TextStyle(
                            fontSize: fsCellStrong,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                        padV: 3,
                      ),
                    ],
                  ),
                );
              }

              widgets.add(
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: cTableBorder, width: .8),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Table(
                    border: const pw.TableBorder(
                      horizontalInside: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: .35,
                      ),
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      for (int i = 1; i <= months.length; i++)
                        i: const pw.FlexColumnWidth(1),
                      months.length + 1: const pw.FlexColumnWidth(1.1),
                    },
                    children: [...headerRows, ...dataRows],
                  ),
                ),
              );

              // Légende
              widgets.add(pw.SizedBox(height: 8));
              // widgets.add(
              //   pw.Text(
              //     "Convention : “P” = présent au moins 1 fois dans le mois ; Total = nombre d’occurrences (date|heure) auxquelles l’agent a participé sur l’année.",
              //     style: pw.TextStyle(
              //       fontSize: fsFoot,
              //       color: PdfColors.blueGrey700,
              //     ),
              //   ),
              // );

              // Séparateur entre types
              if (idx != typeEntries.length - 1) {
                widgets.add(pw.SizedBox(height: 12));
                widgets.add(pw.Container(height: .6, color: PdfColors.grey400));
                widgets.add(pw.SizedBox(height: 12));
              }
            }

            return widgets;
          },
        ),
      );

      // Sauvegarde + ouverture
      final outputDir = await getApplicationDocumentsDirectory();
      await Directory(outputDir.path).create(recursive: true);
      final file = File(
        "${outputDir.path}/participations_stats_$syndicalYearLabel.pdf",
      );
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      print('Erreur lors de la génération du PDF : $e');
    }
  }

  // ---------- Helpers ----------

  static List<pw.TableRow> _tableHeader({
    required List<String> monthLabels,
    required List<String> monthsKeys,
    required Map<String, Set<String>> distinctMeetingsPerMonth,
    required int totalYearOccurrences,
    required double fsHeader1,
    required double fsHeader2,
    required PdfColor cHead1Bg,
    required PdfColor cHead1Text,
    required PdfColor cHead2Bg,
    required PdfColor cHead2Text,
  }) {
    final styleH1 = pw.TextStyle(
      fontSize: fsHeader1,
      fontWeight: pw.FontWeight.bold,
      color: cHead1Text,
    );
    final styleH2 = pw.TextStyle(fontSize: fsHeader2, color: cHead2Text);

    // Ligne 1 : libellés
    final row1 = pw.TableRow(
      decoration: pw.BoxDecoration(color: cHead1Bg),
      children: [
        _cellLeft(
          pw.Text("Agent", style: styleH1),
          pad: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        ...monthLabels
            .map((lbl) => _cellCenter(pw.Text(lbl, style: styleH1), padV: 6))
            .toList(),
        _cellCenter(pw.Text("Total", style: styleH1), padV: 6),
      ],
    );

    // Ligne 2 : nombres d’occurrences
    final row2 = pw.TableRow(
      decoration: pw.BoxDecoration(color: cHead2Bg),
      children: [
        _cellLeft(
          pw.Text("", style: styleH2),
          pad: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        ...monthsKeys.map((m) {
          final n = distinctMeetingsPerMonth[m]?.length ?? 0;
          return _cellCenter(pw.Text("$n", style: styleH2), padV: 4);
        }).toList(),
        _cellCenter(pw.Text("$totalYearOccurrences", style: styleH2), padV: 4),
      ],
    );

    return [row1, row2];
  }

  static pw.Widget _cellCenter(pw.Widget child, {double padV = 4}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: padV),
      alignment: pw.Alignment.center,
      child: child,
    );
  }

  static pw.Widget _cellLeft(pw.Widget child, {pw.EdgeInsets? pad}) {
    return pw.Container(
      padding: pad ?? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: pw.Alignment.centerLeft,
      child: child,
    );
  }
}
