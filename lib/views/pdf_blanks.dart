// lib/services/pdf_blanks.dart
// Génération de modèles PDF "vierges" prêts à imprimer / envoyer.
// ignore_for_file: deprecated_member_use, no_leading_underscores_for_local_identifiers

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfBlanks {
  // Palette cohérente avec tes autres exports
  static const PdfColor _pdfBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _pdfOddRow = PdfColor.fromInt(0xFFF7FBFF);
  static const PdfColor _pdfLine = PdfColor.fromInt(0xFFDDDDDD);

  /// Génère et SAUVE un PDF "Véhicules (vierge)" sur le stockage temporaire.
  /// Retourne le chemin du fichier. Ouvre le fichier si [openAfterSave] = true.
  static Future<String> saveVehiculesPdfVierge({
    String? baseLabel,
    int lignesVides = 12,
    bool openAfterSave = true,
  }) async {
    try {
      final bytes = await buildVehiculesPdfViergeBytes(
        baseLabel: baseLabel,
        lignesVides: lignesVides,
        format: PdfPageFormat.a4.landscape,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final baseSafe = _fileSafe(baseLabel ?? 'toutes');
      final path = '${dir.path}/vehicules_vierge_${baseSafe}_$ts.pdf';

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (openAfterSave) {
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          debugPrint('PdfBlanks.saveVehiculesPdfVierge open error: $e');
        }
      }
      return file.path;
    } catch (e) {
      debugPrint('PdfBlanks.saveVehiculesPdfVierge error: $e');
      rethrow;
    }
  }

  /// Construit les octets du PDF "Véhicules (vierge)".
  static Future<Uint8List> buildVehiculesPdfViergeBytes({
    String? baseLabel,
    int lignesVides = 20,
    required PdfPageFormat format,
  }) async {
    try {
      // Polices embarquées (accents / symbole €)
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
      );

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );

      final title =
          'Parc Véhicules'
          '${baseLabel == null || baseLabel.trim().isEmpty ? '' : ' — $baseLabel'}';

      // En-têtes identiques
      final headers = const [
        'IMMAT.',
        'ENTRÉE',
        'MARQUE',
        'MODÈLE',
        'BASE',
        'COLLAB.',
        'STATUT',
        'PROCHAIN CT',
      ];

      // N lignes vides
      final data = List<List<String>>.generate(
        lignesVides,
        (_) => List<String>.filled(8, ' '),
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(24),
          header:
              (ctx) => pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _pdfBlue,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          footer:
              (ctx) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
          build:
              (ctx) => [
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: _pdfHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: _pdfLine, width: 0.4),
                    outside: const pw.BorderSide(color: _pdfLine, width: 0.6),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.1),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.3),
                    3: pw.FlexColumnWidth(1.3),
                    4: pw.FlexColumnWidth(1.2),
                    5: pw.FlexColumnWidth(1.3),
                    6: pw.FlexColumnWidth(1.1),
                    7: pw.FlexColumnWidth(1.3),
                  },
                  cellAlignment: pw.Alignment.centerLeft,
                  oddRowDecoration: const pw.BoxDecoration(color: _pdfOddRow),
                ),
              ],
        ),
      );

      return doc.save();
    } catch (e) {
      debugPrint('PdfBlanks.buildVehiculesPdfViergeBytes error: $e');
      rethrow;
    }
  }

  // Helpers
  static String _fileSafe(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '_');

  // SAUVE & (optionnel) OUVRE le PDF “Kilométrage (mensuel) – vierge”
  static Future<String> saveKilometragePdfViergeParMois({
    int? annee, // pour le nom du fichier
    int? mois, // pour le nom du fichier
    String? basePourNom, // pour le nom du fichier
    int lignesVides = 20,
    bool openAfterSave = true,
  }) async {
    try {
      final bytes = await buildKilometragePdfViergeBytes(
        lignesVides: lignesVides,
        format: PdfPageFormat.a4.landscape,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final m2 = (mois ?? 0).toString().padLeft(2, '0');
      final baseSafe = _fileSafe(basePourNom ?? 'toutes');
      final suffix =
          (annee != null && mois != null)
              ? '${annee}_${m2}_$baseSafe'
              : 'mensuel_$baseSafe';
      final path = '${dir.path}/kilometrage_vierge_${suffix}_$ts.pdf';

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (openAfterSave) {
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          debugPrint(
            'PdfBlanks.saveKilometragePdfViergeParMois open error: $e',
          );
        }
      }
      return file.path;
    } catch (e) {
      debugPrint('PdfBlanks.saveKilometragePdfViergeParMois error: $e');
      rethrow;
    }
  }

  /// Construit les octets du PDF “Kilométrage (mensuel) – vierge”
  static Future<Uint8List> buildKilometragePdfViergeBytes({
    int lignesVides = 20,
    PdfPageFormat? format,
  }) async {
    try {
      // Polices (accents / €)
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
      );

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );

      // Garantit le PORTRAIT
      PdfPageFormat _portraitOf(PdfPageFormat f) =>
          (f.width <= f.height) ? f : PdfPageFormat(f.height, f.width);
      final pageFormat = _portraitOf(format ?? PdfPageFormat.a4);

      // Petit helper “label + ligne”
      pw.Widget _lineField(String label) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 16,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _pdfLine, width: 0.8),
                ),
              ),
            ),
          ],
        );
      }

      const title = 'Kilométrage';
      const headers = <String>['IMMAT.', 'KM'];
      final data = List<List<String>>.generate(
        lignesVides,
        (_) => const [' ', ' '],
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          header:
              (ctx) => pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _pdfBlue,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          footer:
              (ctx) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
          build:
              (ctx) => [
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _pdfLine, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: const PdfColor.fromInt(0xFFFDFDFE),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _lineField('Année')),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _lineField('Mois')),
                      pw.SizedBox(width: 12),
                      pw.Expanded(flex: 2, child: _lineField('Base')),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: _pdfHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: _pdfLine, width: 0.4),
                    outside: const pw.BorderSide(color: _pdfLine, width: 0.6),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.8),
                    1: pw.FlexColumnWidth(1.0),
                  },
                  cellAlignments: const {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                  },
                  oddRowDecoration: const pw.BoxDecoration(color: _pdfOddRow),
                ),
              ],
        ),
      );

      return doc.save();
    } catch (e) {
      debugPrint('PdfBlanks.buildKilometragePdfViergeBytes error: $e');
      rethrow;
    }
  }

  /// Sauvegarde un PDF "Commandes (vierge)" dans le répertoire temporaire.
  static Future<String> saveCommandesPdfVierge({
    String? periodeLabel,
    String? baseLabel,
    int lignesVides = 20,
    bool openAfterSave = true,
    PdfPageFormat? format,
  }) async {
    try {
      final bytes = await buildCommandesPdfViergeBytes(
        lignesVides: lignesVides,
        format: format ?? PdfPageFormat.a4.landscape,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final parts = <String>['commandes_vierge'];
      if (periodeLabel != null && periodeLabel.trim().isNotEmpty) {
        parts.add(_fileSafe(periodeLabel));
      }
      if (baseLabel != null && baseLabel.trim().isNotEmpty) {
        parts.add(_fileSafe(baseLabel));
      }
      parts.add(ts);
      final path = '${dir.path}/${parts.join('_')}.pdf';

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (openAfterSave) {
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          debugPrint('PdfBlanks.saveCommandesPdfVierge open error: $e');
        }
      }
      return file.path;
    } catch (e) {
      debugPrint('PdfBlanks.saveCommandesPdfVierge error: $e');
      rethrow;
    }
  }

  /// Construit les octets du PDF “Commandes (vierge)” en **A4 portrait**
  static Future<Uint8List> buildCommandesPdfViergeBytes({
    int lignesVides = 20, // (on ignore et fixe à 28 plus bas)
    required PdfPageFormat format, // ignoré: on force A4 portrait
  }) async {
    try {
      // Polices (accents / €)
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
      );

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );

      const headers = <String>[
        'DATE',
        'LIBELLÉ BILLET',
        'QTÉ',
        'MT(€)',
        'N° CHÈQUE',
        'AGENT',
        'BASE',
        'E-MAIL',
      ];

      // 🔒 Toujours 28 lignes
      const _rowsCount = 28;
      final data = List<List<String>>.generate(
        _rowsCount,
        (_) => List<String>.filled(headers.length, ' '),
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4, // A4 portrait
          margin: const pw.EdgeInsets.all(24),
          header:
              (ctx) => pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _pdfBlue,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Commandes de billets',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
          footer:
              (ctx) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
          build:
              (ctx) => [
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: _pdfHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: _pdfLine, width: 0.4),
                    outside: const pw.BorderSide(color: _pdfLine, width: 0.6),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(0.9), // DATE
                    1: pw.FlexColumnWidth(1.6), // LIBELLÉ
                    2: pw.FlexColumnWidth(0.7), // QTÉ
                    3: pw.FlexColumnWidth(1.0), // MONT
                    4: pw.FlexColumnWidth(1.5), // N°CHÈQUE
                    5: pw.FlexColumnWidth(1.5), // AGENT
                    6: pw.FlexColumnWidth(0.9), // BASE
                    7: pw.FlexColumnWidth(1.5), // E-MAIL
                  },
                  cellAlignments: const {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                    6: pw.Alignment.centerLeft,
                    7: pw.Alignment.centerLeft,
                  },
                  oddRowDecoration: const pw.BoxDecoration(color: _pdfOddRow),
                ),
              ],
        ),
      );

      return doc.save();
    } catch (e) {
      debugPrint('PdfBlanks.buildCommandesPdfViergeBytes error: $e');
      rethrow;
    }
  }
}
