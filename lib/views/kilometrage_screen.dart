// lib/views/kilometrage_screen.dart
// ignore_for_file: use_build_context_synchronously, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/kilometrage.dart';
import '../models/vehicule.dart';
import '../providers/kilometrage_provider.dart';
import '../providers/vehicule_provider.dart';

// ───────── Styles communs ─────────
const _brand = Color(0xFF0B5FFF);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);
const _cardBg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _shadow = Color(0x1A0F172A);

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

// Bases fréquentes (avec "Toutes les bases")
const List<String> _basePresets = <String>[
  'Toutes les bases',
  'SUD',
  'NORD',
  'OUEST',
  'EST',
  'PARIS',
  'AUTRE',
];

class KilometrageScreen extends StatefulWidget {
  const KilometrageScreen({super.key, this.initialAnnee});
  final int? initialAnnee;

  @override
  State<KilometrageScreen> createState() => _KilometrageScreenState();
}

class _KilometrageScreenState extends State<KilometrageScreen> {
  // Année courante (peut venir de initialAnnee)
  late int _annee = widget.initialAnnee ?? DateTime.now().year;

  // Sélection véhicule
  int? _selectedVehiculeId;

  // Filtres & contrôleurs
  final _vehSearchCtrl = TextEditingController();
  String _baseFilter = _basePresets.first;

