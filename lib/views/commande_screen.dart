// lib/views/commandes_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/billet_provider.dart';
import '../providers/commande_provider.dart';
import '../providers/reglement_provider.dart';
import '../models/billet.dart';
import '../models/commande.dart';
import '../models/reglement.dart';

// PDF & fichiers
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen> {
  // Filtre (barre de recherche)
  final _filterCtrl = TextEditingController();

  // Tri
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Scrollbars / contrôleurs stables
  final _hScrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  // Couleurs PDF
  static const Color kBlue = Color(0xFF1E88E5);
  static const PdfColor kPdfBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor kPdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor kPdfOddRow = PdfColor.fromInt(0xFFF7FBFF);
  static const PdfColor kPdfTableLine = PdfColor.fromInt(0xFFDDDDDD);

  // Bases
  static const List<String> _basesPresets = ['SUD', 'NORD', 'OUEST', 'AUTRE…'];

  static const double _kEps = 1e-6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BilletProvider>().loadBillets();
      context.read<CommandeProvider>().loadCommandes();
      context.read<ReglementProvider>().loadReglements();
    });
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billets = context.watch<BilletProvider>().billets;
    final byBilletId = {
      for (final b in billets)
        if (b.id != null) b.id!: b,
    };

    final provCmd = context.watch<CommandeProvider>();
    final all = provCmd.commandes;

    // Agrégats de paiement
    final regsProv = context.watch<ReglementProvider>();
    final totalsByCmd = regsProv.totalByCommande; // Map<int,double>

    // Filtre
    final q = _filterCtrl.text.trim().toLowerCase();
    final rows = all.where((c) {
      if (q.isEmpty) return true;
      return c.agent.toLowerCase().contains(q) ||
          c.base.toLowerCase().contains(q) ||
          c.billetLibelle.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    // Tri (0:DATE,1:LIB,2:QTE,3:MONTANT,4:AGENT,5:BASE,6:EMAIL)
    if (_sortColumnIndex != null) {
      rows.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.date.compareTo(b.date);
            break;
          case 1:
            cmp = a.billetLibelle.toLowerCase().compareTo(
              b.billetLibelle.toLowerCase(),
            );
            break;
          case 2:
            cmp = a.qte.compareTo(b.qte);
            break;
          case 3:
            cmp = a.montantCse.compareTo(b.montantCse);
            break;
          case 4:
            cmp = a.agent.toLowerCase().compareTo(b.agent.toLowerCase());
            break;
          case 5:
            cmp = a.base.toLowerCase().compareTo(b.base.toLowerCase());
            break;
          case 6:
            cmp = a.email.toLowerCase().compareTo(b.email.toLowerCase());
            break;
          default:
            cmp = a.date.compareTo(b.date);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes de billets'),
        actions: [
          // Export PDF
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
              onPressed: rows.isEmpty
                  ? null
                  : () => _exportPdf(rows, byBilletId, totalsByCmd),
            ),
          ),
          // Nouveau
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openCreateDialog(context),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black,
                child: Icon(Icons.add, color: Colors.white, size: 20),
              ),
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
                controller: _filterCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Filtrer (agent / base / libellé / e-mail)…',
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
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Tableau
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: rows.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucune commande.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        final table = _buildCommandesTable(
                          rows,
                          totalsByCmd,
                          byBilletId,
                        );
                        return Scrollbar(
                          thumbVisibility: true,
                          controller: _hScrollCtrl,
                          notificationPredicate: (notif) =>
                              notif.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _hScrollCtrl,
                            child: Scrollbar(
                              thumbVisibility: true,
                              controller: _vScrollCtrl,
                              notificationPredicate: (notif) =>
                                  notif.metrics.axis == Axis.vertical,
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

  // --- Table avec métriques identiques à BilletsScreen
  DataTable _buildCommandesTable(
    List<Commande> rows,
    Map<int, double> totalsByCmd,
    Map<int, Billet> byBilletId,
  ) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      columnSpacing: 36,
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 40,
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
          label: const Text('LIBELLÉ BILLET'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('QTÉ'),
          numeric: true,
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
          label: const Text('AGENT'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('BASE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('E-MAIL'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        const DataColumn(label: Text('ACTIONS')),
      ],
      rows: rows.map((c) {
        final totalPaid = (c.id != null) ? (totalsByCmd[c.id!] ?? 0.0) : 0.0;
        final totalDue = c.montantCse;
        final amountColor = _colorForStatus(totalDue, totalPaid);

        // Tooltip prix (Original / Négo / CSE unitaire)
        final billet = byBilletId[c.billetId];
        final priceTooltip = (billet == null)
            ? 'Tarifs : CSE ${_fmtMoney(c.prixCse)} €'
            : 'Tarifs : Original ${_fmtMoney(billet.prixOriginal)} € • Négo ${_fmtMoney(billet.prixNegos)} € • CSE ${_fmtMoney(c.prixCse)} €';

        return DataRow(
          cells: [
            DataCell(Text(_fmtDate(c.date))),
            DataCell(
              Tooltip(
                message: priceTooltip,
                child: Text(c.billetLibelle.toUpperCase()),
              ),
            ),
            DataCell(Text('${c.qte}')),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _fmtMoney(c.montantCse),
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // if (totalPaid > 0)
                  //   Text(
                  //     'Payé: ${_fmtMoney(totalPaid)}  •  Reste: ${_fmtMoney((totalDue - totalPaid).clamp(0.0, double.infinity))}',
                  //     style: TextStyle(
                  //       fontSize: 11,
                  //       color: Theme.of(
                  //         context,
                  //       ).colorScheme.onSurface.withOpacity(.7),
                  //     ),
                  //   ),
                ],
              ),
            ),
            DataCell(Text(c.agent)),
            DataCell(Text(c.base)),
            DataCell(Text(c.email)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Régler',
                    icon: const Icon(
                      Icons.payments_outlined,
                      color: Colors.blue,
                      size: 18,
                    ),
                    onPressed: () => _openReglementDialog(c),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                    onPressed: () => _editCommandeDialog(c),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _deleteCommande(c),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // --- Dialog de création
  Future<void> _openCreateDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();

    DateTime selectedDate = DateTime.now();
    final dateCtrl = TextEditingController(text: _fmtDate(selectedDate));
    int? selectedBilletId;
    final qteCtrl = TextEditingController(text: '1');
    final agentCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? baseSel;
    final baseOtherCtrl = TextEditingController();

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

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          final billets = context.watch<BilletProvider>().billets;
          return AlertDialog(
            title: const Text('NOUVELLE COMMANDE'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // Billet
                    DropdownButtonFormField<int>(
                      value: selectedBilletId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Billet',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: billets
                          .map(
                            (b) => DropdownMenuItem<int>(
                              value: b.id,
                              child: Text(b.libelle.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedBilletId = v),
                      validator: (v) => v == null ? 'Choisir un billet' : null,
                    ),
                    const SizedBox(height: 8),

                    // Quantité
                    TextFormField(
                      controller: qteCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Quantité invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Agent
                    TextFormField(
                      controller: agentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’agent',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // Email
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        final ok = RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(s);
                        if (!ok) return 'E-mail invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Base
                    DropdownButtonFormField<String>(
                      value: baseSel,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Base',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _basesPresets
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b,
                              child: Text(b),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => baseSel = v),
                      validator: (v) {
                        if (v == null) return 'Choisir une base';
                        if (v == 'AUTRE…' &&
                            baseOtherCtrl.text.trim().isEmpty) {
                          return 'Saisir la base';
                        }
                        return null;
                      },
                    ),
                    if (baseSel == 'AUTRE…') const SizedBox(height: 8),
                    if (baseSel == 'AUTRE…')
                      TextFormField(
                        controller: baseOtherCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la base',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (baseSel == 'AUTRE…' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Saisir la base';
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

                  final list = context.read<BilletProvider>().billets;
                  final Billet billet = list.firstWhere(
                    (b) => b.id == selectedBilletId,
                  );
                  final qte = int.parse(qteCtrl.text.trim());

                  final chosenBase =
                      (baseSel == 'AUTRE…'
                              ? baseOtherCtrl.text.trim()
                              : (baseSel ?? ''))
                          .toUpperCase();

                  final cmd = Commande(
                    id: null,
                    dateIso: DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                    ).toIso8601String(),
                    billetId: billet.id!,
                    billetLibelle: billet.libelle,
                    prixCse: billet.prixCse,
                    qte: qte,
                    agent: agentCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    base: chosenBase,
                  );

                  await context.read<CommandeProvider>().addCommande(cmd);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commande enregistrée')),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      // rechargement géré par le provider
    }

    // Nettoyage
    dateCtrl.dispose();
    qteCtrl.dispose();
    agentCtrl.dispose();
    emailCtrl.dispose();
    baseOtherCtrl.dispose();
  }

  Future<void> _openReglementDialog(Commande c) async {
    final formKey = GlobalKey<FormState>();

    final agent = c.agent;
    final totalDue = c.montantCse;

    final regsProv = context.read<ReglementProvider>();
    final alreadyPaid = (c.id != null) ? regsProv.paidFor(c.id!) : 0.0;
    final remaining = (totalDue - alreadyPaid).clamp(0.0, double.infinity);

    String? modeSel; // 'CHEQUE','CB','VIREMENT','ESPECES','AUTRES'
    final chequeCtrl = TextEditingController();
    final montantCtrl = TextEditingController(
      text: _fmtMoney(remaining > 0 ? remaining : totalDue),
    );

    double? parseAmount(String s) =>
        double.tryParse(s.trim().replaceAll(',', '.'));

    final Color statusColor = _colorForStatus(totalDue, alreadyPaid);
    final Color remainingColor = remaining <= _kEps ? Colors.green : Colors.red;

    Widget amountLine(String label, double amount, Color color) {
      final baseStyle = Theme.of(context).textTheme.bodyMedium!;
      return RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: _fmtMoney(amount),
              style: baseStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: ' €'),
          ],
        ),
      );
    }

    const displayToStore = {
      'Chèque': 'CHEQUE',
      'CB': 'CB',
      'Virement': 'VIREMENT',
      'Espèces': 'ESPECES',
      'Autres': 'AUTRES',
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('RÉGLEMENT DE LA COMMANDE'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Agent : $agent'),
                  const SizedBox(height: 6),
                  amountLine(
                    'Total :',
                    totalDue,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                  amountLine('Déjà payé :', alreadyPaid, statusColor),
                  amountLine('Reste :', remaining, remainingColor),
                  const Divider(height: 16),

                  TextFormField(
                    controller: montantCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant réglé (€)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final m = parseAmount(v ?? '');
                      if (m == null || m <= 0)
                        return 'Saisir un montant valide';
                      if (m > remaining + _kEps) {
                        return 'Ne doit pas dépasser le reste (${_fmtMoney(remaining)} €)';
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

                final montantSaisi = parseAmount(montantCtrl.text.trim())!;
                final reg = Reglement(
                  id: null,
                  commandeId: c.id!,
                  mode: modeSel!,
                  numeroCheque: modeSel == 'CHEQUE'
                      ? chequeCtrl.text.trim()
                      : null,
                  montant: montantSaisi,
                  dateIso: DateTime.now().toIso8601String(),
                );

                await context.read<ReglementProvider>().addReglement(reg);
                if (context.mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Règlement enregistré')),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) setState(() {}); // rafraîchir la couleur de statut

    montantCtrl.dispose();
    chequeCtrl.dispose();
  }

  Future<void> _deleteCommande(Commande c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Supprimer la commande de « ${c.billetLibelle.toUpperCase()} » pour ${c.agent} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<CommandeProvider>().deleteCommande(c.id!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commande supprimée')));
    }
  }

  Future<void> _editCommandeDialog(Commande c) async {
    final formKey = GlobalKey<FormState>();
    final qte = TextEditingController(text: '${c.qte}');
    final agent = TextEditingController(text: c.agent);
    final email = TextEditingController(text: c.email);

    DateTime date = c.date;
    final dateCtrl = TextEditingController(text: _fmtDate(date));

    // Prépa base (dropdown + éventuel "autre")
    final presets = _basesPresets.where((b) => b != 'AUTRE…').toList();
    String? baseSel = presets.contains(c.base) ? c.base : 'AUTRE…';
    final baseOtherCtrl = TextEditingController(
      text: presets.contains(c.base) ? '' : c.base,
    );

    Future<void> pickDateForEdit() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
        helpText: 'Sélectionner une date',
        locale: const Locale('fr', 'FR'),
      );
      if (picked != null) {
        date = DateTime(picked.year, picked.month, picked.day);
        dateCtrl.text = _fmtDate(date);
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Modifier la commande'),
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
                        onPressed: pickDateForEdit,
                      ),
                    ),
                    onTap: pickDateForEdit,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qte,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Quantité',
                      isDense: true,
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Quantité invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: agent,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’agent',
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      isDense: true,
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      final ok = RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(s);
                      if (!ok) return 'E-mail invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: baseSel,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Base',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...presets.map(
                        (b) => DropdownMenuItem(value: b, child: Text(b)),
                      ),
                      const DropdownMenuItem(
                        value: 'AUTRE…',
                        child: Text('AUTRE…'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => baseSel = v),
                    validator: (v) {
                      if (v == null) return 'Choisir une base';
                      if (v == 'AUTRE…' && baseOtherCtrl.text.trim().isEmpty) {
                        return 'Saisir la base';
                      }
                      return null;
                    },
                  ),
                  if (baseSel == 'AUTRE…') const SizedBox(height: 8),
                  if (baseSel == 'AUTRE…')
                    TextFormField(
                      controller: baseOtherCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la base',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (baseSel == 'AUTRE…' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Saisir la base';
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

                final baseOut =
                    (baseSel == 'AUTRE…'
                            ? baseOtherCtrl.text.trim()
                            : (baseSel ?? ''))
                        .toUpperCase();

                final updated = c.copyWith(
                  dateIso: DateTime(
                    date.year,
                    date.month,
                    date.day,
                  ).toIso8601String(),
                  qte: int.parse(qte.text.trim()),
                  agent: agent.text.trim(),
                  email: email.text.trim(),
                  base: baseOut,
                );

                await context.read<CommandeProvider>().updateCommande(updated);
                Navigator.pop(context, true);
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
      ).showSnackBar(const SnackBar(content: Text('Commande modifiée')));
    }

    qte.dispose();
    agent.dispose();
    email.dispose();
    dateCtrl.dispose();
    baseOtherCtrl.dispose();
  }

  // --------- EXPORT PDF ---------

  Future<void> _exportPdf(
    List<Commande> rows,
    Map<int, Billet> byBilletId,
    Map<int, double> totalsByCmd,
  ) async {
    try {
      final bytes = await _buildCommandesPdfBytes(
        rows,
        byBilletId,
        totalsByCmd,
        PdfPageFormat.a4,
      );
      final dir = await getTemporaryDirectory();
      final name =
          'commandes_${DateTime.now().toIso8601String().split('T').first}.pdf';
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

  Future<Uint8List> _buildCommandesPdfBytes(
    List<Commande> rows,
    Map<int, Billet> byBilletId,
    Map<int, double> totalsByCmd,
    PdfPageFormat format,
  ) async {
    // ---- POLICES embarquées pour afficher "€" correctement ----
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    // Totaux
    double totalCse = 0, totalPaid = 0;
    for (final c in rows) {
      totalCse += c.montantCse;
      totalPaid += (c.id != null) ? (totalsByCmd[c.id!] ?? 0.0) : 0.0;
    }
    final totalRest = (totalCse - totalPaid).clamp(0.0, double.infinity);

    // Lignes
    final data = rows.map<List<String>>((c) {
      final paid = (c.id != null) ? (totalsByCmd[c.id!] ?? 0.0) : 0.0;
      final rest = (c.montantCse - paid).clamp(0.0, double.infinity);
      // (facultatif) infos de prix depuis le billet :
      final billet = byBilletId[c.billetId];

      return [
        _fmtDate(c.date),
        c.agent,
        c.billetLibelle,
        '${c.qte}', // QTÉ
        '${_fmtMoney(c.prixCse)} €', // PRIX CSE U.
        '${_fmtMoney(c.montantCse)} €', // MONTANT CSE
        c.base,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          // En-tête
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
                  'Rapport des commandes',
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

          // Tableau
          pw.Table.fromTextArray(
            headers: const [
              'DATE',
              'AGENT',
              'BILLET',
              'QTÉ',
              'P.U. (€)',
              'MONT(€)',
              'BASE',
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
              0: pw.FlexColumnWidth(1.0), // DATE
              1: pw.FlexColumnWidth(1.6), // AGENT
              2: pw.FlexColumnWidth(2.1), // BILLET
              3: pw.FlexColumnWidth(0.7), // QTÉ
              4: pw.FlexColumnWidth(1.2), // PRIX CSE U.
              5: pw.FlexColumnWidth(1.2), // MONTANT CSE
              8: pw.FlexColumnWidth(1.2), // BASE
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: const {
              3: pw.Alignment.centerRight, // QTÉ
              4: pw.Alignment.centerRight, // PRIX CSE U.
              5: pw.Alignment.centerRight, // MONTANT CSE
            },
            oddRowDecoration: const pw.BoxDecoration(color: kPdfOddRow),
          ),

          pw.SizedBox(height: 10),

          // Totaux
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: kPdfBlue, width: 1.2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'TOTAL: ${totalCse.toStringAsFixed(2)} €    ',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: kPdfBlue,
                  ),
                ),
                // pw.Text(
                //   'PAYÉ : ${totalPaid.toStringAsFixed(2)} €    ',
                //   style: pw.TextStyle(
                //     fontWeight: pw.FontWeight.bold,
                //     color: kPdfBlue,
                //   ),
                // ),
                // pw.Text(
                //   'RESTE : ${totalRest.toStringAsFixed(2)} €',
                //   style: pw.TextStyle(
                //     fontWeight: pw.FontWeight.bold,
                //     color: kPdfBlue,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // --- Helpers --------------------------------------------------------------

  Color _colorForStatus(double totalDue, double paid) {
    if (paid <= _kEps) return Colors.red; // rien payé
    if (paid + _kEps >= totalDue) return Colors.green; // total payé
    return Colors.orange; // partiel
  }

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);
}
