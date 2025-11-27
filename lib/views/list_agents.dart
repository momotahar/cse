// lib/views/cse/list_agents.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:cse_kch/views/agents_list_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cse_kch/models/agent_model.dart';
import 'package:cse_kch/providers/agent_provider.dart';
import 'package:cse_kch/providers/filiale_provider.dart';
import 'package:cse_kch/views/add_nouvel_agent_dialog.dart';

class ListAgents extends StatefulWidget {
  const ListAgents({super.key});

  @override
  State<ListAgents> createState() => _ListAgentsState();
}

class _ListAgentsState extends State<ListAgents> {
  // Filtres
  final _searchCtrl = TextEditingController();
  String? _statutFilter; // null => Tous
  String? _filialeFilter; // null => Toutes

  // Tri
  int? _sortColumnIndex;
  bool _sortAsc = true;

  // Scrollbars
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  static const _statuts = <String>[
    'DS',
    'Titulaire',
    'DS-Titulaire',
    'Suppléant',
    'RS',
    'RP',
    'Invité',
  ];

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    // charge la data à l’ouverture (comme pour Filiales)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final filProv = context.read<FilialeProvider>();
      final agProv = context.read<AgentProvider>();
      await filProv.loadFiliales();
      await agProv.loadAgents();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  Color _chipColor(String statut, BuildContext ctx) {
    switch (statut) {
      case 'DS':
        return const Color(0xFF673AB7);
      case 'DS-Titulaire':
        return const Color(0xFF2196F3);
      case 'Titulaire':
        return const Color(0xFF2196F3);
      case 'Suppléant':
        return const Color(0xFF4CAF50);
      case 'RS':
        return const Color(0xFFFF9800);
      case 'RP':
        return const Color(0xFFF44336);
      case 'Invité':
        return Colors.grey.shade600;
      default:
        return Theme.of(ctx).colorScheme.outline;
    }
  }

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final agProv = context.watch<AgentProvider>();
    final filProv = context.watch<FilialeProvider>();

    final all = agProv.agents;
    final filialeAbrevs = filProv.filiales.map((f) => f.abreviation).toList();

    // Filtrage
    final q = _searchCtrl.text.trim().toLowerCase();
    List<AgentModel> rows = all.where((a) {
      final okQ =
          q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.surname.toLowerCase().contains(q) ||
          a.filiale.abreviation.toLowerCase().contains(q) ||
          a.filiale.designation.toLowerCase().contains(q) ||
          a.filiale.base.toLowerCase().contains(q) || // 👈 NEW
          a.statut.toLowerCase().contains(q);
      final okS = _statutFilter == null || a.statut == _statutFilter;
      final okF =
          _filialeFilter == null || a.filiale.abreviation == _filialeFilter;
      return okQ && okS && okF;
    }).toList();