  // Scroll
  final _vehListCtrl = ScrollController();
  final _rightHCtrl = ScrollController();
  final _rightVCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Chargements initiaux
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<VehiculeProvider>().loadVehicules();
      } catch (e) {
        _toast('Erreur chargement véhicules : $e');
      }

      try {
        await context.read<KilometrageProvider>().loadByAnnee(_annee);
      } catch (_) {}

      final vehs = context.read<VehiculeProvider>().vehicules;
      if (vehs.isNotEmpty) {
        setState(() => _selectedVehiculeId = vehs.first.id);
        await _reloadForSelected();
      }
    });
  }

  @override
  void dispose() {
    _vehSearchCtrl.dispose();
    _vehListCtrl.dispose();
    _rightHCtrl.dispose();
    _rightVCtrl.dispose();
    super.dispose();
  }

  // ───────── Helpers d’UI ─────────
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  // ───────── Données / calculs ─────────
  Future<void> _reloadForSelected() async {
    final id = _selectedVehiculeId;
    if (id == null) return;
    try {
      await context.read<KilometrageProvider>().loadByVehicule(
        id,
        annee: _annee,
      );
    } catch (e) {
      _toast('Erreur chargement kilométrage : $e');
    }
  }

  int? _kmForMonth(List<Kilometrage> all, int vehiculeId, int annee, int mois) {
    try {
      final k = all.firstWhere(
        (x) => x.vehiculeId == vehiculeId && x.annee == annee && x.mois == mois,
        orElse: () => throw StateError('none'),
      );
      return k.kilometrage;
    } catch (_) {
      return null;
    }
  }

  List<DropdownMenuItem<int>> _yearItems() {
    final now = DateTime.now().year;
    final years = [for (var y = now + 1; y >= now - 6; y--) y];
    return years
        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
        .toList();
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    final vehProv = context.watch<VehiculeProvider>();
    final kmProv = context.watch<KilometrageProvider>();

    // Filtrage liste véhicules (gauche)
    final search = _vehSearchCtrl.text.trim().toLowerCase();
    final allVehs = vehProv.vehicules;

    final filteredVehs = allVehs.where((v) {
      final matchesText =
          v.immatriculation.toLowerCase().contains(search) ||
          (v.baseGeo ?? '').toLowerCase().contains(search) ||
          (v.marque ?? '').toLowerCase().contains(search) ||
          (v.modele ?? '').toLowerCase().contains(search);
      final matchesBase = _baseFilter == 'Toutes les bases'
          ? true
          : ((v.baseGeo ?? '').trim().toUpperCase() == _baseFilter);
      return matchesText && matchesBase;
    }).toList()..sort((a, b) => a.immatriculation.compareTo(b.immatriculation));

    // Sélection sûre (évite l’exception quand liste vide)
    Vehicule? selectedVeh;
    if (_selectedVehiculeId != null) {
      selectedVeh = filteredVehs.firstWhere(
        (x) => x.id == _selectedVehiculeId,
        orElse: () =>
            filteredVehs.isNotEmpty ? filteredVehs.first : null as Vehicule,
      );
      if (selectedVeh == null && filteredVehs.isNotEmpty) {
        selectedVeh = filteredVehs.first;
        _selectedVehiculeId = selectedVeh.id;
      }
    } else if (filteredVehs.isNotEmpty) {
      selectedVeh = filteredVehs.first;
      _selectedVehiculeId = selectedVeh.id;
    }

    // Lignes de la table (droite)
    final months = List.generate(12, (i) => i + 1);
    final monthNames = List.generate(12, (i) {
      final d = DateTime(2025, i + 1, 1);
      return DateFormat.MMM('fr_FR').format(d); // janv., févr., …
    });

    final rows = <DataRow>[];
    final vehId = _selectedVehiculeId;

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final label = monthNames[i];
      final kmValue = (vehId == null)
          ? null
          : _kmForMonth(kmProv.items, vehId, _annee, month);

      rows.add(
        DataRow(
          cells: [
            DataCell(Text(label)),
            DataCell(Text(kmValue?.toString() ?? '')),
            DataCell(
              Row(
                children: [
                  IconButton(
                    tooltip: 'Saisir / modifier',
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: vehId == null
                        ? null
                        : () => _openUpsertDialog(
                            context,
                            vehiculeId: vehId,
                            mois: month,
                            existingKm: kmValue,
                          ),
                  ),
                  if (kmValue != null)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        try {
                          final existing = kmProv.items.firstWhere(
                            (k) =>
                                k.vehiculeId == vehId &&
                                k.annee == _annee &&
                                k.mois == month,
                          );
                          await context
                              .read<KilometrageProvider>()
                              .deleteKilometrage(existing.id!);
                          await _reloadForSelected();
                        } catch (e) {
                          _toast('Erreur suppression : $e');
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Kilométrage'),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: Row(
        children: [
          // ───────── Colonne gauche : liste véhicules ─────────
          SizedBox(
            width: 450,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: _card(
                    child: Column(
                      children: [
                        TextField(
                          controller: _vehSearchCtrl,
                          decoration: _decField(
                            label: 'Rechercher (immat., base, marque…)',
                            icon: Icons.search,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _baseFilter,
                          isExpanded: true,
                          decoration: _decField(
                            label: 'Base',
                            icon: Icons.location_city,
                          ),
                          items: _basePresets
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _baseFilter = v ?? _basePresets.first,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: _card(
                      child: Scrollbar(
                        controller: _vehListCtrl,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _vehListCtrl,
                          itemCount: filteredVehs.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: _border),
                          itemBuilder: (_, i) {
                            final v = filteredVehs[i];
                            return ListTile(
                              selected: v.id == _selectedVehiculeId,
                              onTap: () async {
                                setState(() => _selectedVehiculeId = v.id);
                                await _reloadForSelected();
                              },
                              leading: const Icon(
                                Icons.directions_car,
                                color: _brand,
                              ),
                              title: Text(
                                v.immatriculation,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${v.baseGeo ?? '-'} • ${v.marque ?? ''} ${v.modele ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ───────── Colonne droite : table kilométrage ─────────
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedVeh == null
                              ? 'Choisissez un véhicule.'
                              : 'Véhicule : ${selectedVeh.immatriculation} (${selectedVeh.baseGeo ?? '-'})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<int>(
                          value: _annee,
                          decoration: _decField(
                            label: 'Année',
                            icon: Icons.event,
                          ),
                          items: _yearItems(),
                          onChanged: (y) async {
                            if (y == null) return;
                            setState(() => _annee = y);
                            try {
                              await context
                                  .read<KilometrageProvider>()
                                  .loadByAnnee(_annee);
                              await _reloadForSelected();
                            } catch (e) {
                              _toast('Erreur actualisation : $e');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await context
                                .read<KilometrageProvider>()
                                .loadByAnnee(_annee);
                            await _reloadForSelected();
                            _toast('Liste actualisée');
                          } catch (e) {
                            _toast('Erreur actualisation : $e');
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: _card(
                      padding: const EdgeInsets.all(8),
                      child: Scrollbar(
                        controller: _rightHCtrl,
                        thumbVisibility: true,
                        notificationPredicate: (n) =>
                            n.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _rightHCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Scrollbar(
                            controller: _rightVCtrl,
                            thumbVisibility: true,
                            notificationPredicate: (n) =>
                                n.metrics.axis == Axis.vertical,
                            child: SingleChildScrollView(
                              controller: _rightVCtrl,
                              child: DataTable(
                                headingRowHeight: 36,
                                dataRowMinHeight: 30,
                                dataRowMaxHeight: 42,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                                headingRowColor:
                                    MaterialStateProperty.resolveWith(
                                      (_) => Colors.white,
                                    ),
                                columns: const [
                                  DataColumn(label: Text('Mois')),
                                  DataColumn(label: Text('Km relevé')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: rows,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────── Dialog upsert ─────────
  Future<void> _openUpsertDialog(
    BuildContext context, {
    required int vehiculeId,
    required int mois,
    int? existingKm,
  }) async {
    final kmCtrl = TextEditingController(text: existingKm?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Saisir le kilométrage'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mois : ${DateFormat.MMMM('fr_FR').format(DateTime(2025, mois, 1))}',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _decField(
                    label: 'Kilométrage (km)',
                    icon: Icons.speed,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    if (int.tryParse(v.trim()) == null) {
                      return 'Nombre invalide';
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final km = int.parse(kmCtrl.text.trim());
                await context.read<KilometrageProvider>().upsertByKey(
                  vehiculeId: vehiculeId,
                  mois: mois,
                  annee: _annee,
                  kilometrage: km,
                );
                Navigator.pop(context);
                await _reloadForSelected();
                _toast('Enregistré');
              } catch (e) {
                _toast('Erreur enregistrement : $e');
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
    );

    kmCtrl.dispose();
  }
}
