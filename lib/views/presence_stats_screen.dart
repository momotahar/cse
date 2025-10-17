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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PresenceProvider>().fetchPresences();
    });
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
    String occKey(PresenceModel p) =>
        '${(p.reunion).trim()}|${p.date}|${p.time}';

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
      if (monthToOccAllTypes.containsKey(mKey)) {
        monthToOccAllTypes[mKey]!.add(occKey(p));
      }
    }
    final Map<String, int> monthlyTotalsAllTypes = {
      for (final m in months) m: monthToOccAllTypes[m]!.length,
    };

    // Totaux annuels par type
    final perType = groupBy(
      relevantPresences,
      (p) => (p.reunion).trim().isEmpty ? 'Sans type' : (p.reunion).trim(),
    );
    final Map<String, int> annualTotalsByType = {
      for (final e in perType.entries)
        e.key: e.value.map(occKey).toSet().length,
    };

    // Détail par type (tables)
    final reunionsByTypeForTable = groupBy(
      relevantPresences,
      (p) => (p.reunion).trim().isEmpty ? 'Sans type' : (p.reunion).trim(),
    );

    // ==================

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Groupe gauche : icône + titre
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  // garde ta variable
                  "Stat-Participations $syndicalYearLabel",
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),

            // Groupe droite : loader ou bouton PDF
            _exportingPdf
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    children: [
                      IconButton(
                        tooltip: 'Exporter en PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.blue,
                          size: 24,
                        ),
                        onPressed: () => _exportPdf(relevantPresences),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF0F3FF),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (relevantPresences.isEmpty)
          ? const Center(child: Text("Aucune donnée disponible."))
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<PresenceProvider>().fetchPresences(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                children: [
                  // ====== CARTES COMPACTES EN HAUT SEULEMENT ======
                  _cardCompact(
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
                            return _pillCompact(label, '$v');
                          }),
                          _pillAccentCompact(
                            "TOTAL",
                            "$totalAnnualMeetingsAllTypes",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _cardCompact(
                    title: "Totaux par type (annuel)",
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: annualTotalsByType.entries
                          .map((e) => _chipStatCompact(e.key, e.value))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ====== TABLES (inchangées sauf typo plus légère) ======
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
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE3E8FF)),
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
                            title: _typeBadge(reunionType),
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
                                    headingRowColor: MaterialStateProperty.all(
                                      const Color(0xFFE9F0FF),
                                    ),
                                    columns: [
                                      const DataColumn(
                                        label: Text(
                                          "Agent",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600, // was bold
                                            color: Color(0xFF1A2B4C),
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
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF3C4E79),
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
                                                      ? const Color(0xFFEEF2FF)
                                                      : const Color(0xFFD7E3FF),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "$reunionCount",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight
                                                        .w600, // lighter
                                                    color: reunionCount == 0
                                                        ? const Color(
                                                            0xFF6C7AA6,
                                                          )
                                                        : const Color(
                                                            0xFF1F4ED6,
                                                          ),
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
                                            const Text(
                                              "Total",
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight:
                                                    FontWeight.w600, // lighter
                                                color: Color(0xFF1A2B4C),
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
                                                color: const Color(0xFFFFE7D9),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                "$totalAnnualMeetingsThisType",
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight
                                                      .w600, // lighter
                                                  color: Color(0xFFBF360C),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    rows: agents.mapIndexed((i, agentEntry) {
                                      final name = agentEntry.key;
                                      final agentPresences = agentEntry.value;

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

                                      final monthCells = months.map((m) {
                                        final hasAny =
                                            agentMonthOcc[m]!.isNotEmpty;
                                        return hasAny
                                            ? const DataCell(
                                                Text(
                                                  "P",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight
                                                        .w600, // lighter
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                              )
                                            : const DataCell(
                                                Text(
                                                  "—",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF90A0C5),
                                                  ),
                                                ),
                                              );
                                      }).toList();

                                      final totalMonthsPresent = agentMonthOcc
                                          .values
                                          .where((s) => s.isNotEmpty)
                                          .length;

                                      return DataRow(
                                        color:
                                            MaterialStateProperty.resolveWith<
                                              Color?
                                            >(
                                              (states) => i.isEven
                                                  ? const Color(0xFFF7FAFF)
                                                  : Colors.white,
                                            ),
                                        cells: [
                                          DataCell(
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2A3B5A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          ...monthCells,
                                          DataCell(
                                            Text(
                                              "$totalMonthsPresent",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600, // lighter
                                                color: Color(0xFF1F4ED6),
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

  // ===== UI helpers — variantes compactes (cartes du haut uniquement) =====

  Widget _cardCompact({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE3E8FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700, // titre léger
                color: Color(0xFF1A2B4C),
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _pillCompact(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE4FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF506690),
              fontWeight: FontWeight.w600, // moins gras
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD7E3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700, // au lieu de w900
                color: Color(0xFF1F4ED6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillAccentCompact(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFAF7B), Color(0xFFD76D77), Color(0xFF3A1C71)],
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
              fontWeight: FontWeight.w700, // au lieu de w800
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
                fontWeight: FontWeight.w700, // au lieu de w900
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipStatCompact(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE9FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_special_rounded,
            size: 14,
            color: Color(0xFF1F4ED6),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600, // moins gras
              color: Color(0xFF2A3B5A),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD7E3FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700, // au lieu de w900
                color: Color(0xFF1F4ED6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Capsule titre de tableau
  Widget _typeBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700, // au lieu de w800
          color: Color(0xFF274690),
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
