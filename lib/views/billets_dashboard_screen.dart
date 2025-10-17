// lib/views/billets_dashboard_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unused_element_parameter

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/billet_provider.dart';
import '../providers/commande_provider.dart';
import '../providers/reglement_provider.dart';
import '../models/billet.dart';
import '../models/commande.dart';
import '../models/reglement.dart';

class BilletsDashboardScreen extends StatefulWidget {
  const BilletsDashboardScreen({super.key});

  @override
  State<BilletsDashboardScreen> createState() => _BilletsDashboardScreenState();
}

class _BilletsDashboardScreenState extends State<BilletsDashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billetsProv = context.read<BilletProvider>();
      final cmdProv = context.read<CommandeProvider>();
      final regProv = context.read<ReglementProvider>();

      if (billetsProv.billets.isEmpty) billetsProv.loadBillets();
      if (cmdProv.commandes.isEmpty) cmdProv.loadCommandes();
      if (regProv.reglements.isEmpty) regProv.loadReglements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final billets = context.watch<BilletProvider>().billets;
    final commandesAll = context.watch<CommandeProvider>().commandes;
    final regsAll = context.watch<ReglementProvider>().reglements;

    // bornes pour l’année
    final years = _availableYears(commandesAll);
    if (!years.contains(_selectedYear) && years.isNotEmpty) {
      _selectedYear = years.last;
    }

    // --- Mensuel (sélection) ---
    final monthCmds = commandesAll
        .where(
          (c) =>
              c.date.month == _selectedMonth &&
              c.date.year == _selectedYear &&
              c.id != null,
        )
        .toList();

    final byBilletId = {
      for (final b in billets)
        if (b.id != null) b.id!: b,
    };
    final monthCmdIds = monthCmds.map((c) => c.id!).toSet();
    final monthRegs = regsAll
        .where((r) => monthCmdIds.contains(r.commandeId))
        .toList();

    final statsMonth = _computeStats(
      commandes: monthCmds,
      reglements: monthRegs,
      billetsById: byBilletId,
    );

    // --- Annuel (cumuls) ---
    final yearCmds = commandesAll
        .where((c) => c.date.year == _selectedYear && c.id != null)
        .toList();
    final yearCmdIds = yearCmds.map((c) => c.id!).toSet();
    final yearRegs = regsAll
        .where((r) => yearCmdIds.contains(r.commandeId))
        .toList();

    final statsYear = _computeStats(
      commandes: yearCmds,
      reglements: yearRegs,
      billetsById: byBilletId,
    );

    // Comptes annuels par libellé (mini-chips)
    final libelleYearCounts = {
      for (final e in statsYear.byLibelle.entries) e.key: e.value.qte,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord — Billetterie'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.05, .4, 1],
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(.35),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // ───────── Cumuls annuels (pastilles + mini-chips par libellé)
            _TopStrip(
              year: _selectedYear,
              commandes: statsYear.nbCommandes,
              quantite: statsYear.totalQte,
              prixCse: statsYear.totalCse,
              prixNegos: statsYear.totalNegos,
              pleinPrix: statsYear.totalPlein,
              subvention: statsYear.totalSubvention,
              libelleCounts: libelleYearCounts,
            ),

            const SizedBox(height: 10),

            // ───────── LIGNE 1 : Filtres + KPI mensuels
            _ResponsiveRow(
              minTileWidth: 150, // compact pour afficher plus de cartes
              children: [
                _FiltersTile(
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                  years: years,
                  onChanged: (m, y) => setState(() {
                    _selectedMonth = m;
                    _selectedYear = y;
                  }),
                ),
                _KpiCard(
                  dense: true,
                  title: 'Commandes',
                  value: '${statsMonth.nbCommandes}',
                  gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                ),
                _KpiCard(
                  dense: true,
                  title: 'Quantité totale',
                  value: '${statsMonth.totalQte}',
                  gradient: const [Color(0xFF5ee7df), Color(0xFFb490ca)],
                ),
                _KpiCard(
                  dense: true,
                  title: 'Prix CSE',
                  value: _fmtMoney(statsMonth.totalCse),
                  suffix: '€',
                  gradient: const [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
                ),
                _KpiCard(
                  dense: true,
                  title: 'Prix négos',
                  value: _fmtMoney(statsMonth.totalNegos),
                  suffix: '€',
                  gradient: const [Color(0xFF7BC6CC), Color(0xFFBE93C5)],
                ),
                _KpiCard(
                  dense: true,
                  title: 'Plein Prix',
                  value: _fmtMoney(statsMonth.totalPlein),
                  suffix: '€',
                  gradient: const [Color(0xFFf6d365), Color(0xFFfda085)],
                ),
                _KpiCard(
                  dense: true,
                  title: 'Subvention CSE',
                  value: _fmtMoney(statsMonth.totalSubvention),
                  suffix: '€',
                  gradient: const [Color(0xFF84fab0), Color(0xFF8fd3f4)],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ───────── LIGNE 2 : Statut de paiement
            _PaymentStatusCard(
              title: 'Statut de paiement (mois sélectionné)',
              full: statsMonth.nbPayeesComplet,
              partial: statsMonth.nbPayeesPartiel,
              unpaid: statsMonth.nbNonPayees,
            ),

            const SizedBox(height: 14),

            // ───────── ANALYTIQUE : bloc unique en onglets
            _AnalyticsBlock(stats: statsMonth),
          ],
        ),
      ),
    );
  }

  List<int> _availableYears(List<Commande> all) {
    if (all.isEmpty) return [DateTime.now().year];
    final years = all.map((c) => c.date.year).toSet().toList()..sort();
    return years;
  }

  // --- AGRÉGATEUR ----------------------------------------------------------

  _Stats _computeStats({
    required List<Commande> commandes,
    required List<Reglement> reglements,
    required Map<int, Billet> billetsById,
  }) {
    const eps = 1e-6;

    int nbCommandes = commandes.length;
    int totalQte = 0;
    double totalCse = 0.0;
    double totalNegos = 0.0;
    double totalPlein = 0.0;
    int nbFull = 0, nbPartial = 0, nbNone = 0;

    final byLibelle = <String, _LibelleAgg>{};

    // Par base (et détail libellé)
    final byBase = <String, double>{}; // CSE
    final byBaseNegos = <String, double>{}; // Négos
    final byBaseQte = <String, int>{};
    final byBaseLibelle = <String, Map<String, _LibelleAgg>>{};

    // Par activité (et détail libellé)
    final byActivite = <String, double>{}; // CSE (pivot visuel)
    final byActiviteNegos = <String, double>{};
    final byActiviteQte = <String, int>{};
    final byActiviteLibelle = <String, Map<String, _LibelleAgg>>{};

    final paidByCmd = <int, double>{};

    for (final r in reglements) {
      paidByCmd.update(
        r.commandeId,
        (v) => v + r.montant,
        ifAbsent: () => r.montant,
      );
    }

    for (final c in commandes) {
      totalQte += c.qte;
      final billet = billetsById[c.billetId];

      final pleinUnit = (billet?.prixOriginal ?? c.prixCse);
      final negosUnit = (billet?.prixNegos ?? c.prixCse);
      final cseUnit = c.prixCse;

      final plein = pleinUnit * c.qte;
      final negos = negosUnit * c.qte;
      final cse = cseUnit * c.qte;
      final subv = plein - cse;

      totalCse += cse;
      totalNegos += negos;
      totalPlein += plein;

      final libKey = c.billetLibelle.toUpperCase();
      byLibelle.update(
        libKey,
        (old) => old.add(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
        ifAbsent: () => _LibelleAgg(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
      );

      // Base
      final base = c.base;
      byBase.update(base, (v) => v + cse, ifAbsent: () => cse);
      byBaseNegos.update(base, (v) => v + negos, ifAbsent: () => negos);
      byBaseQte.update(base, (v) => v + c.qte, ifAbsent: () => c.qte);
      final mapBaseLib = byBaseLibelle.putIfAbsent(
        base,
        () => <String, _LibelleAgg>{},
      );
      mapBaseLib.update(
        libKey,
        (old) => old.add(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
        ifAbsent: () => _LibelleAgg(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
      );

      // Activité (heuristique: segment 1 du libellé, avant "-" ou ":")
      final act = _extractActivity(c.billetLibelle);
      byActivite.update(act, (v) => v + cse, ifAbsent: () => cse);
      byActiviteNegos.update(act, (v) => v + negos, ifAbsent: () => negos);
      byActiviteQte.update(act, (v) => v + c.qte, ifAbsent: () => c.qte);
      final mapActLib = byActiviteLibelle.putIfAbsent(
        act,
        () => <String, _LibelleAgg>{},
      );
      mapActLib.update(
        libKey,
        (old) => old.add(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
        ifAbsent: () => _LibelleAgg(
          qte: c.qte,
          cse: cse,
          negos: negos,
          plein: plein,
          subvention: subv,
        ),
      );

      // Statut paiement (sur CSE)
      final paid = paidByCmd[c.id!] ?? 0.0;
      if (paid <= eps)
        nbNone++;
      else if (paid + eps >= cse)
        nbFull++;
      else
        nbPartial++;
    }

    return _Stats(
      nbCommandes: nbCommandes,
      totalQte: totalQte,
      totalCse: totalCse,
      totalNegos: totalNegos,
      totalPlein: totalPlein,
      totalSubvention: totalPlein - totalCse,
      nbPayeesComplet: nbFull,
      nbPayeesPartiel: nbPartial,
      nbNonPayees: nbNone,

      byLibelle: byLibelle,

      byBase: byBase,
      byBaseNegos: byBaseNegos,
      byBaseQte: byBaseQte,
      byBaseLibelle: byBaseLibelle,

      byActivite: byActivite,
      byActiviteNegos: byActiviteNegos,
      byActiviteQte: byActiviteQte,
      byActiviteLibelle: byActiviteLibelle,
    );
  }
}

// ===== UI helpers ===========================================================

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  const _ResponsiveRow({required this.children, this.minTileWidth = 170});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cons) {
        final w = cons.maxWidth;
        final perRow = (w / (minTileWidth + 12)).floor().clamp(
          1,
          children.length,
        );
        final itemWidth = (w - (12.0 * (perRow - 1))) / perRow;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

// ——— Palette de dégradés
const List<List<Color>> _softGradients = [
  [Color(0xFF4facfe), Color(0xFF00f2fe)],
  [Color(0xFF5ee7df), Color(0xFFb490ca)],
  [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
  [Color(0xFFf6d365), Color(0xFFfda085)],
  [Color(0xFF84fab0), Color(0xFF8fd3f4)],
  [Color(0xFF7BC6CC), Color(0xFFBE93C5)],
];

class _TopStrip extends StatelessWidget {
  final int year;
  final int commandes;
  final int quantite;
  final double prixCse;
  final double prixNegos;
  final double pleinPrix;
  final double subvention;
  final Map<String, int> libelleCounts;

  const _TopStrip({
    required this.year,
    required this.commandes,
    required this.quantite,
    required this.prixCse,
    required this.prixNegos,
    required this.pleinPrix,
    required this.subvention,
    required this.libelleCounts,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ).copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(.9));

    final entries = libelleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cumuls annuels $year', style: titleStyle),
        const SizedBox(height: 6),
        // Pastilles
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CircleKpi(
                value: '$commandes',
                label: 'Cdes',
                colors: _softGradients[0],
              ),
              const SizedBox(width: 6),
              _CircleKpi(
                value: '$quantite',
                label: 'Quantité',
                colors: _softGradients[1],
              ),
              const SizedBox(width: 6),
              _CircleKpi(
                value: _compactEuros(prixCse),
                label: 'Prix CSE',
                colors: _softGradients[2],
              ),
              const SizedBox(width: 6),
              _CircleKpi(
                value: _compactEuros(prixNegos),
                label: 'Prix négos',
                colors: _softGradients[5],
              ),
              const SizedBox(width: 6),
              _CircleKpi(
                value: _compactEuros(pleinPrix),
                label: 'Plein Prix',
                colors: _softGradients[3],
              ),
              const SizedBox(width: 6),
              _CircleKpi(
                value: _compactEuros(subvention),
                label: 'Subvention',
                colors: _softGradients[4],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Mini-chips par libellé
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                _MiniLibelleChip(
                  label: entries[i].key,
                  count: entries[i].value,
                  percent: quantite > 0
                      ? (entries[i].value / quantite) * 100
                      : 0,
                  colors: _softGradients[i % _softGradients.length],
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniLibelleChip extends StatelessWidget {
  final String label;
  final int count;
  final double percent;
  final List<Color> colors;
  const _MiniLibelleChip({
    required this.label,
    required this.count,
    required this.percent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = colors.first.withOpacity(.12);
    final c2 = colors.last.withOpacity(.12);
    final border = colors.last.withOpacity(.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      constraints: const BoxConstraints(minHeight: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_activity, size: 10),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
            ),
          ),
          const SizedBox(width: 5),
          _tinyPill('$count'),
          const SizedBox(width: 3),
          _tinyPill('${percent.isNaN ? 0 : percent.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _tinyPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CircleKpi extends StatelessWidget {
  final String value;
  final String label;
  final List<Color> colors;
  const _CircleKpi({
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final len = value.length;
    final double diameter = len <= 4
        ? 76
        : (len <= 6 ? 84 : (len <= 8 ? 92 : 100));
    final double fontSize = len <= 4
        ? 18
        : (len <= 6 ? 16 : (len <= 8 ? 14 : 12));

    return Column(
      children: [
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.8),
          ),
        ),
      ],
    );
  }
}

class _FiltersTile extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final List<int> years;
  final void Function(int month, int year) onChanged;

  const _FiltersTile({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.years,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final monthItems = List.generate(12, (i) => i + 1);
    final labelStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Container(
      constraints: const BoxConstraints(minWidth: 150), // réduit
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16), // légèrement réduit
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 8), // réduit
        child: Row(
          children: [
            // const Icon(Icons.calendar_month, size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButton<int>(
                value: selectedMonth,
                isExpanded: true,
                underline: const SizedBox(),
                items: monthItems
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(_monthNameFr(m), style: labelStyle),
                      ),
                    )
                    .toList(),
                onChanged: (m) => onChanged(m ?? selectedMonth, selectedYear),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                underline: const SizedBox(),
                items: years
                    .map(
                      (y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y', style: labelStyle),
                      ),
                    )
                    .toList(),
                onChanged: (y) => onChanged(selectedMonth, y ?? selectedYear),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- KPI card (ajout d’un mode compact/dense) ------------------------

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? suffix;
  final List<Color> gradient;

  /// Active un rendu plus petit (polices, padding, rayon, ombre, largeur mini).
  final bool dense;

  /// (Optionnel) Forcer une largeur mini personnalisée.
  final double? minWidth;
  final double scale; // ← NEW (1.0 = normal)
  const _KpiCard({
    required this.title,
    required this.value,
    required this.gradient,
    this.suffix,
    this.dense = false,
    this.minWidth,
    this.scale = 1.0, // ← NEW
  });

  @override
  Widget build(BuildContext context) {
    final s = scale.clamp(0.6, 1.2); // sécurité
    // Échelles compactes
    final double kMinWidth = minWidth ?? (dense ? 140 : 170) * s;
    final double padH = dense ? 10 : 14;
    final double padV = dense ? 8 : 12;
    final double radius = dense ? 14 : 18;
    final double blur = dense ? 8 : 12;

    final double titleFs = dense ? 11 : 12;
    final double valueFs = dense ? 20 : 24;
    final double suffixFs = dense ? 14 : 16;

    return Container(
      constraints: BoxConstraints(minWidth: kMinWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: blur,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleFs,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(.9),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: valueFs,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      suffix!,
                      style: TextStyle(
                        fontSize: suffixFs,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  final String title;
  final int full, partial, unpaid;
  const _PaymentStatusCard({
    this.title = 'Statut de paiement',
    required this.full,
    required this.partial,
    required this.unpaid,
  });

  @override
  Widget build(BuildContext context) {
    final totalNum = (full + partial + unpaid);
    final safeTotal = totalNum <= 0 ? 1 : totalNum; // éviter division par 0
    final fullP = full / safeTotal;
    final partP = partial / safeTotal;
    final noneP = unpaid / safeTotal;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  (Theme.of(context).textTheme.labelMedium ??
                          const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ))
                      .copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.85),
                      ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  _seg(widthFactor: fullP, color: Colors.green),
                  _seg(widthFactor: partP, color: Colors.orange),
                  _seg(widthFactor: noneP, color: Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _legendDot(color: Colors.green, label: 'Payées ($full)'),
                _legendDot(
                  color: Colors.orange,
                  label: 'Partielles ($partial)',
                ),
                _legendDot(color: Colors.red, label: 'Non payées ($unpaid)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg({required double widthFactor, required Color color}) {
    return Expanded(
      flex: (widthFactor * 1000).round(),
      child: Container(height: 12, color: color.withOpacity(.85)),
    );
  }

  Widget _legendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  (Theme.of(context).textTheme.titleMedium ??
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// =========================== ANALYTIQUE EN ONGLET ============================

class _AnalyticsBlock extends StatelessWidget {
  final _Stats stats;
  const _AnalyticsBlock({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Billets'),
                  Tab(text: 'Bases'),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 560, // laisse de la place aux listes
                child: TabBarView(
                  children: [
                    // --- Onglet 1 : Billets (classement par montants CSE + Négos etc)
                    _RankedPanel(
                      title: 'Par type de billet',
                      entries: stats.byLibelle.entries
                          .map(
                            (e) => _RowAgg(
                              label: e.key,
                              qte: e.value.qte,
                              cse: e.value.cse,
                              negos: e.value.negos,
                              plein: e.value.plein,
                              subv: e.value.subvention,
                            ),
                          )
                          .toList(),
                      totalForPercent: stats.totalCse,
                    ),

                    // --- Onglet 2 : Bases (répartition + détail par billet)
                    _BasesPanel(stats: stats),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowAgg {
  final String label;
  final int qte;
  final double cse, negos, plein, subv;
  _RowAgg({
    required this.label,
    required this.qte,
    required this.cse,
    required this.negos,
    required this.plein,
    required this.subv,
  });
}

class _RankedPanel extends StatelessWidget {
  final String title;
  final List<_RowAgg> entries;
  final double totalForPercent;
  const _RankedPanel({
    required this.title,
    required this.entries,
    required this.totalForPercent,
  });

  @override
  Widget build(BuildContext context) {
    final list = List<_RowAgg>.from(entries)
      ..sort((a, b) => b.cse.compareTo(a.cse));
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in list)
              _AggRowTile(
                label: e.label,
                qte: e.qte,
                cse: e.cse,
                negos: e.negos,
                plein: e.plein,
                subv: e.subv,
                percentOfTotal: totalForPercent > 0
                    ? (e.cse / totalForPercent) * 100
                    : 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _AggRowTile extends StatelessWidget {
  final String label;
  final int qte;
  final double cse, negos, plein, subv, percentOfTotal;
  const _AggRowTile({
    required this.label,
    required this.qte,
    required this.cse,
    required this.negos,
    required this.plein,
    required this.subv,
    required this.percentOfTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne titre + % + quantité
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(width: 6),
              _miniPill(
                '${percentOfTotal.isNaN ? 0 : percentOfTotal.toStringAsFixed(0)} %',
              ),
              const SizedBox(width: 6),
              _miniPill('$qte pcs'),
            ],
          ),
          const SizedBox(height: 8),
          _MoneyChipsRow(cse: cse, negos: negos, plein: plein, subv: subv),
        ],
      ),
    );
  }

  Widget _miniPill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.05),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

class _MoneyChipsRow extends StatelessWidget {
  final double cse, negos, plein, subv;
  const _MoneyChipsRow({
    required this.cse,
    required this.negos,
    required this.plein,
    required this.subv,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip('CSE', _fmtMoney(cse), const Color(0xFF6C63FF)),
        _chip('Négos', _fmtMoney(negos), const Color(0xFF24A0ED)),
        _chip('Plein', _fmtMoney(plein), const Color(0xFFF6A609)),
        _chip('Subv.', _fmtMoney(subv), const Color(0xFF00BFA6)),
      ],
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.4)),
        color: color.withOpacity(.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w400)),
          const SizedBox(width: 6),
          Text(
            '$value €',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: color.withOpacity(.95),
            ),
          ),
        ],
      ),
    );
  }
}

// ----- Bases (avec détail par billet) ---------------------------------------

class _BasesPanel extends StatelessWidget {
  final _Stats stats;
  const _BasesPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bases =
        stats.byBase.entries
            .map(
              (e) => _RowAgg(
                label: e.key,
                qte: stats.byBaseQte[e.key] ?? 0,
                cse: e.value,
                negos: stats.byBaseNegos[e.key] ?? 0,
                plein: (e.value + stats.totalSubvention * 0), // non exact ici
                subv: 0, // on reste focus CSE/Négos + qté
              ),
            )
            .toList()
          ..sort((a, b) => b.cse.compareTo(a.cse));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition des Billets par Base',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final b in bases)
              _BaseTile(
                base: b.label,
                qte: b.qte,
                cse: b.cse,
                negos: b.negos,
                // détail par billet :
                byLibelle:
                    stats.byBaseLibelle[b.label] ??
                    const <String, _LibelleAgg>{},
                baseTotalForPercent: stats.byBase[b.label] ?? 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _BaseTile extends StatelessWidget {
  final String base;
  final int qte;
  final double cse, negos;
  final Map<String, _LibelleAgg> byLibelle;
  final double baseTotalForPercent;
  const _BaseTile({
    required this.base,
    required this.qte,
    required this.cse,
    required this.negos,
    required this.byLibelle,
    required this.baseTotalForPercent,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        byLibelle.entries
            .map(
              (e) => _RowAgg(
                label: e.key,
                qte: e.value.qte,
                cse: e.value.cse,
                negos: e.value.negos,
                plein: e.value.plein,
                subv: e.value.subvention,
              ),
            )
            .toList()
          ..sort((a, b) => b.cse.compareTo(a.cse));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  base,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              _mini('$qte pcs'),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _MoneyChipsRow(cse: cse, negos: negos, plein: 0, subv: 0),
          ),
          children: [
            for (final it in items)
              _AggRowTile(
                label: it.label,
                qte: it.qte,
                cse: it.cse,
                negos: it.negos,
                plein: it.plein,
                subv: it.subv,
                percentOfTotal: baseTotalForPercent > 0
                    ? (it.cse / baseTotalForPercent) * 100
                    : 0,
              ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.05),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      s,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

// ===== Models d’agrégats ====================================================

class _LibelleAgg {
  final int qte;
  final double cse;
  final double negos;
  final double plein;
  final double subvention;
  _LibelleAgg({
    required this.qte,
    required this.cse,
    required this.negos,
    required this.plein,
    required this.subvention,
  });
  _LibelleAgg add({
    required int qte,
    required double cse,
    required double negos,
    required double plein,
    required double subvention,
  }) => _LibelleAgg(
    qte: this.qte + qte,
    cse: this.cse + cse,
    negos: this.negos + negos,
    plein: this.plein + plein,
    subvention: this.subvention + subvention,
  );
}

class _Stats {
  final int nbCommandes;
  final int totalQte;
  final double totalCse;
  final double totalNegos;
  final double totalPlein;
  final double totalSubvention;
  final int nbPayeesComplet;
  final int nbPayeesPartiel;
  final int nbNonPayees;

  final Map<String, _LibelleAgg> byLibelle;

  final Map<String, double> byBase; // CSE
  final Map<String, double> byBaseNegos;
  final Map<String, int> byBaseQte;
  final Map<String, Map<String, _LibelleAgg>> byBaseLibelle;

  final Map<String, double> byActivite; // CSE
  final Map<String, double> byActiviteNegos;
  final Map<String, int> byActiviteQte;
  final Map<String, Map<String, _LibelleAgg>> byActiviteLibelle;

  _Stats({
    required this.nbCommandes,
    required this.totalQte,
    required this.totalCse,
    required this.totalNegos,
    required this.totalPlein,
    required this.totalSubvention,
    required this.nbPayeesComplet,
    required this.nbPayeesPartiel,
    required this.nbNonPayees,
    required this.byLibelle,
    required this.byBase,
    required this.byBaseNegos,
    required this.byBaseQte,
    required this.byBaseLibelle,
    required this.byActivite,
    required this.byActiviteNegos,
    required this.byActiviteQte,
    required this.byActiviteLibelle,
  });
}

// ===== Helpers ==============================================================

String _monthNameFr(int m) {
  const names = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Jui',
    'Juil',
    'Août',
    'Sept',
    'Oct',
    'Nov',
    'Déc',
  ];
  final idx = (m - 1).clamp(0, 11);
  return names[idx];
}

String _fmtMoney(double v) => v.toStringAsFixed(2);
String _compactEuros(double v) => '${v.round()}€';

String _extractActivity(String libelle) {
  // Heuristique simple : avant " - " ou ":" ; sinon tout le libellé.
  var s = libelle.trim();
  final idxDash = s.indexOf(' - ');
  final idxColon = s.indexOf(':');
  int cut = -1;
  if (idxDash >= 0) cut = idxDash;
  if (idxColon >= 0 && (cut < 0 || idxColon < cut)) cut = idxColon;
  if (cut > 0) s = s.substring(0, cut);
  if (s.isEmpty) s = 'AUTRE';
  return s.toUpperCase();
}
