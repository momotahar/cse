// lib/views/incidents_list_screen.dart
// ignore_for_file: deprecated_member_use, unnecessary_string_interpolations, use_build_context_synchronously

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

import '../models/incident.dart';
import '../providers/incident_provider.dart';
import 'incidents_form_screen.dart';

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen> {
  // ===== Palette alignée sur DepensesListScreen =====
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _ink = Color(0xFF0F172A); // slate-900
  static const _muted = Color(0xFF64748B); // slate-500
  static const _cardBg = Color(0xFFF8FAFC); // slate-50
  static const _bg = Color(0xFFF1F5F9); // slate-100
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _shadow = Color(0x1A0F172A); // 10% opacité

  // Filtres
  final _agentLikeCtrl = TextEditingController();
  String? _base;
  bool? _arret; // null = tous, true = oui, false = non
  int? _month;
  int? _year;

  // Tri tableau
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Scrollbars stables (H + V)
  final _hScrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  // Date format
  final DateFormat _df = DateFormat('dd/MM/yyyy');
  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    try {
      return _df.format(dt);
    } catch (_) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$d/$m/$y';
    }
  }

  // Couleurs PDF
  static const PdfColor _pdfBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _pdfOddRow = PdfColor.fromInt(0xFFF7FBFF);
  static const PdfColor _pdfLine = PdfColor.fromInt(0xFFDDDDDD);

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year; // année courante par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<IncidentProvider>().filterByYear(_year!);
    });
  }

  @override
  void dispose() {
    _agentLikeCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  // ---------- Filtres : période PUIS filtres additionnels ----------
  Future<void> _apply() async {
    final prov = context.read<IncidentProvider>();

    // Étape 1 : charger la période
    if (_year != null && _month != null) {
      await prov.filterByMonthYear(month: _month!, year: _year!);
    } else if (_year != null) {
      await prov.filterByYear(_year!);
    } else {
      await prov.refresh(); // dataset "global" si pas de borne temporelle
    }

    // Étape 2 : appliquer base/arrêt/agent sur le dataset courant
    await prov.setFilters(
      base: (_base ?? '').isEmpty ? null : _base,
      arretTravail: _arret,
      agentLike: _agentLikeCtrl.text.trim().isEmpty
          ? null
          : _agentLikeCtrl.text.trim(),
    );
  }

  Future<void> _clear() async {
    setState(() {
      _agentLikeCtrl.clear();
      _base = null;
      _arret = null;
      _month = null;
      _year = DateTime.now().year;
    });
    await context.read<IncidentProvider>().filterByYear(_year!);
    await context.read<IncidentProvider>().setFilters(
      base: null,
      arretTravail: null,
      agentLike: null,
    );
  }

  // Navigation d’édition (page complète). Assure-toi que IncidentsFormScreen est un Scaffold.
  Future<void> _edit(Incident inc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncidentsFormScreen(incident: inc),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    await context.read<IncidentProvider>().refresh();
    await _apply(); // ré-appliquer les filtres courants après édition
  }

  Future<void> _delete(Incident inc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet incident ?'),
        content: Text(
          '${inc.agentNom} • ${inc.base} • ${_fmt(inc.dateIncident)}',
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
      await context.read<IncidentProvider>().deleteIncident(inc.id!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident supprimé.')));
      }
      await _apply();
    }
  }

  // ---------- Export PDF ----------
  Future<void> _openPdfExportDialog() async {
    // valeurs préremplies avec l’état courant
    String agentLike = _agentLikeCtrl.text.trim();
    String base = _base ?? '';
    bool? arret = _arret;
    int? selMonth = _month;
    int? selYear = _year;

    final startYear = 2018, endYear = DateTime.now().year + 3;
    final years = List.generate(endYear - startYear + 1, (i) => startYear + i);

    // bases disponibles au moment de l'export (depuis les incidents en mémoire)
    final provForBases = context.read<IncidentProvider>();
    final exportBases = <String>{
      ...provForBases.incidents
          .map((e) => (e.base).trim())
          .where((b) => b.isNotEmpty),
    }.toList()..sort();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Exporter — Incidents'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: agentLike),
                decoration: const InputDecoration(
                  labelText: 'Agent (contient)',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => agentLike = v.trim(),
              ),
              const SizedBox(height: 8),

              // ▼▼▼ Base -> Dropdown (au lieu d'un TextField) ▼▼▼
              DropdownButtonFormField<String?>(
                value: base.isEmpty ? null : base,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Base',
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(value: null, child: Text('Toutes')),
                  ...exportBases.map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  ),
                ],
                onChanged: (v) => setLocal(() => base = v ?? ''),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<bool?>(
                value: arret,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Arrêt de travail',
                  prefixIcon: Icon(Icons.health_and_safety_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: true, child: Text('Oui')),
                  DropdownMenuItem(value: false, child: Text('Non')),
                ],
                onChanged: (v) => setLocal(() => arret = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: selMonth,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Mois',
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  ...List.generate(
                    12,
                    (i) => i + 1,
                  ).map((m) => DropdownMenuItem(value: m, child: Text('$m'))),
                ],
                onChanged: (v) => setLocal(() => selMonth = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: selYear,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Année',
                  prefixIcon: Icon(Icons.event),
                ),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) => setLocal(() => selYear = v),
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
      // Synchronise l’écran puis applique les filtres
      setState(() {
        _agentLikeCtrl.text = agentLike;
        _base = base.isEmpty ? null : base;
        _arret = arret;
        _month = selMonth;
        _year = selYear;
      });
      await _apply();

      final rows = List<Incident>.from(
        context.read<IncidentProvider>().incidents,
      )..sort((a, b) => (a.dateIncident).compareTo(b.dateIncident));

      await _exportIncidentsPdf(
        rows: rows,
        month: _month,
        year: _year,
        base: _base,
        arret: _arret,
        agentLike: _agentLikeCtrl.text.trim(),
      );
    }
  }

  Future<void> _exportIncidentsPdf({
    required List<Incident> rows,
    int? month,
    int? year,
    String? base,
    bool? arret,
    String? agentLike,
  }) async {
    try {
      final bytes = await _buildIncidentsPdfBytes(
        rows: rows,
        month: month,
        year: year,
        base: base,
        arret: arret,
        agentLike: agentLike,
        format: PdfPageFormat.a4.landscape,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final partM = month == null ? 'all' : month.toString().padLeft(2, '0');
      final partY = year == null ? 'all' : '$year';
      final name = 'incidents_${partY}_${partM}_$ts.pdf';
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

  Future<Uint8List> _buildIncidentsPdfBytes({
    required List<Incident> rows,
    required PdfPageFormat format,
    int? month,
    int? year,
    String? base,
    bool? arret,
    String? agentLike,
  }) async {
    // Polices (accents / symbole €)
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
    if ((base ?? '').isNotEmpty) filters.add('Base : $base');
    if (arret != null) filters.add('Arrêt : ${arret ? 'Oui' : 'Non'}');
    if ((agentLike ?? '').isNotEmpty) {
      filters.add('Agent contient "$agentLike"');
    }
    final filterLine = filters.join(' • ');

    // Données tableau
    final headers = const [
      'DATE',
      'AGENT',
      'BASE',
      'ARRÊT',
      'CONTACT',
      'TÉLÉPHONE',
    ];

    String fmt(DateTime? dt) {
      if (dt == null) return '—';
      try {
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$d/$m/$y';
      }
    }

    final data = rows.map<List<String>>((inc) {
      return [
        fmt(inc.dateIncident),
        inc.agentNom,
        inc.base,
        inc.arretTravail ? 'Oui' : 'Non',
        fmt(inc.dateContact),
        (inc.telephone ?? '').trim().isEmpty ? '—' : inc.telephone!.trim(),
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
                'Liste des incidents',
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
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerLeft,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), // date
              1: pw.FlexColumnWidth(1.8), // agent
              2: pw.FlexColumnWidth(1.4), // base
              3: pw.FlexColumnWidth(0.9), // arrêt
              4: pw.FlexColumnWidth(1.2), // contact
              5: pw.FlexColumnWidth(1.2), // téléphone
            },
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total lignes : ${rows.length}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: _pdfBlue,
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<IncidentProvider>();
    final items = List<Incident>.from(prov.incidents);

    // bases disponibles (pour le bandeau de filtres)
    final bases = <String>{
      ...items.map((e) => (e.base).trim()).where((b) => b.isNotEmpty),
    }.toList()..sort();

    // tri courant
    if (_sortColumnIndex != null) {
      items.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0: // date
            cmp = (a.dateIncident).compareTo(b.dateIncident);
            break;
          case 1: // agent
            cmp = (a.agentNom).toLowerCase().compareTo(
              (b.agentNom).toLowerCase(),
            );
            break;
          case 2: // base
            cmp = (a.base).toLowerCase().compareTo((b.base).toLowerCase());
            break;
          case 3: // arrêt
            cmp = (a.arretTravail ? 1 : 0).compareTo(b.arretTravail ? 1 : 0);
            break;
          case 4: // contact
            cmp = (a.dateContact ?? DateTime(9999)).compareTo(
              b.dateContact ?? DateTime(9999),
            );
            break;
          default:
            cmp = (a.dateIncident).compareTo(b.dateIncident);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // plage d’années
    final startYear = 2018, endYear = DateTime.now().year + 3;
    final years = List.generate(
      endYear - startYear + 1,
      (i) => startYear + i,
    ).reversed.toList();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Filtres (carte stylée)
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
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _agentLikeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Agent',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ),

                    // ▼▼▼ Base -> Dropdown ▼▼▼
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        value: _base,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Base',
                          prefixIcon: const Icon(Icons.location_city),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(color: _border),
                          ),
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Toutes'),
                          ),
                          ...bases.map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _base = v),
                      ),
                    ),

                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<bool?>(
                        value: _arret,
                        decoration: InputDecoration(
                          labelText: 'Arrêt de travail',
                          prefixIcon: const Icon(
                            Icons.health_and_safety_outlined,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(color: _border),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tous')),
                          DropdownMenuItem(value: true, child: Text('Oui')),
                          DropdownMenuItem(value: false, child: Text('Non')),
                        ],
                        onChanged: (v) => _arret = v,
                      ),
                    ),
                    SizedBox(
                      width: 110,
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
                      width: 110,
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
                    FilledButton.icon(
                      onPressed: _openPdfExportDialog,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.receipt_long,
                      label: '${items.length}',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tableau encadré (style pro)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final table = DataTable(
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columnSpacing: 85,
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
                        label: const Text('Agent'),
                        onSort: (i, asc) => setState(() {
                          _sortColumnIndex = i;
                          _sortAscending = asc;
                        }),
                      ),
                      DataColumn(
                        label: const Text('Base'),
                        onSort: (i, asc) => setState(() {
                          _sortColumnIndex = i;
                          _sortAscending = asc;
                        }),
                      ),
                      DataColumn(
                        label: const Text('Arrêt'),
                        onSort: (i, asc) => setState(() {
                          _sortColumnIndex = i;
                          _sortAscending = asc;
                        }),
                      ),
                      DataColumn(
                        label: const Text('Contact'),
                        onSort: (i, asc) => setState(() {
                          _sortColumnIndex = i;
                          _sortAscending = asc;
                        }),
                      ),
                      const DataColumn(label: Text('Téléphone')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: items.map((inc) {
                      return DataRow(
                        cells: [
                          DataCell(Text(_fmt(inc.dateIncident))),
                          DataCell(Text(inc.agentNom)),
                          DataCell(Text(inc.base)),
                          DataCell(Text(inc.arretTravail ? 'Oui' : 'Non')),
                          DataCell(Text(_fmt(inc.dateContact))),
                          DataCell(
                            Text(
                              (inc.telephone ?? '').trim().isEmpty
                                  ? '—'
                                  : inc.telephone!.trim(),
                            ),
                          ),
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
                                  onPressed: () => _edit(inc),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => _delete(inc),
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
    const muted = _IncidentsListScreenState._muted;
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
