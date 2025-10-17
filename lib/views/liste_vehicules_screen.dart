// lib/views/list_vehicules_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/vehicule.dart';
import '../providers/vehicule_provider.dart';

// ───────────────── Style ─────────────────
const _brand = Color(0xFF0B5FFF);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);
const _cardBg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _shadow = Color(0x1A0F172A);

// Bases fréquentes (MAJUSCULE)
const List<String> _basePresets = <String>[
  'SUD',
  'NORD',
  'OUEST',
  'EST',
  'PARIS',
  'Autre',
];

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

class ListVehiculesScreen extends StatefulWidget {
  const ListVehiculesScreen({super.key});
  @override
  State<ListVehiculesScreen> createState() => _ListVehiculesScreenState();
}

class _ListVehiculesScreenState extends State<ListVehiculesScreen> {
  String _searchText = '';
  String _baseFilter = 'Toutes les bases';

  final _hScrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<VehiculeProvider>().loadVehicules();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur chargement: $e')));
      }
      // Option temps réel :
      // context.read<VehiculeProvider>().startRealtime();
    });
  }

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehiculeProvider>();

    // Liste des bases issues des données (pas forcées en MAJ ici pour garder l’existant),
    // mais on affichera en MAJUSCULE côté tableau.
    // Options fixes pour le filtre Base
    final List<String> filterOptions = ['Toutes les bases', ..._basePresets];

    // valeur affichée toujours valide
    final currentBase = filterOptions.contains(_baseFilter)
        ? _baseFilter
        : 'Toutes les bases';

    // set en MAJ pour comparer facilement
    final Set<String> presetsUpper = _basePresets
        .map((e) => e.toUpperCase())
        .toSet();

    // Filtrage (on passe tout en MAJ pour une recherche tolérante)
    final filtered = provider.vehicules.where((v) {
      final s = _searchText.toUpperCase();
      final immat = v.immatriculation.toUpperCase();
      final base = (v.baseGeo ?? '');
      final baseUpper = base.toUpperCase();
      final marque = (v.marque ?? '').toUpperCase();
      final modele = (v.modele ?? '').toUpperCase();
      final statut = (v.statut ?? '').toUpperCase();
      final dateEntree = (v.dateEntree ?? '').toUpperCase();

      final matchesText =
          immat.contains(s) ||
          baseUpper.contains(s) ||
          marque.contains(s) ||
          modele.contains(s) ||
          statut.contains(s) ||
          dateEntree.contains(s);

      bool matchesBase;
      if (currentBase == 'Toutes les bases') {
        matchesBase = true;
      } else if (currentBase == 'Autre') {
        // "Autre" = toutes les bases non vides qui ne sont pas dans les presets
        matchesBase = baseUpper.isNotEmpty && !presetsUpper.contains(baseUpper);
      } else {
        // égalité stricte avec la valeur sélectionnée (en MAJ)
        matchesBase = baseUpper == currentBase.toUpperCase();
      }

      return matchesText && matchesBase;
    }).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Parc véhicules'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
      ),
      body: Column(
        children: [
          // ───────── Filtres & actions ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Container(
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
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: _decField(
                        label: 'Rechercher (immat., base, marque…)',
                        icon: Icons.search,
                      ),
                      onChanged: (v) => setState(() => _searchText = v.trim()),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: currentBase,
                      isExpanded: true,
                      decoration: _decField(
                        label: 'Filtrer par base',
                        icon: Icons.location_city,
                      ),
                      items: filterOptions
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setState(() => _baseFilter = v ?? 'Toutes les bases'),
                    ),
                  ),

                  _StatChip(
                    icon: Icons.local_taxi,
                    label: '${filtered.length}',
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await provider.loadVehicules();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Liste actualisée')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur refresh: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ───────── Tableau scrollable ─────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Builder(
                builder: (ctx) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.error != null) {
                    return Center(child: Text(provider.error!));
                  }
                  if (filtered.isEmpty) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucun véhicule trouvé.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  final table = DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 38,
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    headingRowColor: MaterialStateProperty.resolveWith(
                      (_) => Colors.white,
                    ),
                    columns: const [
                      DataColumn(label: Text('Immat.')),
                      DataColumn(label: Text('Entrée')),
                      DataColumn(label: Text('Marque')),
                      DataColumn(label: Text('Modèle')),
                      DataColumn(label: Text('Base')),
                      DataColumn(label: Text('Collab.')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Prochain CT')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((v) {
                      return DataRow(
                        cells: [
                          DataCell(Text(v.immatriculation.toUpperCase())),
                          DataCell(Text(v.dateEntree ?? '')),
                          DataCell(Text(v.marque ?? '')),
                          DataCell(Text(v.modele ?? '')),
                          DataCell(Text((v.baseGeo ?? '').toUpperCase())),
                          DataCell(Text(v.collaborateur ?? '')),
                          DataCell(Text(v.statut ?? '')),
                          DataCell(Text(v.prochainCtTech ?? '')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifier',
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  onPressed: () =>
                                      _openForm(context, vehicule: v),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: v.id == null
                                      ? null
                                      : () => _confirmDelete(context, v.id!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );

                  final framedTable = Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                    padding: const EdgeInsets.all(8),
                    child: table,
                  );

                  return Scrollbar(
                    thumbVisibility: true,
                    controller: _hScrollCtrl,
                    notificationPredicate: (n) =>
                        n.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScrollCtrl,
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _vScrollCtrl,
                        notificationPredicate: (n) =>
                            n.metrics.axis == Axis.vertical,
                        child: SingleChildScrollView(
                          controller: _vScrollCtrl,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width,
                            ),
                            child: framedTable,
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

  // ───────────── FORM / CRUD ─────────────
  Future<void> _openForm(BuildContext context, {Vehicule? vehicule}) async {
    final isEdit = vehicule != null;

    final immatCtrl = TextEditingController(
      text: vehicule?.immatriculation.toUpperCase() ?? '',
    );
    final marqueCtrl = TextEditingController(text: vehicule?.marque ?? '');
    final modeleCtrl = TextEditingController(text: vehicule?.modele ?? '');
    final baseCtrl = TextEditingController(
      text: (vehicule?.baseGeo ?? '').toUpperCase(),
    );
    final dateEntreeCtrl = TextEditingController(
      text: vehicule?.dateEntree ?? '',
    );
    final collabCtrl = TextEditingController(
      text: vehicule?.collaborateur ?? '',
    );
    final statutCtrl = TextEditingController(text: vehicule?.statut ?? '');
    final prochainCtCtrl = TextEditingController(
      text: vehicule?.prochainCtTech ?? '',
    );

    // État du dropdown "Base"
    String _selectedBase = (vehicule?.baseGeo ?? '').toUpperCase();
    final bool isPresetInitial =
        _basePresets.contains(_selectedBase) && _selectedBase != 'PERSONNALISÉ';
    if (!isPresetInitial && _selectedBase.isNotEmpty) {
      // Valeur libre → positionner sur PERSONNALISÉ + préremplir le champ libre
      _selectedBase = 'PERSONNALISÉ';
      baseCtrl.text = (vehicule?.baseGeo ?? '').toUpperCase();
    } else if (isPresetInitial) {
      baseCtrl.clear();
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(isEdit ? 'Modifier le véhicule' : 'Ajouter un véhicule'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 500,
              height: 320,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.5,
                children: [
                  // Immat (en MAJ à la saisie et à la sauvegarde)
                  _buildField(
                    'Immatriculation',
                    immatCtrl,
                    required: true,
                    toUpperOnChange: true,
                  ),
                  _buildField('Marque', marqueCtrl, required: true),
                  _buildField('Modèle', modeleCtrl, required: true),

                  // Base (Dropdown + éventuellement champ libre)
                  SizedBox(
                    width: 400,
                    child: DropdownButtonFormField<String>(
                      value: _basePresets.contains(_selectedBase)
                          ? _selectedBase
                          : 'Autre',
                      isExpanded: true,
                      decoration: _decField(
                        label: 'Base',
                        icon: Icons.location_city,
                      ),
                      items: _basePresets
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        setLocalState(() {
                          _selectedBase = v ?? 'PERSONNALISÉ';
                          if (_selectedBase != 'PERSONNALISÉ') {
                            baseCtrl.clear();
                          }
                        });
                      },
                    ),
                  ),
                  if (_selectedBase == 'PERSONNALISÉ')
                    _buildField(
                      'Base (personnalisée)',
                      baseCtrl,
                      toUpperOnChange: true,
                    ),

                  _buildField('Collaborateur', collabCtrl),
                  _buildField('Statut', statutCtrl),

                  // Prochain CT → date picker
                  _buildDatePickerField('Prochain CT', prochainCtCtrl, context),

                  // Date d’entrée → date picker
                  _buildDatePickerField(
                    'Date d’entrée',
                    dateEntreeCtrl,
                    context,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                // Base finale (preset ou champ libre), en MAJ
                final baseFinal = _selectedBase == 'PERSONNALISÉ'
                    ? baseCtrl.text.trim().toUpperCase()
                    : _selectedBase;

                final newVehicule = Vehicule(
                  id: vehicule?.id,
                  immatriculation: immatCtrl.text.trim().toUpperCase(),
                  dateEntree: dateEntreeCtrl.text.trim().isEmpty
                      ? null
                      : dateEntreeCtrl.text.trim(),
                  marque: marqueCtrl.text.trim(),
                  modele: modeleCtrl.text.trim(),
                  baseGeo: baseFinal.isEmpty ? null : baseFinal,
                  collaborateur: collabCtrl.text.trim(),
                  statut: statutCtrl.text.trim(),
                  prochainCtTech: prochainCtCtrl.text.trim().isEmpty
                      ? null
                      : prochainCtCtrl.text.trim(),
                );

                try {
                  final prov = context.read<VehiculeProvider>();
                  if (isEdit) {
                    await prov.updateVehicule(newVehicule);
                  } else {
                    await prov.addVehicule(newVehicule);
                  }
                  FocusScope.of(context).unfocus();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit ? 'Véhicule mis à jour' : 'Véhicule ajouté',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    // dispose
    immatCtrl.dispose();
    marqueCtrl.dispose();
    modeleCtrl.dispose();
    baseCtrl.dispose();
    dateEntreeCtrl.dispose();
    collabCtrl.dispose();
    statutCtrl.dispose();
    prochainCtCtrl.dispose();
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool toUpperOnChange = false,
  }) {
    return SizedBox(
      width: 400,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: _decField(label: label),
        validator: !required
            ? null
            : (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        onChanged: !toUpperOnChange
            ? null
            : (txt) {
                final up = txt.toUpperCase();
                if (up != controller.text) {
                  final sel = controller.selection;
                  controller.value = TextEditingValue(
                    text: up,
                    selection: sel,
                    composing: TextRange.empty,
                  );
                }
              },
      ),
    );
  }

  Widget _buildDatePickerField(
    String label,
    TextEditingController controller,
    BuildContext context,
  ) {
    return SizedBox(
      width: 400,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 13),
        decoration: _decField(label: label, icon: Icons.event),
        onTap: () async {
          try {
            // Si déjà rempli → utiliser comme initialDate
            DateTime? initial;
            try {
              initial = controller.text.trim().isEmpty
                  ? null
                  : DateFormat(
                      'dd/MM/yyyy',
                      'fr_FR',
                    ).parse(controller.text.trim());
            } catch (_) {}
            final picked = await showDatePicker(
              context: context,
              locale: const Locale('fr', 'FR'),
              initialDate: initial ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              controller.text = DateFormat(
                'dd/MM/yyyy',
                'fr_FR',
              ).format(picked);
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur date: $e')));
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce véhicule ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<VehiculeProvider>().deleteVehicule(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Supprimé')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// Petite pastille statistique
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _muted),
          ),
        ],
      ),
    );
  }
}
