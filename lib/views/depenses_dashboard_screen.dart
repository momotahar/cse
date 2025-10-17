// lib/views/depenses_dashboard_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/depense_provider.dart';
import '../services/depense_dao.dart'; // DepenseSupplierSum

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

class DepensesDashboardScreen extends StatefulWidget {
  const DepensesDashboardScreen({super.key});
  @override
  State<DepensesDashboardScreen> createState() =>
      _DepensesDashboardScreenState();
}

class _DepensesDashboardScreenState extends State<DepensesDashboardScreen> {
  int _selectedYear = DateTime.now().year;

  String _eur(double v) => '${v.toStringAsFixed(2)} €';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DepenseProvider>();

    // Années libres 2018 → année courante + 3 (même sans données)
    final startYear = 2018, endYear = DateTime.now().year + 3;
    final years =
        List.generate(
          endYear - startYear + 1,
          (i) => startYear + i,
        ).reversed.toList();

    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ───────── Header combiné (filtre + KPI) — même style que Incidents
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
                      child: DropdownButtonFormField<int>(
                        value: _selectedYear,
                        decoration: _decField(label: 'Année'),
                        items:
                            years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (y) => setState(
                              () => _selectedYear = y ?? _selectedYear,
                            ),
                      ),
                    ),
                  ],
                ),
              );

              // ✅ Correction de typage : FutureBuilder<List<num>>
              final kpiArea = FutureBuilder<List<num>>(
                future: Future.wait<num>([
                  prov
                      .totalAmount(year: _selectedYear)
                      .then((v) => v as num), // double -> num
                  prov
                      .invoiceCount(year: _selectedYear)
                      .then((v) => v as num), // int -> num
                ]),
                builder: (BuildContext context, AsyncSnapshot<List<num>> snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final total = (snap.data![0]).toDouble();
                  final count = (snap.data![1]).toInt();
                  final monthlyAvg = total / 12.0;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _KpiCard(
                        title: 'Total dépenses (année)',
                        value: _eur(total),
                        gradient: _palette[2],
                      ),
                      _KpiCard(
                        title: 'Nb de factures (année)',
                        value: '$count',
                        gradient: _palette[1],
                      ),
                      _KpiCard(
                        title: 'Dépense moyenne / mois',
                        value: _eur(monthlyAvg),
                        gradient: const [Color(0xFF6C63FF), Color(0xFF8EA8FF)],
                      ),
                    ],
                  );
                },
              );

              if (wide) {
                // Même LIGNE : filtre (gauche) + KPI (droite)
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 520,
                      ),
                      child: filterCard,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: kpiArea),
                  ],
                );
              } else {
                // Écran étroit : on empile
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [filterCard, const SizedBox(height: 12), kpiArea],
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // ───────── Section heatmap Fournisseur × Mois
          _Section(
            title: 'Répartition par fournisseur × mois — $_selectedYear',
            child: _SupplierMonthMatrix(year: _selectedYear),
          ),
        ],
      ),
    );
  }
}

/// Heatmap: lignes = 12 mois, colonnes = Top 6 fournisseurs (année) + Autres
class _SupplierMonthMatrix extends StatefulWidget {
  final int year;
  const _SupplierMonthMatrix({required this.year});

  @override
  State<_SupplierMonthMatrix> createState() => _SupplierMonthMatrixState();
}

class _SupplierMonthMatrixState extends State<_SupplierMonthMatrix> {
  final ScrollController _hCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<DepenseProvider>();

    // Charge la répartition par fournisseur pour chaque mois de l’année
    final futures = List.generate(
      12,
      (i) => prov.sumBySupplier(year: widget.year, month: i + 1),
    );

    return FutureBuilder<List<List<DepenseSupplierSum>>>(
      future: Future.wait(futures),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final monthlyLists = snap.data!; // 12 listes (m=1..12)

        // Agrège les totaux annuels par fournisseur
        final totalsBySupplier = <String, double>{};
        for (final list in monthlyLists) {
          for (final e in list) {
            totalsBySupplier.update(
              e.fournisseur,
              (v) => v + e.total,
              ifAbsent: () => e.total,
            );
          }
        }

        // Top K fournisseurs (évite 50 colonnes) + “Autres”
        const k = 6;
        final topSuppliers =
            totalsBySupplier.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        final top = topSuppliers.take(k).map((e) => e.key).toList();
        final hasOthers = totalsBySupplier.length > k;

        final columns = [...top, if (hasOthers) 'Autres'];
        final supplierIndex = {
          for (int i = 0; i < columns.length; i++) columns[i]: i,
        };

        // Matrice [mois][col] en €
        final matrix = List.generate(
          12,
          (_) => List<double>.filled(columns.length, 0),
        );
        final rowTotals = List<double>.filled(12, 0);
        final colTotals = List<double>.filled(columns.length, 0);

        for (int m = 0; m < 12; m++) {
          for (final e in monthlyLists[m]) {
            final colName =
                top.contains(e.fournisseur)
                    ? e.fournisseur
                    : (hasOthers ? 'Autres' : e.fournisseur);
            final idx = supplierIndex[colName]!;
            matrix[m][idx] += e.total;
            rowTotals[m] += e.total;
            colTotals[idx] += e.total;
          }
        }

        // Max global pour l’échelle de la heatmap
        final globalMax = [
          ...matrix.expand((r) => r),
          ...rowTotals,
          ...colTotals,
        ].fold<double>(0, (acc, v) => math.max(acc, v));
        final safeMax = globalMax <= 0 ? 1.0 : globalMax;

        // ----- DataTable stylée + cadre pro -----
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
            ...List.generate(columns.length, (i) {
              final colors = _palette[i % _palette.length];
              return DataColumn(
                label: Row(
                  children: [
                    _legendDot(colors.first),
                    const SizedBox(width: 6),
                    Text(columns[i]),
                  ],
                ),
              );
            }),
            const DataColumn(label: Text('Total')),
          ],
          rows: [
            // 12 lignes (mois)
            ...List.generate(
              12,
              (m) => DataRow(
                cells: [
                  DataCell(Text(_monthNameShort(m + 1))),
                  ...List.generate(
                    columns.length,
                    (c) => DataCell(
                      _heatCell(
                        context: context,
                        value: matrix[m][c],
                        max: safeMax,
                        color: _palette[c % _palette.length].first,
                      ),
                    ),
                  ),
                  DataCell(_totalPill(context, rowTotals[m])),
                ],
              ),
            ),
            // Ligne "Total année"
            DataRow(
              color: MaterialStatePropertyAll(
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25),
              ),
              cells: [
                const DataCell(
                  Text(
                    'Total année',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ...List.generate(
                  columns.length,
                  (c) => DataCell(_totalPill(context, colTotals[c])),
                ),
                DataCell(
                  _totalPill(context, rowTotals.fold(0.0, (a, b) => a + b)),
                ),
              ],
            ),
          ],
        );

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

        // ✅ Scrollbar + SingleChildScrollView partagent _hCtrl (pas d'assertion)
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
    required double value,
    required double max,
    required Color color,
  }) {
    final t = (value / max).clamp(0.0, 1.0);
    final bg = color.withOpacity(0.12 + 0.28 * t);
    final useWhite = t > 0.55;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        value.toStringAsFixed(0),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color:
              useWhite ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _totalPill(BuildContext context, double v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondary.withOpacity(.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      v.toStringAsFixed(0),
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
// UI helpers (cartes, sections)
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
      width: 220,
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
