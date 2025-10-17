// lib/views/incidents_dashboard_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
import '../services/incident_dao.dart'; // IncidentArretSplit, IncidentBaseCount

// ────────────────────────────────────────────────────────────────────────────
// Palette/Style — alignée avec IncidentsListScreen & DepensesListScreen
const _brand = Color(0xFF0B5FFF); // bleu corporate
const _ink = Color(0xFF0F172A); // slate-900
const _muted = Color(0xFF64748B); // slate-500
const _bg = Color(0xFFF1F5F9); // slate-100 (fond)
const _cardBg = Color(0xFFF8FAFC); // slate-50 (cartes)
const _border = Color(0xFFE2E8F0); // slate-200
const _shadow = Color(0x1A0F172A); // 10% opacity

// Déco champ uniforme
InputDecoration _decField({required String label, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _brand, width: 1.2),
      ),
    );

// Palette dégradés pour KPI/heatmap
const List<List<Color>> _palette = [
  [Color(0xFF4facfe), Color(0xFF00f2fe)],
  [Color(0xFF5ee7df), Color(0xFFb490ca)],
  [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
  [Color(0xFFf6d365), Color(0xFFfda085)],
  [Color(0xFF84fab0), Color(0xFF8fd3f4)],
];

class IncidentsDashboardScreen extends StatefulWidget {
  const IncidentsDashboardScreen({super.key});

  @override
  State<IncidentsDashboardScreen> createState() =>
      _IncidentsDashboardScreenState();
}

class _IncidentsDashboardScreenState extends State<IncidentsDashboardScreen> {
  int? _selectedYear; // null = toutes années

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year; // par défaut : année courante
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<IncidentProvider>();

    // Années 2018 → année courante + 3 (même si pas de données)
    final int startYear = 2018;
    final int endYear = DateTime.now().year + 3;
    final years =
        List.generate(
          endYear - startYear + 1,
          (i) => startYear + i,
        ).reversed.toList();

    final titleSuffix =
        _selectedYear == null ? '— toutes années' : '— ${_selectedYear!}';

    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ───────── Header combiné (sélecteur d’année + KPI) sur UNE LIGNE
          LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 980; // seuil responsive

              final filterCard = Container(
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 18, color: _muted),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedYear,
                        decoration: _decField(label: 'Année'),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Toutes années'),
                          ),
                          ...years.map(
                            (y) => DropdownMenuItem<int?>(
                              value: y,
                              child: Text('$y'),
                            ),
                          ),
                        ],
                        onChanged: (y) => setState(() => _selectedYear = y),
                      ),
                    ),
                  ],
                ),
              );

              final kpiArea = FutureBuilder(
                future: Future.wait([
                  prov.totalCount(year: _selectedYear), // 0
                  prov.arretSplit(year: _selectedYear), // 1
                ]),
                builder: (context, AsyncSnapshot<List<Object>> snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final yearTotal = snap.data![0] as int;
                  final yearSplit = snap.data![1] as IncidentArretSplit;

                  final cards = Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _KpiCard(
                        title: 'Incidents $titleSuffix',
                        value: '$yearTotal',
                        gradient: _palette[2],
                      ),
                      _KpiCard(
                        title: 'Arrêts (OUI) $titleSuffix',
                        value: '${yearSplit.yes}',
                        gradient: _palette[1],
                      ),
                      _KpiCard(
                        title: 'Arrêts (NON) $titleSuffix',
                        value: '${yearSplit.no}',
                        gradient: const [Color(0xFF6C63FF), Color(0xFF8EA8FF)],
                      ),
                    ],
                  );

                  return cards;
                },
              );

              if (wide) {
                // Même LIGNE : filtre (à gauche) + KPI (à droite)
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // largeur fixe/mini pour le filtre
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 520,
                      ),
                      child: filterCard,
                    ),
                    const SizedBox(width: 12),
                    // KPI prend le reste
                    Expanded(child: kpiArea),
                  ],
                );
              } else {
                // Écran étroit : on empile (sécurité responsive)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [filterCard, const SizedBox(height: 12), kpiArea],
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // ───────── Section heatmap Base × Mois
          _Section(
            title: 'Répartition par base × mois $titleSuffix',
            child: _BaseMonthMatrix(year: _selectedYear),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// DataTable Base × Mois avec heatmap + Scrollbar horizontal CORRIGÉ
class _BaseMonthMatrix extends StatefulWidget {
  final int? year; // null = toutes années
  const _BaseMonthMatrix({required this.year});

  @override
  State<_BaseMonthMatrix> createState() => _BaseMonthMatrixState();
}

class _BaseMonthMatrixState extends State<_BaseMonthMatrix> {
  final ScrollController _hCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<IncidentProvider>();

    // On charge 12 listes (par mois). year == null → agrégé toutes années.
    final futures = List.generate(
      12,
      (i) => prov.countByBase(year: widget.year, month: i + 1),
    );

    return FutureBuilder<List<List<IncidentBaseCount>>>(
      future: Future.wait(futures),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final monthlyLists = snap.data!; // 12 éléments (mois 1..12)

        // Ensemble de toutes les bases rencontrées
        final basesSet = <String>{};
        for (final list in monthlyLists) {
          for (final e in list) basesSet.add(e.base);
        }
        final bases = basesSet.toList()..sort(); // tri alpha
        final baseIndex = {for (int i = 0; i < bases.length; i++) bases[i]: i};

        // Matrice counts[mois][base] et totaux
        final counts = List.generate(
          12,
          (_) => List<int>.filled(bases.length, 0),
        );
        final rowTotals = List<int>.filled(12, 0);
        final colTotals = List<int>.filled(bases.length, 0);

        for (int m = 0; m < 12; m++) {
          for (final e in monthlyLists[m]) {
            final idx = baseIndex[e.base]!;
            counts[m][idx] = e.count;
            rowTotals[m] += e.count;
            colTotals[idx] += e.count;
          }
        }

        // Valeur max globale pour l’échelle de la heatmap
        final globalMax = [
          ...counts.expand((row) => row),
          ...rowTotals,
          ...colTotals,
        ].fold<int>(0, (acc, v) => math.max(acc, v));
        final safeMax = globalMax == 0 ? 1 : globalMax;

        // ----- DataTable stylée -----
        final table = DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
          headingRowColor: MaterialStateProperty.resolveWith(
            (_) => Colors.white,
          ),
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(.28),
              width: 0.6,
            ),
            outside: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(.28),
              width: 0.8,
            ),
          ),
          columns: [
            const DataColumn(label: Text('Mois')),
            ...List.generate(bases.length, (i) {
              final colors = _palette[i % _palette.length];
              return DataColumn(
                label: Row(
                  children: [
                    _legendDot(colors.first),
                    const SizedBox(width: 6),
                    Text(bases[i]),
                  ],
                ),
              );
            }),
            const DataColumn(label: Text('Total')),
          ],
          rows: List.generate(12, (m) {
              return DataRow(
                cells: [
                  DataCell(Text(_monthNameShort(m + 1))),
                  ...List.generate(bases.length, (b) {
                    final v = counts[m][b];
                    final cell = _heatCell(
                      context: context,
                      value: v,
                      max: safeMax,
                      color: _palette[b % _palette.length].first,
                    );
                    return DataCell(cell);
                  }),
                  DataCell(_totalPill(context, rowTotals[m])),
                ],
              );
            })
            // Ligne "Total"
            ..add(
              DataRow(
                color: MaterialStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25),
                ),
                cells: [
                  const DataCell(
                    Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...List.generate(
                    bases.length,
                    (b) => DataCell(_totalPill(context, colTotals[b])),
                  ),
                  DataCell(
                    _totalPill(context, rowTotals.fold(0, (a, b) => a + b)),
                  ),
                ],
              ),
            ),
        );

        // Cadre pro autour du tableau
        final framed = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: table,
        );

        // ✅ Scrollbar + SingleChildScrollView partagent _hCtrl (corrige l’assertion)
        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 680),
              child: framed,
            ),
          ),
        );
      },
    );
  }

  // ── helpers UI ─────────────────────────────────────────────
  Widget _heatCell({
    required BuildContext context,
    required int value,
    required int max,
    required Color color,
  }) {
    final double t = (value / max).clamp(0.0, 1.0);
    final bg = color.withOpacity(0.12 + (0.28 * t)); // 0.12 → 0.40
    final useWhite = t > 0.55;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        '$value',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color:
              useWhite ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _totalPill(BuildContext context, int v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondary.withOpacity(.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$v',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.secondary,
      ),
    ),
  );

  String _monthNameShort(int m) {
    const names = [
      'Janv',
      'Févr',
      'Mars',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sept',
      'Oct',
      'Nov',
      'Déc',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  Widget _legendDot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// UI helpers
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final List<Color> gradient;
  const _KpiCard({
    required this.title,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      constraints: const BoxConstraints(minWidth: 170),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: Colors.white.withOpacity(.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
