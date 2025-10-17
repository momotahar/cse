// lib/views/reglements_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../models/reglement.dart';
import '../providers/reglement_provider.dart';
import '../providers/commande_provider.dart';
import '../models/commande.dart';

// PDF & fichiers
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReglementsScreen extends StatefulWidget {
  const ReglementsScreen({super.key});

  @override
  State<ReglementsScreen> createState() => _ReglementsScreenState();
}

class _ReglementsScreenState extends State<ReglementsScreen> {
  final _searchCtrl = TextEditingController();

  Timer? _debounce;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  final _hScrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  static const Color kBlue = Color(0xFF1E88E5);
  static const PdfColor kPdfBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor kPdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor kPdfOddRow = PdfColor.fromInt(0xFFF7FBFF);
  static const PdfColor kPdfTableLine = PdfColor.fromInt(0xFFDDDDDD);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReglementProvider>().loadReglements();
      context.read<CommandeProvider>().loadCommandes();
    });

    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Helpers ID ─────────────────────────
  // Convertit n’importe quelle forme d’ID (int/double/String "12" ou "12.0")
  // en int. Renvoie null si impossible.
  int? _toIntId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      // tolère "12.0"
      final asNum = num.tryParse(s);
      return asNum?.toInt();
    }
    return int.tryParse(v.toString());
  }

  String _agentFromCommandeId(dynamic commandeId, Map<int, Commande> byCmdId) {
    final key = _toIntId(commandeId);
    if (key == null) return '—';
    final agent = (byCmdId[key]?.agent ?? '').trim();
    return agent.isEmpty ? '—' : agent;
  }

  @override
  Widget build(BuildContext context) {
    final regsProv = context.watch<ReglementProvider>();
    final cmdProv = context.watch<CommandeProvider>();

    // Index des commandes par ID int
    final Map<int, Commande> byCmdId = {
      for (final c in cmdProv.commandes)
        if (c.id != null) c.id!: c,
    };

    // base des lignes
    final items = List<Reglement>.from(regsProv.reglements);

    // filtre
    final q = _searchCtrl.text.trim().toLowerCase();
    final rowsData = items.where((r) {
      final agent = _agentFromCommandeId(r.commandeId, byCmdId).toLowerCase();
      final mode = (r.mode).toLowerCase();
      final cheque = (r.numeroCheque ?? '').toLowerCase();
      if (q.isEmpty) return true;
      return agent.contains(q) || mode.contains(q) || cheque.contains(q);
    }).toList();

    // tri
    if (_sortColumnIndex != null) {
      rowsData.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0: // DATE
            cmp = DateTime.parse(
              a.dateIso,
            ).compareTo(DateTime.parse(b.dateIso));
            break;
          case 1: // AGENT
            final aAgent = _agentFromCommandeId(
              a.commandeId,
              byCmdId,
            ).toLowerCase();
            final bAgent = _agentFromCommandeId(
              b.commandeId,
              byCmdId,
            ).toLowerCase();
            cmp = aAgent.compareTo(bAgent);
            break;
          case 2: // MONTANT
            cmp = a.montant.compareTo(b.montant);
            break;
          case 3: // MODE
            cmp = a.mode.toLowerCase().compareTo(b.mode.toLowerCase());
            break;
          case 4: // N° CHÈQUE
            cmp = (a.numeroCheque ?? '').toLowerCase().compareTo(
              (b.numeroCheque ?? '').toLowerCase(),
            );
            break;
          default:
            cmp = DateTime.parse(
              a.dateIso,
            ).compareTo(DateTime.parse(b.dateIso));
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Règlements'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('PDF', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: rowsData.isEmpty
                  ? null
                  : () => _exportPdf(rowsData, byCmdId),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Filtrer (agent / mode / n° chèque)…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          // Tableau
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: rowsData.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucun règlement.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        final table = _buildReglementsTable(rowsData, byCmdId);
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
                                  child: table,
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

  DataTable _buildReglementsTable(
    List<Reglement> rowsData,
    Map<int, Commande> byCmdId,
  ) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      columnSpacing: 36,
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 36,
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      columns: [
        DataColumn(
          label: const Text('DATE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('AGENT'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('MONTANT (€)'),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('MODE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('N° CHÈQUE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        const DataColumn(label: Text('ACTIONS')),
      ],
      rows: rowsData.map((r) {
        final agent = _agentFromCommandeId(r.commandeId, byCmdId);
        return DataRow(
          cells: [
            DataCell(Text(_fmtDate(DateTime.parse(r.dateIso)))),
            DataCell(Text(agent)),
            DataCell(Text('${_fmtMoney(r.montant)} €')),
            DataCell(Text(_fmtMode(r.mode))),
            DataCell(Text(r.numeroCheque ?? '—')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                    onPressed: r.id == null
                        ? null
                        : () => _openEditReglementDialog(r),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: r.id == null
                        ? null
                        : () => _confirmDelete(r.id!),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // --------- EXPORT PDF ---------

  Future<void> _exportPdf(
    List<Reglement> rows,
    Map<int, Commande> byCmdId,
  ) async {
    try {
      final bytes = await _buildReglementsPdfBytes(
        rows,
        byCmdId,
        PdfPageFormat.a4,
      );
      final dir = await getTemporaryDirectory();
      final name =
          'reglements_${DateTime.now().toIso8601String().split('T').first}.pdf';
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

  Future<Uint8List> _buildReglementsPdfBytes(
    List<Reglement> rows,
    Map<int, Commande> byCmdId,
    PdfPageFormat format,
  ) async {
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    final total = rows.fold<double>(0.0, (s, r) => s + r.montant);

    final data = rows.map<List<String>>((r) {
      final agent = _agentFromCommandeId(r.commandeId, byCmdId);
      return [
        _fmtDate(DateTime.parse(r.dateIso)),
        agent,
        '${_fmtMoney(r.montant)} €',
        _fmtMode(r.mode),
        r.numeroCheque ?? '—',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: kPdfBlue,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Rapport des règlements',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                ),
                pw.Text(
                  'Généré le ${_fmtDate(DateTime.now())}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'DATE',
              'AGENT',
              'MONTANT (€)',
              'MODE',
              'N° CHÈQUE',
            ],
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: kPdfHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: kPdfTableLine, width: 0.4),
              outside: const pw.BorderSide(color: kPdfTableLine, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.8),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.1),
              4: pw.FlexColumnWidth(1.6),
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: const {2: pw.Alignment.centerRight},
            oddRowDecoration: const pw.BoxDecoration(color: kPdfOddRow),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: kPdfBlue, width: 1.2),
              ),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTAL : ${total.toStringAsFixed(2)} €',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: kPdfBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // --------- EDIT / DELETE ---------

  Future<void> _openEditReglementDialog(Reglement r) async {
    final formKey = GlobalKey<FormState>();

    final regsProv = context.read<ReglementProvider>();
    final cmdProv = context.read<CommandeProvider>();

    final byCmdId = {
      for (final c in cmdProv.commandes)
        if (c.id != null) c.id!: c,
    };
    final Commande? commande = byCmdId[_toIntId(r.commandeId)];

    DateTime selectedDate = DateTime.parse(r.dateIso);
    final dateCtrl = TextEditingController(text: _fmtDate(selectedDate));
    final montantCtrl = TextEditingController(
      text: r.montant.toStringAsFixed(2),
    );
    String? modeSel = r.mode;
    final chequeCtrl = TextEditingController(text: r.numeroCheque ?? '');

    const displayToStore = {
      'Chèque': 'CHEQUE',
      'CB': 'CB',
      'Virement': 'VIREMENT',
      'Espèces': 'ESPECES',
      'Autres': 'AUTRES',
    };

    Future<void> pickDateLocal() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
        helpText: 'Sélectionner une date',
        locale: const Locale('fr', 'FR'),
      );
      if (picked != null) {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
        dateCtrl.text = _fmtDate(selectedDate);
      }
    }

    double? parseMontant(String s) {
      final v = s.trim().replaceAll(',', '.');
      return double.tryParse(v);
    }

    double resteAutorise() {
      final totalDue = commande?.montantCse ?? double.infinity;
      final sumOthers = regsProv.reglements
          .where(
            (x) =>
                _toIntId(x.commandeId) == _toIntId(r.commandeId) &&
                x.id != r.id,
          )
          .fold<double>(0.0, (s, x) => s + x.montant);
      return (totalDue - sumOthers).clamp(0.0, double.infinity);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('MODIFIER LE RÈGLEMENT'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Choisir une date',
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: pickDateLocal,
                      ),
                    ),
                    onTap: pickDateLocal,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: montantCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant (€)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = parseMontant(v ?? '');
                      if (n == null || n < 0) return 'Saisir un montant valide';
                      final plafond = resteAutorise();
                      if (n > plafond + 1e-6) {
                        return 'Montant ≤ reste dû : ${_fmtMoney(plafond)} €';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: modeSel,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Mode de règlement',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: displayToStore.keys
                        .map(
                          (label) => DropdownMenuItem(
                            value: displayToStore[label],
                            child: Text(label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => modeSel = v),
                    validator: (v) => (v == null) ? 'Choisir un mode' : null,
                  ),
                  if (modeSel == 'CHEQUE') const SizedBox(height: 8),
                  if (modeSel == 'CHEQUE')
                    TextFormField(
                      controller: chequeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° de chèque',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (modeSel == 'CHEQUE' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Saisir le n° de chèque';
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                final updated = Reglement(
                  id: r.id,
                  commandeId: r.commandeId,
                  mode: modeSel!,
                  numeroCheque: modeSel == 'CHEQUE'
                      ? chequeCtrl.text.trim()
                      : null,
                  montant: parseMontant(montantCtrl.text.trim())!,
                  dateIso: DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                  ).toIso8601String(),
                );

                try {
                  await context.read<ReglementProvider>().updateReglement(
                    updated,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Règlement modifié')));
    }

    dateCtrl.dispose();
    montantCtrl.dispose();
    chequeCtrl.dispose();
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Supprimer ce règlement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await context.read<ReglementProvider>().deleteReglement(id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Règlement supprimé')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
      }
    }
  }

  // --------- Helpers ---------

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  String _fmtMode(String m) {
    switch (m.toUpperCase()) {
      case 'CHEQUE':
        return 'Chèque';
      case 'CB':
        return 'CB';
      case 'VIREMENT':
        return 'Virement';
      case 'ESPECES':
        return 'Espèces';
      default:
        return 'Autres';
    }
  }
}
