// lib/views/syndic_event_list.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_kch/constants/app_constants.dart';
// ❗️Chemin PDF corrigé
import 'package:cse_kch/views/syndic_event_lsit_pdf.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Providers & models
import '../providers/syndic_event_provider.dart';
import '../providers/depot_provider.dart';
import '../providers/agent_provider.dart';
import '../models/syndic_event.dart';
import '../services/syndic_event_dao.dart';

class SyndicEventList extends StatefulWidget {
  const SyndicEventList({super.key});

  @override
  State<SyndicEventList> createState() => _SyndicEventListState();
}

class _SyndicEventListState extends State<SyndicEventList> {
  // Filtres
  final _searchCtrl = TextEditingController();

  // Tri
  int? _sortColumnIndex;
  bool _sortAsc = true;

  // Scroll
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  // Mois courant (écoute provider)
  late DateTime _month;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<SyndicEventProvider>().listenMonth(_month);
      final ap = context.read<AgentProvider>();
      if (ap.agents.isEmpty) await ap.loadAgents();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', 'fr_FR').format(d);

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    setState(() => _month = DateTime(next.year, next.month, 1));
    context.read<SyndicEventProvider>().listenMonth(_month);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SyndicEventProvider>();
    final events = List<SyndicEvent>.from(prov.events);

