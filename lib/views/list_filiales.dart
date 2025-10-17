// lib/views/cse/filiale_list_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'package:cse_kch/models/filiale_model.dart';
import 'package:cse_kch/views/add_nouvelle_filiale_dialog.dart';
import 'package:cse_kch/providers/filiale_provider.dart';
import 'package:cse_kch/views/filiales_list_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilialeListScreen extends StatefulWidget {
  const FilialeListScreen({super.key});

  @override
  State<FilialeListScreen> createState() => _FilialeListScreenState();
}

class _FilialeListScreenState extends State<FilialeListScreen> {
  // Filtre
  final _searchCtrl = TextEditingController();
  bool _exporting = false;

  // Tri
  int? _sortColumnIndex;
  bool _sortAsc = true;

  // Scrollbars
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FilialeProvider>().loadFiliales();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<FilialeProvider>();
    final all = prov.filiales;
    final loading = prov.isLoading;

    // Filtrage (abréviation / désignation / base / adresse)
    final q = _searchCtrl.text.trim().toLowerCase();
    List<FilialeModel> rows = all.where((f) {
      if (q.isEmpty) return true;
      return f.abreviation.toLowerCase().contains(q) ||
          f.designation.toLowerCase().contains(q) ||
          f.base.toLowerCase().contains(q) ||
          f.adresse.toLowerCase().contains(q);
    }).toList();

    // Tri (0 ABRÉV, 1 DÉSIGNATION, 2 BASE, 3 ADRESSE)
    if (_sortColumnIndex != null) {
      rows.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.abreviation.toLowerCase().compareTo(
              b.abreviation.toLowerCase(),
            );
            break;
          case 1:
            cmp = a.designation.toLowerCase().compareTo(
              b.designation.toLowerCase(),
            );
            break;
          case 2:
            cmp = a.base.toLowerCase().compareTo(b.base.toLowerCase());
            break;
          case 3:
            cmp = a.adresse.toLowerCase().compareTo(b.adresse.toLowerCase());
            break;
          default:
            cmp = a.abreviation.toLowerCase().compareTo(
              b.abreviation.toLowerCase(),
            );
        }
        return _sortAsc ? cmp : -cmp;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('Filiales'),
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
                          await FilialesListPdfGenerator.generate(
                            context: context,
                            filiales: rows,
                          );
                        } finally {
                          if (mounted) setState(() => _exporting = false);
                        }
                      },
              ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => const AddNouvelFilialeDialog(),
                );
                if (created == true) await prov.loadFiliales();
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
      body: RefreshIndicator(
        onRefresh: () => context.read<FilialeProvider>().loadFiliales(),
        child: Column(
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
                    hintText:
                        'Rechercher (abréviation / désignation / base / adresse)…',
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
                child: Builder(
                  builder: (_) {
                    if (loading && all.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (rows.isEmpty) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Aucune filiale.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return LayoutBuilder(
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataTable _buildTable(BuildContext context, List<FilialeModel> rows) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAsc,
      columnSpacing: 36,
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 36,
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      columns: [
        DataColumn(
          label: const Text('ABRÉVIATION'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('DÉSIGNATION'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('BASE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        DataColumn(
          label: const Text('ADRESSE'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAsc = asc;
          }),
        ),
        const DataColumn(label: Text('ACTIONS')),
      ],
      rows: rows
          .map(
            (f) => DataRow(
              cells: [
                DataCell(Text(f.abreviation)),
                DataCell(Text(f.designation)),
                DataCell(
                  Tooltip(
                    message: f.base,
                    child: Text(
                      f.base,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                DataCell(
                  Tooltip(
                    message: f.adresse,
                    child: Text(
                      f.adresse,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
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
                        onPressed: () => _editDialog(context, f),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _deleteFiliale(context, f),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Future<void> _deleteFiliale(BuildContext context, FilialeModel f) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer'),
            content: Text('Supprimer la filiale « ${f.abreviation} » ?'),
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
      await context.read<FilialeProvider>().deleteFiliale(f.id!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Filiale supprimée')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  void _editDialog(BuildContext context, FilialeModel f) {
    final formKey = GlobalKey<FormState>();
    final abrev = TextEditingController(text: f.abreviation);
    final design = TextEditingController(text: f.designation);
    final baseCtrl = TextEditingController(text: f.base); // ⬅️ Base
    final adresse = TextEditingController(text: f.adresse);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('MODIFIER FILIALE'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: abrev,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Abréviation',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: design,
                  decoration: const InputDecoration(
                    labelText: 'Désignation',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: baseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: adresse,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
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
                final updated = f.copyWith(
                  abreviation: abrev.text.trim().toUpperCase(),
                  designation: design.text.trim(),
                  base: baseCtrl.text.trim(),
                  adresse: adresse.text.trim(),
                );
                await context.read<FilialeProvider>().updateFiliale(updated);
                if (!mounted) return;
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filiale modifiée')),
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
    );
  }
}