    // Tri (0 NOM, 1 PRÉNOM, 2 STATUT, 3 FILIALE, 4 BASE, 5 ORDRE, 6 AJOUTÉ LE)
    if (_sortColumnIndex != null) {
      rows.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 1:
            cmp = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
            break;
          case 2:
            cmp = a.statut.toLowerCase().compareTo(b.statut.toLowerCase());
            break;
          case 3:
            cmp = a.filiale.abreviation.toLowerCase().compareTo(
              b.filiale.abreviation.toLowerCase(),
            );
            break;
          case 4:
            cmp = a.filiale.base.toLowerCase().compareTo(
              b.filiale.base.toLowerCase(),
            );
            break; // 👈 NEW
          case 5:
            cmp = a.ordre.compareTo(b.ordre);
            break;
          case 6:
            cmp = a.dateAjout.compareTo(b.dateAjout);
            break;
          default:
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return _sortAsc ? cmp : -cmp;
      });
    } else {
      // tri par défaut: ordre ASC puis nom
      rows.sort((a, b) {
        final c = a.ordre.compareTo(b.ordre);
        if (c != 0) return c;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('Agents'),
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
                onPressed: () async {
                  setState(() => _exporting = true);
                  try {
                    // n’exporte QUE ce qui est filtré/affiché
                    await AgentsListPdfGenerator.generate(
                      context: context,
                      agents: rows,
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
                  builder: (_) => const AddNouvelAgentDialog(),
                );
                if (done == true) {
                  await context.read<AgentProvider>().loadAgents();
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
          // Barre de filtres — style CommandesScreen / Filiales
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                // Recherche
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher (nom, prénom, statut, filiale)…',
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
                const SizedBox(width: 8),
                // Statut
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    value: _statutFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous')),
                      ..._statuts.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _statutFilter = v),
                  ),
                ),
                const SizedBox(width: 8),
                // Filiale
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    value: _filialeFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Filiale',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes'),
                      ),
                      ...filialeAbrevs.map(
                        (a) => DropdownMenuItem(value: a, child: Text(a)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filialeFilter = v),
                  ),
                ),
              ],
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
                          'Aucun agent.',
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

  DataTable _buildTable(BuildContext context, List<AgentModel> rows) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAsc,
      columnSpacing: 32,
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 40,
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      columns: [
        DataColumn(
          label: const Text('NOM'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('PRÉNOM'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('STATUT'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('FILIALE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          // 👇 NEW
          label: const Text('BASE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('ORDRE'),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        const DataColumn(label: Text('ACTIONS')),
      ],

      rows: rows.map((a) {
        final chipCol = _chipColor(a.statut, context);
        return DataRow(
          cells: [
            DataCell(Text(a.name)),
            DataCell(Text(a.surname)),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: chipCol.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chipCol.withOpacity(.5)),
                ),
                child: Text(
                  a.statut,
                  style: TextStyle(
                    color: chipCol,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            DataCell(Text(a.filiale.abreviation)),
            DataCell(Text(a.filiale.base)),
            DataCell(Text('${a.ordre}')),
            // DataCell(Text(_fmtDate(a.dateAjout))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                    onPressed: () => _editDialog(context, a),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _deleteAgent(context, a),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _deleteAgent(BuildContext context, AgentModel a) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer'),
            content: Text('Supprimer ${a.name} ${a.surname} ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      await context.read<AgentProvider>().deleteAgent(a.id!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agent supprimé')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  void _editDialog(BuildContext context, AgentModel a) {
    final formKey = GlobalKey<FormState>();
    final nom = TextEditingController(text: a.name);
    final prenom = TextEditingController(text: a.surname);
    final ordreCtrl = TextEditingController(text: '${a.ordre}');
    String? statutSel = a.statut;
    String? filialeSel = a.filiale.abreviation;

    final filProv = context.read<FilialeProvider>();
    final filialeAbrevs = filProv.filiales.map((f) => f.abreviation).toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('MODIFIER AGENT'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nom,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: prenom,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: statutSel,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _statuts
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setLocal(() => statutSel = v),
                    validator: (v) => v == null ? 'Choisir un statut' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: filialeSel,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Filiale',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: filialeAbrevs
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) => setLocal(() => filialeSel = v),
                    validator: (v) => v == null ? 'Choisir une filiale' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: ordreCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Ordre (optionnel)',
                      helperText: 'Utilisé pour le tri/affichage',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
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
                try {
                  final newFiliale = filProv.filiales.firstWhere(
                    (f) => f.abreviation == filialeSel,
                  );
                  final newOrdre = int.tryParse(ordreCtrl.text.trim()) ?? 0;

                  final updated = a.copyWith(
                    name: nom.text.trim().toUpperCase(),
                    surname: prenom.text.trim().toUpperCase(),
                    statut: statutSel,
                    filiale: newFiliale,
                    ordre: newOrdre,
                  );
                  await context.read<AgentProvider>().updateAgent(updated);
                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agent modifié')),
                  );
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
  }
}