    // Filtre texte (sur type, dépôt, adresse, agents)
    final q = _searchCtrl.text.trim().toLowerCase();
    List<SyndicEvent> rows = events.where((e) {
      if (q.isEmpty) return true;
      final hay = [
        e.type,
        e.depotLabel,
        e.depotAdresse,
        e.agentNoms.join(' '),
        _fmtDate(e.date),
        e.timeLabel,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    // Tri DataTable : 0 DATE, 1 HEURE, 2 TYPE, 3 DÉPÔT, 4 ADRESSE, 5 AGENTS
    if (_sortColumnIndex != null) {
      rows.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.date.compareTo(b.date);
            break;
          case 1:
            cmp = a.timeLabel.compareTo(b.timeLabel);
            break;
          case 2:
            cmp = a.type.toLowerCase().compareTo(b.type.toLowerCase());
            break;
          case 3:
            cmp = a.depotLabel.toLowerCase().compareTo(
              b.depotLabel.toLowerCase(),
            );
            break;
          case 4:
            cmp = a.depotAdresse.toLowerCase().compareTo(
              b.depotAdresse.toLowerCase(),
            );
            break;
          case 5:
            cmp = a.agentNoms
                .join(', ')
                .toLowerCase()
                .compareTo(b.agentNoms.join(', ').toLowerCase());
            break;
          default:
            cmp = a.date.compareTo(b.date);
        }
        return _sortAsc ? cmp : -cmp;
      });
    } else {
      rows.sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        return a.timeLabel.compareTo(b.timeLabel);
      });
    }

    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(_month);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Évènements – $monthLabel'),
            if (_exporting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'Exporter PDF',
                icon: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.blueAccent,
                ),
                onPressed: rows.isEmpty
                    ? null
                    : () async {
                        setState(() => _exporting = true);
                        try {
                          final label = DateFormat(
                            'MMMM yyyy',
                            'fr_FR',
                          ).format(_month);
                          await SyndicEventListPdfGenerator.generate(
                            context: context,
                            events: rows,
                            titleSuffix: label,
                          );
                        } finally {
                          if (mounted) setState(() => _exporting = false);
                        }
                      },
              ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final done = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _AddEventDialog(),
                );
                if (done == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Évènement ajouté')),
                  );
                }
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black,
                child: Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mois précédent',
                ),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher (type, dépôt, adresse, agent)…',
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
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mois suivant',
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: rows.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucun évènement.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, cons) {
                        final table = _buildTable(context, rows);
                        return Scrollbar(
                          thumbVisibility: true,
                          controller: _hCtrl,
                          notificationPredicate: (n) =>
                              n.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _hCtrl,
                            child: Scrollbar(
                              thumbVisibility: true,
                              controller: _vCtrl,
                              notificationPredicate: (n) =>
                                  n.metrics.axis == Axis.vertical,
                              child: SingleChildScrollView(
                                controller: _vCtrl,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: cons.maxWidth,
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

  DataTable _buildTable(BuildContext context, List<SyndicEvent> rows) {
    const double _cellFontSize = 12; // ← ajuste si tu veux encore plus petit
    const double _headerFontSize = 12;

    const headerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: _headerFontSize,
    );
    const cellStyle = TextStyle(fontSize: _cellFontSize);

    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAsc,
      columnSpacing: 28,
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 44,
      headingTextStyle: headerStyle, // ← taille d’en-tête réduite
      columns: [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('HEURE')),
        const DataColumn(label: Text('TYPE')),
        const DataColumn(label: Text('DÉPÔT')),
        const DataColumn(label: Text('ADRESSE')),
        const DataColumn(label: Text('AGENTS')),
        const DataColumn(label: Text('ACTIONS')),
      ],
      rows: rows.map((e) {
        return DataRow(
          cells: [
            DataCell(Text(_fmtDate(e.date), style: cellStyle)),
            DataCell(Text(e.timeLabel, style: cellStyle)),
            DataCell(Text(e.type, style: cellStyle)),
            DataCell(Text(e.depotLabel, style: cellStyle)),
            DataCell(Text(e.depotAdresse, style: cellStyle)),
            DataCell(
              Tooltip(
                message: e.agentNoms.isEmpty ? '-' : e.agentNoms.join(', '),
                child: SizedBox(
                  width: 240,
                  child: Text(
                    e.agentNoms.isEmpty ? '-' : e.agentNoms.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle, // ← taille réduite
                  ),
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => _EditEventDialog(event: e),
                      );
                      if (ok == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Évènement modifié')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () async {
                      final yes =
                          await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Supprimer'),
                              content: Text(
                                'Supprimer ${_fmtDate(e.date)} ${e.timeLabel} – ${e.type} ?',
                                style: cellStyle, // optionnel, cohérent
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!yes) return;
                      await context.read<SyndicEventProvider>().remove(e.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Évènement supprimé')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// ===== Dialog AJOUT =====
class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog();

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'CSE';
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int? _selectedDepotIndex;
  final Set<int> _selectedAgentIdx = {};

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final depProv = context.watch<DepotProvider>();
    final agProv = context.watch<AgentProvider>();
    final depots = depProv.items;
    final agents = agProv.agents;

    final d = DateFormat('dd/MM/yyyy', 'fr_FR').format(_date);
    final t =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('AJOUTER UN ÉVÈNEMENT'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: AppConstants.typesReunion
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'CSE'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(text: d),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Heure',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.schedule),
                ),
                controller: TextEditingController(text: t),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedDepotIndex,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Dépôt',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int i = 0; i < depots.length; i++)
                    DropdownMenuItem(value: i, child: Text(depots[i].nom)),
                ],
                validator: (v) => v == null ? 'Choisir un dépôt' : null,
                onChanged: (v) => setState(() => _selectedDepotIndex = v),
              ),
              const SizedBox(height: 8),
              _AgentMultiPicker(
                agentsCount: agents.length,
                labelBuilder: (i) =>
                    '${agents[i].name} ${agents[i].surname}'.trim(),
                selected: _selectedAgentIdx,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedDepotIndex == null) return;
                  setState(() => _saving = true);
                  try {
                    final dep = depots[_selectedDepotIndex!];
                    final adresse =
                        [
                              dep.adresse,
                              if (dep.ville != null && dep.ville!.isNotEmpty)
                                dep.ville,
                              if (dep.cp != null && dep.cp!.isNotEmpty) dep.cp,
                            ]
                            .whereType<String>()
                            .where((s) => s.trim().isNotEmpty)
                            .join(', ');

                    final timeLabel =
                        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

                    final agentIds = <String>[];
                    final agentNoms = <String>[];
                    for (final i in _selectedAgentIdx) {
                      final a = agents[i];
                      agentIds.add(a.id?.toString() ?? '');
                      agentNoms.add('${a.name} ${a.surname}'.trim());
                    }

                    final event = SyndicEvent(
                      id: 'tmp',
                      type: _type,
                      date: DateTime(_date.year, _date.month, _date.day),
                      time: timeLabel,
                      depotId: dep.id ?? '',
                      depotLabel: dep.nom,
                      depotAdresse: adresse,
                      agentIds: agentIds,
                      agentNoms: agentNoms,
                      status: 'planifie',
                      createdBy: SyndicEventDao.currentUid(),
                    );

                    await context.read<SyndicEventProvider>().create(event);
                    Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  } finally {
                    setState(() => _saving = false);
                  }
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// ===== Dialog ÉDITION =====
class _EditEventDialog extends StatefulWidget {
  final SyndicEvent event;
  const _EditEventDialog({required this.event});

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  final _formKey = GlobalKey<FormState>();

  // ⬇️ type nullable pour sécuriser si valeur absente de la liste
  late String? _type;
  late DateTime _date;
  late TimeOfDay _time;
  int? _selectedDepotIndex;
  final Set<int> _selectedAgentIdx = {};
  bool _saving = false;

  // Liste de référence cohérente avec l’ajout
  List<String> get _types {
    final list = AppConstants.typesReunion.toSet().toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    // Type sécurisé : si la valeur n’est pas dans la liste, on prend le 1er
    _type = _types.contains(e.type)
        ? e.type
        : (_types.isNotEmpty ? _types.first : null);

    _date = e.date;
    _time = TimeOfDay(hour: e.timeH, minute: e.timeM);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final depots = context.read<DepotProvider>().items;
      final idx = depots.indexWhere((d) => (d.id ?? '') == e.depotId);
      _selectedDepotIndex = (idx >= 0 && idx < depots.length) ? idx : null;

      final agents = context.read<AgentProvider>().agents;
      for (int i = 0; i < agents.length; i++) {
        final nom = '${agents[i].name} ${agents[i].surname}'.trim();
        if (e.agentNoms.contains(nom)) _selectedAgentIdx.add(i);
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final depProv = context.watch<DepotProvider>();
    final agProv = context.watch<AgentProvider>();
    final depots = depProv.items;
    final agents = agProv.agents;

    final d = DateFormat('dd/MM/yyyy', 'fr_FR').format(_date);
    final t =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('MODIFIER L’ÉVÈNEMENT'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⬇️ Value toujours cohérente avec items
              DropdownButtonFormField<String>(
                value: _types.contains(_type) ? _type : null,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _types
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Choisir un type' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(text: d),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Heure',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.schedule),
                ),
                controller: TextEditingController(text: t),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),
              // ⬇️ Value sécurisée pour éviter l’assertion du Dropdown
              DropdownButtonFormField<int>(
                value:
                    (_selectedDepotIndex != null &&
                        _selectedDepotIndex! >= 0 &&
                        _selectedDepotIndex! < depots.length)
                    ? _selectedDepotIndex
                    : null,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Dépôt',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int i = 0; i < depots.length; i++)
                    DropdownMenuItem(value: i, child: Text(depots[i].nom)),
                ],
                validator: (v) => v == null ? 'Choisir un dépôt' : null,
                onChanged: (v) => setState(() => _selectedDepotIndex = v),
              ),
              const SizedBox(height: 8),
              _AgentMultiPicker(
                agentsCount: agents.length,
                labelBuilder: (i) =>
                    '${agents[i].name} ${agents[i].surname}'.trim(),
                selected: _selectedAgentIdx,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedDepotIndex == null) return;
                  setState(() => _saving = true);
                  try {
                    final dep = depots[_selectedDepotIndex!];
                    final adresse =
                        [
                              dep.adresse,
                              if (dep.ville != null && dep.ville!.isNotEmpty)
                                dep.ville,
                              if (dep.cp != null && dep.cp!.isNotEmpty) dep.cp,
                            ]
                            .whereType<String>()
                            .where((s) => s.trim().isNotEmpty)
                            .join(', ');

                    final timeLabel =
                        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

                    final agentsAll = context.read<AgentProvider>().agents;
                    final agentIds = <String>[];
                    final agentNoms = <String>[];
                    for (final i in _selectedAgentIdx) {
                      final a = agentsAll[i];
                      agentIds.add(a.id?.toString() ?? '');
                      agentNoms.add('${a.name} ${a.surname}'.trim());
                    }

                    final patch = {
                      'type': _type!, // validé par le validator
                      'date': Timestamp.fromDate(
                        DateTime.utc(_date.year, _date.month, _date.day),
                      ),
                      'time': timeLabel,
                      'depot_id': dep.id ?? '',
                      'depot_label': dep.nom,
                      'depot_adresse': adresse,
                      'agent_ids': agentIds,
                      'agent_noms': agentNoms,
                    };

                    await context.read<SyndicEventProvider>().update(
                      widget.event.id,
                      patch,
                    );
                    Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  } finally {
                    setState(() => _saving = false);
                  }
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// ===== Sélecteur multi-agents =====
class _AgentMultiPicker extends StatelessWidget {
  final int agentsCount;
  final String Function(int index) labelBuilder;
  final Set<int> selected;

  const _AgentMultiPicker({
    required this.agentsCount,
    required this.labelBuilder,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final temp = <int>{...selected};
        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: const Text('Sélectionner des agents'),
              content: SizedBox(
                width: 520,
                height: 380,
                child: ListView.builder(
                  itemCount: agentsCount,
                  itemBuilder: (_, i) {
                    final label = labelBuilder(i);
                    final checked = temp.contains(i);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(label),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            temp.add(i);
                          } else {
                            temp.remove(i);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    selected
                      ..clear()
                      ..addAll(temp);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Agents',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            selected.isEmpty
                ? 'Aucun agent sélectionné'
                : selected.map((i) => labelBuilder(i)).join(', '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
