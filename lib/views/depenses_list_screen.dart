// lib/views/depenses_list_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/depense.dart';
import '../providers/depense_provider.dart';
import 'depenses_form_screen.dart';

class DepensesListScreen extends StatefulWidget {
  const DepensesListScreen({super.key});
  @override
  State<DepensesListScreen> createState() => _DepensesListScreenState();
}

class _DepensesListScreenState extends State<DepensesListScreen> {
  // ====== Palette alignée sur PdfModelsScreen ======
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _ink = Color(0xFF0F172A); // slate-900
  static const _muted = Color(0xFF64748B); // slate-500
  static const _cardBg = Color(0xFFF8FAFC); // slate-50
  static const _bg = Color(0xFFF1F5F9); // slate-100
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _shadow = Color(0x1A0F172A); // 10% opacité

  final _fournLikeCtrl = TextEditingController();

  int? _month;
  int? _year = DateTime.now().year; // année courante par défaut

  // Tri tableau
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Scrollbars (H + V) stables
  final _hScrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  // Couleurs PDF pour cohérence avec les autres exports
  static const PdfColor _pdfBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _pdfOddRow = PdfColor.fromInt(0xFFF7FBFF);
  static const PdfColor _pdfLine = PdfColor.fromInt(0xFFDDDDDD);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _apply(initial: true);
    });
  }

  @override
  void dispose() {
    _fournLikeCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  // dd/MM/yyyy
  String _df(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _euros(double v) => '${v.toStringAsFixed(2)} €';

  /// Applique les filtres au provider (UI -> provider)
  Future<void> _apply({bool initial = false}) async {
    final prov = context.read<DepenseProvider>();

    DateTime? from;
    DateTime? to;

    if (_year != null && _month != null) {
      from = DateTime(_year!, _month!, 1);
      to = DateTime(_year!, _month! + 1, 0, 23, 59, 59, 999);
    } else if (_year != null) {
      from = DateTime(_year!, 1, 1);
      to = DateTime(_year!, 12, 31, 23, 59, 59, 999);
    } else {
      from = null;
      to = null;
    }

    prov.setFilters(
      from: from,
      to: to,
      fournisseurLike: _fournLikeCtrl.text.trim().isEmpty
          ? null
          : _fournLikeCtrl.text.trim(),
    );

    if (!initial && mounted) {
      // toast éventuel
    }
  }

  Future<void> _clear() async {
    setState(() {
      _fournLikeCtrl.clear();
      _month = null;
      _year = DateTime.now().year;
    });
    await _apply();
  }

  Future<void> _edit(Depense d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DepensesFormScreen(depense: d),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    await context.read<DepenseProvider>().refresh();
  }

  Future<void> _delete(Depense d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette dépense ?'),
        content: Text(
          '${d.fournisseur} • ${_df(d.date)} • ${_euros(d.montantTtc)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<DepenseProvider>().deleteDepense(d.id!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dépense supprimée.')));
      }
    }
  }

  // ───────────────── Export PDF ─────────────────

  Future<void> _openPdfExportDialog() async {
    int? selMonth = _month;
    int? selYear = _year;

    final startYear = 2018, endYear = DateTime.now().year + 3;
    final years = List.generate(
      endYear - startYear + 1,
      (i) => startYear + i,
    ).toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Exporter — Dépenses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                value: selMonth,
                decoration: const InputDecoration(
                  labelText: 'Mois',
                  prefixIcon: Icon(Icons.calendar_month),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tous les mois'),
                  ),
                  ...List.generate(
                    12,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                ],
                onChanged: (v) => setLocal(() => selMonth = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: selYear,
                decoration: const InputDecoration(
                  labelText: 'Année',
                  prefixIcon: Icon(Icons.event),
                  isDense: true,
                ),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) => setLocal(() => selYear = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fournLikeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fournisseur (contient)',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exporter'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() {
        _month = selMonth;
        _year = selYear;
      });
      await _apply();

      final rows = List<Depense>.from(context.read<DepenseProvider>().depenses)
        ..sort((a, b) => a.date.compareTo(b.date));
      await _exportDepensesPdf(rows);
    }
  }

  Future<void> _exportDepensesPdf(List<Depense> rows) async {
    try {
      final bytes = await _buildDepensesPdfBytes(
        rows: rows,
        month: _month,
        year: _year,
        fournisseurLike: _fournLikeCtrl.text.trim(),
        format: PdfPageFormat.a4.landscape,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final partM = _month == null ? 'all' : _month!.toString().padLeft(2, '0');
      final partY = _year == null ? 'all' : _year.toString();
      final name = 'depenses_${partY}_${partM}_$ts.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF enregistré : ${file.path}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF : $e')));
    }
  }

  Future<Uint8List> _buildDepensesPdfBytes({
    required List<Depense> rows,
    required PdfPageFormat format,
    int? month,
    int? year,
    String? fournisseurLike,
  }) async {
    // Polices pour accents & symbole €
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    // Ligne d’info filtres
    final filters = <String>[];
    if (year != null && month != null) {
      filters.add('Période : ${month.toString().padLeft(2, '0')}/$year');
    } else if (year != null) {
      filters.add('Année : $year');
    } else {
      filters.add('Période : toutes');
    }
    if ((fournisseurLike ?? '').isNotEmpty) {
      filters.add('Fournisseur contient "$fournisseurLike"');
    }
    final filterLine = filters.join(' • ');

    // Données tableau
    final headers = const [
      'DATE',
      'FOURNISSEUR',
      'LIBELLÉ',
      'N° FACTURE',
      'MONTANT TTC (€)',
    ];

    final totalTtc = rows.fold<double>(0.0, (sum, d) => sum + (d.montantTtc));

    final data = rows.map<List<String>>((d) {
      final num = (d.numeroFacture ?? '').trim();
      return [
        DateFormat('dd/MM/yyyy', 'fr_FR').format(d.date),
        d.fournisseur,
        d.libelle,
        num.isEmpty ? '—' : num,
        d.montantTtc.toStringAsFixed(2),
      ];
    }).toList();

    final nowStr = DateFormat(
      'dd/MM/yyyy HH:mm',
      'fr_FR',
    ).format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _pdfBlue,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Liste des dépenses',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
              ),
              pw.Text(
                'Généré le $nowStr',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
            child: pw.Text(
              filterLine,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _pdfBlue,
              ),
            ),
          ),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            headerDecoration: const pw.BoxDecoration(color: _pdfHeaderBg),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: _pdfLine, width: 0.4),
              outside: const pw.BorderSide(color: _pdfLine, width: 0.6),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: _pdfOddRow),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(2.4),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.2),
            },
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _pdfBlue, width: 1.2),
                ),
              ),
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'TOTAL TTC : ${totalTtc.toStringAsFixed(2)} €',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfBlue,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DepenseProvider>();
    final items = List<Depense>.from(prov.depenses);

    // Tri côté UI
    items.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // date
          cmp = a.date.compareTo(b.date);
          break;
        case 1: // fournisseur
          cmp = a.fournisseur.toLowerCase().compareTo(
            b.fournisseur.toLowerCase(),
          );
          break;
        case 2: // libellé
          cmp = a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase());
          break;
        case 3: // n° facture
          cmp = (a.numeroFacture ?? '').toLowerCase().compareTo(
            (b.numeroFacture ?? '').toLowerCase(),
          );
          break;
        case 4: // montant
          cmp = a.montantTtc.compareTo(b.montantTtc);
          break;
        default:
          cmp = a.date.compareTo(b.date);
      }
      return _sortAscending ? cmp : -cmp;
    });

    final totalTtc = items.fold<double>(0.0, (s, d) => s + d.montantTtc);

    // Plage d’années libre : 2018 → année courante + 3
    final startYear = 2018, endYear = DateTime.now().year + 3;
    final years = List.generate(
      endYear - startYear + 1,
      (i) => startYear + i,
    ).reversed.toList();

    return Scaffold(
      backgroundColor: _bg,
      // appBar: AppBar(
      //   title: const Text('Dépenses'),
      //   elevation: 0,
      //   backgroundColor: Colors.white,
      //   foregroundColor: _ink,
      //   centerTitle: false,
      //   bottom: const PreferredSize(
      //     preferredSize: Size.fromHeight(1),
      //     child: Divider(height: 1, thickness: 1, color: _border),
      //   ),
      // ),
      body: Column(
        children: [
          // Filtres
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: _shadow,
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _fournLikeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Fournisseur (contient)',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<int?>(
                        value: _month,
                        decoration: InputDecoration(
                          labelText: 'Mois',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _border),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tous'),
                          ),
                          ...List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                        ],
                        onChanged: (v) => _month = v,
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<int?>(
                        value: _year,
                        decoration: InputDecoration(
                          labelText: 'Année',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _border),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        items: years
                            .map(
                              (y) =>
                                  DropdownMenuItem(value: y, child: Text('$y')),
                            )
                            .toList(),
                        onChanged: (v) => _year = v,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Appliquer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Effacer'),
                      style: TextButton.styleFrom(foregroundColor: _muted),
                    ),
                    const SizedBox(width: 8),
                    // PDF
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openPdfExportDialog,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.summarize,
                      label: 'Total : ${totalTtc.toStringAsFixed(2)} €',
                    ),
                    _StatChip(
                      icon: Icons.receipt_long,
                      label: '${items.length}',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tableau
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: items.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucune dépense.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        final table = DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowHeight: 36,
                          dataRowMinHeight: 30,
                          dataRowMaxHeight: 36,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                          headingRowColor: MaterialStateProperty.resolveWith(
                            (_) => Colors.white,
                          ),
                          columns: [
                            DataColumn(
                              label: const Text('Date'),
                              onSort: (i, asc) => setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              }),
                            ),
                            DataColumn(
                              label: const Text('Fournisseur'),
                              onSort: (i, asc) => setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              }),
                            ),
                            DataColumn(
                              label: const Text('Libellé'),
                              onSort: (i, asc) => setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              }),
                            ),
                            DataColumn(
                              label: const Text('N° facture'),
                              onSort: (i, asc) => setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              }),
                            ),
                            DataColumn(
                              label: const Text('Montant TTC'),
                              numeric: true,
                              onSort: (i, asc) => setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              }),
                            ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: items.map((d) {
                            final hasNum = (d.numeroFacture ?? '')
                                .trim()
                                .isNotEmpty;
                            return DataRow(
                              cells: [
                                DataCell(Text(_df(d.date))),
                                DataCell(Text(d.fournisseur)),
                                DataCell(Text(d.libelle)),
                                DataCell(Text(hasNum ? d.numeroFacture! : '—')),
                                DataCell(Text(_euros(d.montantTtc))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Modifier',
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                        onPressed: () => _edit(d),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        onPressed: () => _delete(d),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        );

                        // Cadre pro autour du tableau
                        final framedTable = Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                            boxShadow: const [
                              BoxShadow(
                                color: _shadow,
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: table,
                        );

                        return Scrollbar(
                          thumbVisibility: true,
                          controller: _hScrollCtrl,
                          notificationPredicate: (n) =>
                              n.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _hScrollCtrl,
                            child: Scrollbar(
                              thumbVisibility: true,
                              controller: _vScrollCtrl,
                              notificationPredicate: (n) =>
                                  n.metrics.axis == Axis.vertical,
                              child: SingleChildScrollView(
                                controller: _vScrollCtrl,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: framedTable,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const muted = _DepensesListScreenState._muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // bleu très clair
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: muted),
          ),
        ],
      ),
    );
  }
}
