// lib/views/presence_stats_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:cse_kch/models/presence_model.dart';
import 'package:cse_kch/providers/presence_provider.dart';
import 'package:cse_kch/views/presence_stats_pdf_generator.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PresenceStatsScreen extends StatefulWidget {
  const PresenceStatsScreen({super.key});

  @override
  State<PresenceStatsScreen> createState() => _PresenceStatsScreenState();
}

class _PresenceStatsScreenState extends State<PresenceStatsScreen> {
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PresenceProvider>().fetchPresences(),
    );
  }

  Future<void> _exportPdf(List<PresenceModel> presences) async {
    if (presences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée à exporter.')),
      );
      return;
    }
    setState(() => _exportingPdf = true);
    try {
      await PresenceStatsPdfGenerator.generatePresenceStatsPdf(presences);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF généré avec succès.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresenceProvider>();
    final loading = provider.isLoading;
    final presences = provider.presences;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Fenêtre année syndicale (juin -> juin)
    final now = DateTime.now();
    final startYear = now.month < 6 ? now.year - 1 : now.year;
    final startDate = DateTime(startYear, 6);
    final endDate = DateTime(startYear + 1, 6);
    final syndicalYearLabel = "$startYear-${startYear + 1}";

    // Mois (yyyy-MM)
    final months = List.generate(12, (i) {
      final d = DateTime(startDate.year, startDate.month + i);
      return DateFormat('yyyy-MM').format(d);
    });

    // Filtrage période
    final relevantPresences = presences.where((p) {
      final d = _parseDate(p.date);
      if (d == null) return false;
      return !d.isBefore(startDate) && d.isBefore(endDate);
    }).toList();

    // ==== CALCULS ====
    // Occurrence globale = (type|date|heure)
    String occKey(PresenceModel p) => '${p.reunion.trim()}|${p.date}|${p.time}';

    // Total annuel (tous types)
    final totalAnnualMeetingsAllTypes = relevantPresences
        .map(occKey)
        .toSet()
        .length;

    // Totaux par mois (tous types)
    final Map<String, Set<String>> monthToOccAllTypes = {
      for (final m in months) m: <String>{},
    };
    for (final p in relevantPresences) {
      final d = _parseDate(p.date);
      if (d == null) continue;
      final mKey = DateFormat('yyyy-MM').format(d);
      monthToOccAllTypes[mKey]!.add(occKey(p));
    }
    final monthlyTotalsAllTypes = {
      for (final m in months) m: monthToOccAllTypes[m]!.length,
    };

    // Totaux annuels par type
    final perType = groupBy(
      relevantPresences,
      (p) => (p.reunion).trim().isEmpty ? 'Sans type' : (p.reunion).trim(),
    );
    final annualTotalsByType = {
      for (final e in perType.entries)
        e.key: e.value.map(occKey).toSet().length,
    };

    // Détail par type (tables)
    final reunionsByTypeForTable = groupBy(
      relevantPresences,
      (p) => (p.reunion).trim().isEmpty ? 'Sans type' : (p.reunion).trim(),
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // gauche : icône + titre
            Row(
              children: [
                Icon(Icons.insights, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  "Stat-Participations $syndicalYearLabel",
                  style: TextStyle(color: cs.onSurface),
                ),
              ],
            ),
            // droite : loader ou bouton PDF
            _exportingPdf
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Exporter en PDF',
                    icon: Icon(Icons.picture_as_pdf, color: cs.primary),
                    onPressed: () => _exportPdf(relevantPresences),
                    visualDensity: VisualDensity.compact,
                  ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      // Laisse le thème gérer le fond (clair/sombre)
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (relevantPresences.isEmpty)
          ? Center(
              child: Text(
                "Aucune donnée disponible.",
                style: theme.textTheme.bodyMedium,
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<PresenceProvider>().fetchPresences(),
              color: cs.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                children: [
                  // ====== CARTES COMPACTES EN HAUT ======
                  _cardCompact(
                    context,
                    title: "Totaux par mois (tous types)",
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...months.map((m) {
                            final date = DateFormat('yyyy-MM').parse(m);
                            final label = DateFormat.MMM(
                              'fr_FR',
                            ).format(date).toUpperCase();
                            final v = monthlyTotalsAllTypes[m] ?? 0;
                            return _pillCompact(context, label, '$v');
                          }),
                          _pillAccentCompact(
                            context,
                            "TOTAL",
                            "$totalAnnualMeetingsAllTypes",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _cardCompact(
                    context,
                    title: "Totaux par type (annuel)",
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: annualTotalsByType.entries
                          .map((e) => _chipStatCompact(context, e.key, e.value))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ====== TABLES ======
                  ...reunionsByTypeForTable.entries.map((entry) {
                    final reunionType = entry.key;
                    final presencesForReunion = entry.value;

                    String occKeyType(PresenceModel p) =>
                        '${p.reunion.trim()}|${p.date}|${p.time}';

                    final distinctMeetingsPerMonth = {
                      for (final m in months) m: <String>{},
                    };
                    for (final p in presencesForReunion) {
                      final d = _parseDate(p.date);
                      if (d == null) continue;
                      final key = DateFormat('yyyy-MM').format(d);
                      distinctMeetingsPerMonth[key]!.add(occKeyType(p));
                    }

                    final totalAnnualMeetingsThisType = months.fold<int>(
                      0,
                      (sum, m) => sum + distinctMeetingsPerMonth[m]!.length,
                    );

                    final agents =
                        groupBy(
                          presencesForReunion,
                          (p) => p.agent.trim(),
                        ).entries.toList()..sort(
                          (a, b) => a.key.toLowerCase().compareTo(
                            b.key.toLowerCase(),
                          ),
                        );

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                      child: Card(
                        elevation: 0,
                        color: cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.fromLTRB(
                              12,
                              8,
                              12,
                              0,
                            ),
                            title: _typeBadge(context, reunionType),
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 940,
                                  ),
                                  child: DataTable(
                                    columnSpacing: 22,
                                    dataRowMinHeight: 30,
                                    dataRowMaxHeight: 40,
                                    headingRowHeight: 42,
                                    headingRowColor: MaterialStatePropertyAll(
                                      cs.surfaceVariant.withOpacity(.6),
                                    ),
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          "Agent",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ...months.map((m) {
                                        final date = DateFormat(
                                          'yyyy-MM',
                                        ).parse(m);
                                        final monthLabel = DateFormat.MMM(
                                          'fr_FR',
                                        ).format(date);
                                        final reunionCount =
                                            distinctMeetingsPerMonth[m]!.length;

                                        return DataColumn(
                                          label: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                monthLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: reunionCount == 0
                                                      ? cs.surface.withOpacity(
                                                          .6,
                                                        )
                                                      : cs.primaryContainer
                                                            .withOpacity(.8),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "$reunionCount",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: reunionCount == 0
                                                        ? cs.onSurfaceVariant
                                                        : cs.onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      DataColumn(
                                        label: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Total",
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.tertiaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                "$totalAnnualMeetingsThisType",
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onTertiaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    // rows: agents.mapIndexed((i, e) {
                                    //   final name = e.key;
                                    //   final agentPresences = e.value;

                                    //   final agentMonthOcc = {
                                    //     for (final m in months) m: <String>{},
                                    //   };
                                    //   for (final p in agentPresences) {
                                    //     final d = _parseDate(p.date);
                                    //     if (d == null) continue;
                                    //     final mKey = DateFormat(
                                    //       'yyyy-MM',
                                    //     ).format(d);
                                    //     final k =
                                    //         '${p.reunion.trim()}|${p.date}|${p.time}';
                                    //     agentMonthOcc[mKey]!.add(k);
                                    //   }

                                    //   final monthCells = months.map((m) {
                                    //     final hasAny =
                                    //         agentMonthOcc[m]!.isNotEmpty;
                                    //     return hasAny
                                    //         ? DataCell(
                                    //             Text(
                                    //               "P",
                                    //               style: TextStyle(
                                    //                 fontSize: 13,
                                    //                 fontWeight: FontWeight.w600,
                                    //                 color:
                                    //                     Colors.green.shade700,
                                    //               ),
                                    //             ),
                                    //           )
                                    //         : DataCell(
                                    //             Text(
                                    //               "—",
                                    //               style: TextStyle(
                                    //                 fontSize: 12,
                                    //                 color: cs.onSurfaceVariant,
                                    //               ),
                                    //             ),
                                    //           );
                                    //   }).toList();

                                    //   final totalMonthsPresent = agentMonthOcc
                                    //       .values
                                    //       .where((s) => s.isNotEmpty)
                                    //       .length;

                                    //   return DataRow(
                                    //     color: MaterialStatePropertyAll(
                                    //       i.isEven
                                    //           ? cs.surface.withOpacity(.55)
                                    //           : cs.surface,
                                    //     ),
                                    //     cells: [
                                    //       DataCell(
                                    //         Text(
                                    //           name,
                                    //           style: const TextStyle(
                                    //             fontSize: 12,
                                    //             fontWeight: FontWeight.w600,
                                    //           ),
                                    //           overflow: TextOverflow.ellipsis,
                                    //         ),
                                    //       ),
                                    //       ...monthCells,
                                    //       DataCell(
                                    //         Text(
                                    //           "$totalMonthsPresent",
                                    //           style: TextStyle(
                                    //             fontSize: 12,
                                    //             fontWeight: FontWeight.w600,
                                    //             color: cs.primary,
                                    //           ),
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   );
                                    // }).toList(),
                                    rows: agents.mapIndexed((i, e) {
                                      final name = e.key;
                                      final agentPresences = e.value;

                                      final agentMonthOcc = {
                                        for (final m in months) m: <String>{},
                                      };
                                      for (final p in agentPresences) {
                                        final d = _parseDate(p.date);
                                        if (d == null) continue;
                                        final mKey = DateFormat(
                                          'yyyy-MM',
                                        ).format(d);
                                        final k =
                                            '${p.reunion.trim()}|${p.date}|${p.time}';
                                        agentMonthOcc[mKey]!.add(k);
                                      }

                                      // === NOUVELLE LOGIQUE : nombre de présences par mois ===
                                      final monthCells = months.map((m) {
                                        final count = agentMonthOcc[m]!.length;
                                        final hasAny = count > 0;

                                        return DataCell(
                                          Text(
                                            hasAny ? '$count' : '0',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: hasAny
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: hasAny
                                                  ? Colors.green.shade700
                                                  : cs.onSurfaceVariant,
                                            ),
                                          ),
                                        );
                                      }).toList();

                                      // === NOUVELLE LOGIQUE : total annuel de présences (toutes réunions de ce type) ===
                                      final totalMeetingsForAgent =
                                          agentMonthOcc.values.fold<int>(
                                            0,
                                            (sum, s) => sum + s.length,
                                          );

                                      return DataRow(
                                        color: MaterialStatePropertyAll(
                                          i.isEven
                                              ? cs.surface.withOpacity(.55)
                                              : cs.surface,
                                        ),
                                        cells: [
                                          DataCell(
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          ...monthCells,
                                          DataCell(
                                            Text(
                                              "$totalMeetingsForAgent",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  // ===== UI helpers (compact cards/pills) =====

  Widget _cardCompact(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _pillCompact(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillAccentCompact(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary, cs.tertiary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: .6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipStatCompact(BuildContext context, String label, int value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_special_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Capsule titre de tableau
  Widget _typeBadge(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ==== Utils ====
  DateTime? _parseDate(String raw) {
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(raw);
    } catch (_) {
      return null;
    }
  }
}
