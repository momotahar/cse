// lib/views/billets_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/billet.dart';
import '../providers/billet_provider.dart';

class BilletsScreen extends StatefulWidget {
  const BilletsScreen({super.key});

  @override
  State<BilletsScreen> createState() => _BilletsScreenState();
}

class _BilletsScreenState extends State<BilletsScreen> {
  final _searchCtrl = TextEditingController();

  // Tri
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Scrollbar horizontale
  final _hScrollCtrl = ScrollController();

  // Debounce pour la recherche
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 1er chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BilletProvider>().loadBillets();
    });
    // Recherche avec petit debounce
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        final q = _searchCtrl.text.trim();
        context.read<BilletProvider>().loadBillets(q: q);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BilletProvider>();
    final items = prov.billets;
    final rowsData = List<Billet>.from(items);

    // tri
    if (_sortColumnIndex != null) {
      rowsData.sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase());
            break;
          case 1:
            cmp = a.prixOriginal.compareTo(b.prixOriginal);
            break;
          case 2:
            cmp = a.prixNegos.compareTo(b.prixNegos);
            break;
          case 3:
            cmp = a.prixCse.compareTo(b.prixCse);
            break;
          default:
            cmp = a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase());
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billets'),
        actions: [
          // Bouton rond (nouveau)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openEditDialog(context),
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
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher (libellé)…',
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
              child: items.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucun billet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        final table = _buildBilletsTable(rowsData);
                        return Scrollbar(
                          thumbVisibility: true,
                          controller: _hScrollCtrl,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _hScrollCtrl,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                // minWidth pour occuper l’écran, s’élargit si besoin
                                minWidth: constraints.maxWidth,
                                maxWidth: constraints.maxWidth,
                              ),
                              child: table,
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

  DataTable _buildBilletsTable(List<Billet> rowsData) {
    Widget header(String text) =>
        SizedBox(width: 110, child: Text(text, maxLines: 2, softWrap: true));

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
          label: header('LIBELLÉ'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: header('PRIX ORIGI (€)'),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: header('PRIX NÉGO (€)'),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: header('PRIX CSE (€)'),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        const DataColumn(label: Text('ACTIONS')),
      ],
      rows: rowsData.map((b) {
        return DataRow(
          onSelectChanged: (sel) {
            if (sel == true) _openEditDialog(context, billet: b);
          },
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  b.libelle.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(_fmt(b.prixOriginal))),
            DataCell(Text(_fmt(b.prixNegos))),
            DataCell(Text(_fmt(b.prixCse))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                    onPressed: () => _openEditDialog(context, billet: b),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _confirmDelete(context, b),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  Future<void> _confirmDelete(BuildContext context, Billet b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer le billet « ${b.libelle.toUpperCase()} » ?'),
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
        await context.read<BilletProvider>().deleteBillet(b.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Billet supprimé')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
      }
    }
  }

  Future<void> _openEditDialog(BuildContext context, {Billet? billet}) async {
    final formKey = GlobalKey<FormState>();
    final libelle = TextEditingController(
      text: (billet?.libelle ?? '').toUpperCase(),
    );
    final original = TextEditingController(
      text: billet != null ? billet.prixOriginal.toString() : '',
    );
    final negos = TextEditingController(
      text: billet != null ? billet.prixNegos.toString() : '',
    );
    final cse = TextEditingController(
      text: billet != null ? billet.prixCse.toString() : '',
    );

    double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

    String? _validateMoney(String? v) {
      final n = _parse(v ?? '');
      if (n == null || n < 0) return 'Saisir un prix valide';
      return null;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(billet == null ? 'NOUVEAU BILLET' : 'MODIFIER LE BILLET'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Libellé
                TextFormField(
                  controller: libelle,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'LIBELLÉ',
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 8),

                // Prix original
                TextFormField(
                  controller: original,
                  decoration: const InputDecoration(
                    labelText: 'PRIX ORIGINAL (€)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMoney,
                ),
                const SizedBox(height: 8),

                // Prix négo
                TextFormField(
                  controller: negos,
                  decoration: const InputDecoration(
                    labelText: 'PRIX NÉGO (€)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final pn = _parse(v ?? '');
                    final po = _parse(original.text);
                    if (pn == null || pn < 0) return 'Saisir un prix valide';
                    if (po != null && pn > po) {
                      return 'Doit être ≤ au prix original';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Prix CSE
                TextFormField(
                  controller: cse,
                  decoration: const InputDecoration(
                    labelText: 'PRIX CSE (€)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final pcse = _parse(v ?? '');
                    final pneg = _parse(negos.text);
                    final po = _parse(original.text);
                    if (pcse == null || pcse < 0) {
                      return 'Saisir un prix valide';
                    }
                    if (pneg != null && pcse > pneg) {
                      return 'CSE ≤ Prix NÉGO';
                    }
                    if (po != null && pcse > po) {
                      return 'CSE ≤ Prix ORIGINAL';
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

              final b = Billet(
                id: billet?.id,
                libelle: libelle.text.trim().toUpperCase(),
                prixOriginal: _parse(original.text.trim())!,
                prixNegos: _parse(negos.text.trim())!,
                prixCse: _parse(cse.text.trim())!,
              );

              final prov = context.read<BilletProvider>();
              try {
                if (billet == null) {
                  await prov.addBillet(b);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Billet ajouté')),
                    );
                  }
                } else {
                  await prov.updateBillet(b);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Billet modifié')),
                    );
                  }
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                // remonte les erreurs DAO (validations backend, réseau…)
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved == true) {
      // rechargement géré par le provider si nécessaire
    }

    // nettoie les contrôleurs locaux créés dans le dialog (bonne hygiène mémoire)
    libelle.dispose();
    original.dispose();
    negos.dispose();
    cse.dispose();
  }
}

/// Formatter pour convertir en MAJUSCULE
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
