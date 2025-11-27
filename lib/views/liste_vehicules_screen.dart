// lib/views/list_vehicules_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:cse_kch/providers/entretien_provider.dart';
import 'package:cse_kch/providers/parametres_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vehicule.dart';
import '../providers/vehicule_provider.dart';

// ───────────────── Constantes ─────────────────
const List<String> _basePresets = [
  'Sud',
  'Nord',
  'Ouest',
  'Est',
  'Paris',
  'Autre',
];

// Couleurs
Color _alertColor(AlerteCouleur c) {
  switch (c) {
    case AlerteCouleur.rouge:
      return Colors.red;
    case AlerteCouleur.orange:
      return Colors.orange;
    case AlerteCouleur.none:
    default:
      return Colors.green;
  }
}

DateTime? _parseFrDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    return DateFormat('dd/MM/yyyy', 'fr_FR').parse(s.trim());
  } catch (_) {
    return null;
  }
}

Color _ctColor(DateTime? d) {
  if (d == null) return Colors.grey; // date absente
  final today = DateTime.now();
  final onlyDay = DateTime(today.year, today.month, today.day);
  final diff = d.difference(onlyDay).inDays;

  if (diff < 0) return Colors.red; // déjà dépassé
  if (diff <= 30) return Colors.red; // <= 30 jours
  if (diff <= 60) return Colors.orange; // 31 à 60 jours
  return Colors.green; // > 60 jours
}

// Pastille (calculée sur kmMois / kmMax)
Color _colorFromRatio(double ratio) {
  if (ratio >= 1.0) return Colors.red; // dépassement
  if (ratio >= 0.9) return Colors.orange; // proche du seuil (90%)
  return Colors.green; // ok
}

String formatKm(int? km) =>
    km == null ? '-' : '${NumberFormat.decimalPattern('fr_FR').format(km)} km';

InputDecoration _decField(
  BuildContext context, {
  required String label,
  IconData? icon,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: cs.surface,
    prefixIcon: icon == null ? null : Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: cs.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: cs.primary, width: 1.2),
    ),
  );
}

// ──────────────────────────────── Écran principal ────────────────────────────────
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
        await context.read<ParametresProvider>().loadParametres();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
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
    final vehProv = context.watch<VehiculeProvider>();
    final paramProv = context.watch<ParametresProvider>();
    final seuilFrein =
        paramProv.parametres?.seuilFrein ?? 10000; // seuil pris en référence

    final cs = Theme.of(context).colorScheme;

    final List<String> filterOptions = ['Toutes les bases', ..._basePresets];
    final currentBase = filterOptions.contains(_baseFilter)
        ? _baseFilter
        : 'Toutes les bases';
    final Set<String> presetsUpper = _basePresets
        .map((e) => e.toUpperCase())
        .toSet();

    final filtered = vehProv.vehicules.where((v) {
      final s = _searchText.toUpperCase();
      final immat = v.immatriculation.toUpperCase();
      final baseUpper = (v.baseGeo ?? '').toUpperCase();
      final marque = (v.marque ?? '').toUpperCase();
      final modele = (v.modele ?? '').toUpperCase();
      final statut = (v.statut ?? '').toUpperCase();

      final matchesText =
          immat.contains(s) ||
          baseUpper.contains(s) ||
          marque.contains(s) ||
          modele.contains(s) ||
          statut.contains(s);

      bool matchesBase;
      if (currentBase == 'Toutes les bases') {
        matchesBase = true;
      } else if (currentBase == 'Autre') {
        matchesBase = baseUpper.isNotEmpty && !presetsUpper.contains(baseUpper);
      } else {
        matchesBase = baseUpper == currentBase.toUpperCase();
      }

      return matchesText && matchesBase;
    }).toList();

    final totalCount = vehProv.vehicules.length;
    final filteredCount = filtered.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Parc véhicules')),
      body: Column(
        children: [
          // Filtres
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: _decField(
                      context,
                      label: 'Rechercher (immat., base, marque…)',
                      icon: Icons.search,
                    ),
                    onChanged: (v) => setState(() => _searchText = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: currentBase,
                    isExpanded: true,
                    decoration: _decField(
                      context,
                      label: 'Filtrer par base',
                      icon: Icons.location_city,
                    ),
                    items: filterOptions
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(growable: false),
                    onChanged: (v) =>
                        setState(() => _baseFilter = v ?? 'Toutes les bases'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Paramètres'),
                  onPressed: () => _showParametresDialog(context),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: filtered.isEmpty
                      ? null
                      : () async {
                          final sVid =
                              paramProv.parametres?.seuilVidange ?? 10000;
                          final sFrein =
                              paramProv.parametres?.seuilFrein ?? 10000;
                          await _exportVehiculesPdf(filtered, sVid, sFrein);
                        },
                ),
                const SizedBox(width: 12),
                _buildCountBadge(filteredCount, totalCount, cs),
              ],
            ),
          ),

          // Tableau
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Builder(
                builder: (ctx) {
                  if (vehProv.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (vehProv.error != null) {
                    return Center(child: Text(vehProv.error!));
                  }
                  if (filtered.isEmpty) {
                    return const Center(child: Text('Aucun véhicule trouvé.'));
                  }

                  return Scrollbar(
                    controller: _hScrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScrollCtrl,
                      child: SingleChildScrollView(
                        controller: _vScrollCtrl,
                        child: DataTable(
                          headingRowHeight: 36,
                          dataRowMinHeight: 30,
                          dataRowMaxHeight: 44,
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          headingRowColor: MaterialStateProperty.resolveWith(
                            (_) => cs.surface,
                          ),
                          columns: const [
                            DataColumn(label: Text('Immat.')),
                            DataColumn(label: Text('Base')),
                            DataColumn(label: Text('Collaborateur')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('Prochain CT')),
                            DataColumn(label: Text('Kit sécu')),
                            DataColumn(label: Text('Km réf.')),
                            DataColumn(label: Text('Km mois')),
                            DataColumn(label: Text('Km max vid.')),
                            DataColumn(label: Text('Km max frein')),
                            DataColumn(label: Text('Alertes')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((v) {
                            // --- Calculs km avec 2 seuils (vidange + frein) ---
                            final int kmRef =
                                v.kmRef ?? 0; // dernier km d’entretien
                            final int kmMois =
                                v.kmMois ?? kmRef; // relevé courant

                            final int sVid =
                                paramProv.parametres?.seuilVidange ?? 10000;
                            final int sFrein =
                                paramProv.parametres?.seuilFrein ?? 10000;

                            final int kmMaxVid = kmRef + sVid;
                            final int kmMaxFrein = kmRef + sFrein;

                            final int critMax = (kmMaxVid < kmMaxFrein)
                                ? kmMaxVid
                                : kmMaxFrein;
                            final double ratio = critMax == 0
                                ? 0.0
                                : (kmMois / critMax.toDouble());
                            final Color color = _colorFromRatio(ratio);

                            final bool alertVid = kmMois >= kmMaxVid;
                            final bool alertFr = kmMois >= kmMaxFrein;
                            final Color colorVid = alertVid
                                ? Colors.red
                                : Colors.green;
                            final Color colorFr = alertFr
                                ? Colors.red
                                : Colors.green;

                            return DataRow(
                              cells: [
                                DataCell(Text(v.immatriculation.toUpperCase())),
                                DataCell(Text(v.baseGeo ?? '')),
                                DataCell(Text(v.collaborateur ?? '')),
                                DataCell(Text(v.statut ?? '')),

                                // Prochain CT avec pastille
                                DataCell(
                                  Builder(
                                    builder: (_) {
                                      final ctDate = _parseFrDate(
                                        v.prochainCtTech,
                                      );
                                      final col = _ctColor(ctDate);
                                      return Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: col.withOpacity(0.85),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: col,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(v.prochainCtTech ?? ''),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                // Kit sécu (toggle)
                                DataCell(
                                  IconButton(
                                    tooltip: (v.kitSecurite ?? false)
                                        ? 'Kit disponible'
                                        : 'Kit manquant',
                                    icon: Icon(
                                      (v.kitSecurite ?? false)
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: (v.kitSecurite ?? false)
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: v.id == null
                                        ? null
                                        : () async {
                                            try {
                                              final nv = v.copyWith(
                                                kitSecurite:
                                                    !(v.kitSecurite ?? false),
                                              );
                                              await context
                                                  .read<VehiculeProvider>()
                                                  .updateVehicule(nv);
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    (nv.kitSecurite ?? false)
                                                        ? 'Kit sécurité: présent'
                                                        : 'Kit sécurité: manquant',
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Erreur mise à jour: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                  ),
                                ),

                                // Km réf. (pastille)
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.85),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: color,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(formatKm(kmRef)),
                                    ],
                                  ),
                                ),

                                // Km mois
                                DataCell(Text(formatKm(kmMois))),

                                // Km max vidange
                                DataCell(Text(formatKm(kmMaxVid))),

                                // Km max frein
                                DataCell(Text(formatKm(kmMaxFrein))),

                                // Alertes
                                DataCell(
                                  Row(
                                    children: [
                                      _badge('VID', colorVid),
                                      const SizedBox(width: 8),
                                      _badge('FR', colorFr),
                                    ],
                                  ),
                                ),

                                // Actions
                                DataCell(
                                  Row(
                                    children: [
                                      // Saisir km/mois
                                      IconButton(
                                        tooltip: 'Saisir km/mois',
                                        icon: const Icon(
                                          Icons.speed,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                        onPressed: v.id == null
                                            ? null
                                            : () async {
                                                try {
                                                  final km = await _askKmMois(
                                                    context,
                                                  );
                                                  if (km == null) return;

                                                  final int kmRefActuel =
                                                      v.kmRef ?? 0;
                                                  if (km < kmRefActuel) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Saisie refusée : $km < km réf ${NumberFormat.decimalPattern("fr_FR").format(kmRefActuel)}',
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  final nv = v.copyWith(
                                                    kmMois: km,
                                                  );
                                                  await context
                                                      .read<VehiculeProvider>()
                                                      .updateVehicule(nv);

                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Kilométrage du mois enregistré',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Erreur enregistrement km/mois : $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                      ),

                                      // Enregistrer entretien
                                      IconButton(
                                        tooltip: 'Enregistrer entretien',
                                        icon: const Icon(
                                          Icons.build,
                                          size: 18,
                                          color: Colors.blueGrey,
                                        ),
                                        onPressed: v.id == null
                                            ? null
                                            : () async {
                                                final info =
                                                    await _askEntretienDialog(
                                                      context,
                                                    );
                                                if (info == null) return;

                                                await context
                                                    .read<EntretienProvider>()
                                                    .enregistrerEntretien(
                                                      vehiculeId: v.id!,
                                                      type: info.type,
                                                      kmEntr: info.kmEntr,
                                                    );

                                                final nv = v.copyWith(
                                                  kmRef: info.kmEntr,
                                                  kmMois: info.kmEntr,
                                                );
                                                await context
                                                    .read<VehiculeProvider>()
                                                    .updateVehicule(nv);

                                                if (!mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Entretien ajouté et km de référence mis à jour',
                                                    ),
                                                  ),
                                                );
                                              },
                                      ),

                                      // Modifier
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

                                      // Supprimer
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: v.id == null
                                            ? null
                                            : () => _confirmDelete(
                                                context,
                                                v.id!,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
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

  Future<void> _showParametresDialog(BuildContext context) async {
    final paramProv = context.read<ParametresProvider>();
    await paramProv.loadParametres();

    final seuilVidangeCtrl = TextEditingController(
      text: paramProv.parametres?.seuilVidange.toString() ?? '10000',
    );
    final seuilFreinCtrl = TextEditingController(
      text: paramProv.parametres?.seuilFrein.toString() ?? '10000',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paramètres d’entretien'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: seuilVidangeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Seuil vidange (km)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: seuilFreinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Seuil frein (km)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await paramProv.updateParametres(10000, 10000);
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seuils réinitialisés')),
              );
            },
            child: const Text('Réinitialiser'),
          ),
          FilledButton(
            onPressed: () async {
              final sV = int.tryParse(seuilVidangeCtrl.text.trim()) ?? 10000;
              final sF = int.tryParse(seuilFreinCtrl.text.trim()) ?? 10000;
              await paramProv.updateParametres(sV, sF);
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paramètres mis à jour')),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ─────────── FORMULAIRE (ajout des champs km_ref + kit_securite) ───────────
  Future<void> _openForm(BuildContext context, {Vehicule? vehicule}) async {
    final isEdit = vehicule != null;

    final immatCtrl = TextEditingController(
      text: vehicule?.immatriculation ?? '',
    );
    final marqueCtrl = TextEditingController(text: vehicule?.marque ?? '');
    final modeleCtrl = TextEditingController(text: vehicule?.modele ?? '');
    final baseCtrl = TextEditingController(text: vehicule?.baseGeo ?? '');
    final collabCtrl = TextEditingController(
      text: vehicule?.collaborateur ?? '',
    );
    final statutCtrl = TextEditingController(text: vehicule?.statut ?? '');
    final prochainCtCtrl = TextEditingController(
      text: vehicule?.prochainCtTech ?? '',
    );
    final dateEntreeCtrl = TextEditingController(
      text: vehicule?.dateEntree ?? '',
    );

    // nouveaux champs
    final kmRefCtrl = TextEditingController(
      text: (vehicule?.kmRef ?? 0).toString(),
    );
    bool kitSecurite = vehicule?.kitSecurite ?? false;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Modifier le véhicule' : 'Ajouter un véhicule'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 520,
              height: 380,
              child: ListView(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 240,
                        child: _buildField(
                          innerCtx,
                          'Immatriculation',
                          immatCtrl,
                          required: true,
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildField(innerCtx, 'Marque', marqueCtrl),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildField(innerCtx, 'Modèle', modeleCtrl),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildField(innerCtx, 'Base', baseCtrl),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildField(
                          innerCtx,
                          'Collaborateur',
                          collabCtrl,
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildField(innerCtx, 'Statut', statutCtrl),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildDatePickerField(
                          'Prochain CT',
                          prochainCtCtrl,
                          innerCtx,
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: _buildDatePickerField(
                          'Date entrée',
                          dateEntreeCtrl,
                          innerCtx,
                        ),
                      ),

                      // KM de référence
                      SizedBox(
                        width: 240,
                        child: TextFormField(
                          controller: kmRefCtrl,
                          decoration: _decField(
                            innerCtx,
                            label: 'Km réf. (numérique)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requis';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Nombre ≥ 0';
                            return null;
                          },
                        ),
                      ),

                      // Kit sécurité (switch)
                      SizedBox(
                        width: 240,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(innerCtx).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                innerCtx,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Kit sécurité'),
                              Switch(
                                value: kitSecurite,
                                onChanged: (val) =>
                                    setLocal(() => kitSecurite = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final kmRefVal = int.tryParse(kmRefCtrl.text.trim()) ?? 0;

                final newVehicule = Vehicule(
                  id: vehicule?.id,
                  immatriculation: immatCtrl.text.trim().toUpperCase(),
                  marque: marqueCtrl.text.trim(),
                  modele: modeleCtrl.text.trim(),
                  baseGeo: baseCtrl.text.trim(),
                  collaborateur: collabCtrl.text.trim(),
                  statut: statutCtrl.text.trim(),
                  prochainCtTech: prochainCtCtrl.text.trim(),
                  dateEntree: dateEntreeCtrl.text.trim(),
                  kmRef: kmRefVal,
                  kitSecurite: kitSecurite,
                );

                final prov = Provider.of<VehiculeProvider>(
                  dialogCtx,
                  listen: false,
                );

                try {
                  if (isEdit) {
                    await prov.updateVehicule(newVehicule);
                  } else {
                    await prov.addVehicule(newVehicule);
                  }

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop(); // ferme le dialog
                  }
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(
                      dialogCtx,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
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
    collabCtrl.dispose();
    statutCtrl.dispose();
    prochainCtCtrl.dispose();
    dateEntreeCtrl.dispose();
    kmRefCtrl.dispose();
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decField(context, label: label),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Requis' : null
          : null,
    );
  }

  Widget _buildDatePickerField(
    String label,
    TextEditingController controller,
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _decField(context, label: label, icon: Icons.event),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          locale: const Locale('fr', 'FR'),
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          controller.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(picked);
        }
      },
    );
  }

  // ─────────── Dialogs ───────────
  Future<int?> _askKmMois(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir kilométrage du mois'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Kilométrage relevé',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final km = int.tryParse(ctrl.text.trim());
              if (km == null) return;
              Navigator.pop(ctx, km);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<_EntretienInfo?> _askEntretienDialog(BuildContext context) async {
    final kmCtrl = TextEditingController();
    return showDialog<_EntretienInfo>(
      context: context,
      builder: (ctx) {
        String type = 'vidange'; // état local du dialog

        return StatefulBuilder(
          builder: (ctx, setStateSB) => AlertDialog(
            title: const Text('Enregistrer un entretien'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Type :'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: type,
                        items: const [
                          DropdownMenuItem(
                            value: 'vidange',
                            child: Text('Vidange'),
                          ),
                          DropdownMenuItem(
                            value: 'frein',
                            child: Text('Freins'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setStateSB(() => type = v); // reconstruit le dialog
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kmCtrl,
                    decoration: const InputDecoration(
                      labelText: 'KM relevé',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final km = int.tryParse(kmCtrl.text.trim());
                  if (km == null) return;
                  Navigator.pop(ctx, _EntretienInfo(type: type, kmEntr: km));
                },
                child: const Text('Valider'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce véhicule ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final prov = Provider.of<VehiculeProvider>(
                dialogCtx,
                listen: false,
              );
              try {
                await prov.deleteVehicule(id);

                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop(); // ferme le dialog
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Véhicule supprimé')),
                );
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Erreur suppression: $e')),
                  );
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _badge(String txt, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(.15),
      border: Border.all(color: c),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      txt,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );

  // ==== Couleurs PDF (simples) ====
  static const PdfColor kHeaderBg = PdfColor.fromInt(0xFFEFF6FF);
  static const PdfColor kOddRowBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor kTableLine = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor kTitleBg = PdfColor.fromInt(0xFF2563EB);

  static const PdfColor kGreen = PdfColor.fromInt(0xFF16A34A);
  static const PdfColor kRed = PdfColor.fromInt(0xFFDC2626);

  Future<void> _exportVehiculesPdf(
    List<Vehicule> rows,
    int sVid,
    int sFrein,
  ) async {
    try {
      final bytes = await _buildVehiculesPdfBytes(
        rows,
        sVid,
        sFrein,
        PdfPageFormat.a4,
      );
      final dir = await getTemporaryDirectory();
      final name =
          'vehicules_${DateTime.now().toIso8601String().split('T').first}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (mounted && result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF enregistré : ${file.path}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF : $e')));
    }
  }

  Future<Uint8List> _buildVehiculesPdfBytes(
    List<Vehicule> rows,
    int sVid,
    int sFrein,
    PdfPageFormat format,
  ) async {
    // Fonts
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
      );
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular!, bold: fontBold!),
    );

    final header = pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: kTitleBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Parc véhicules',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
          ),
        ],
      ),
    );

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: kHeaderBg),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _pdfHeaderCell('Immat.'),
          _pdfHeaderCell('Base'),
          _pdfHeaderCell('Collab.'),
          _pdfHeaderCell('Statut'),
          _pdfHeaderCell('Prochain CT'),
          _pdfHeaderCell('Kit sécu'),
          _pdfHeaderCell('Km réf.'),
          _pdfHeaderCell('Km mois'),
          _pdfHeaderCell('Alertes'),
        ],
      ),
    ];

    for (int i = 0; i < rows.length; i++) {
      final v = rows[i];

      final kmRef = v.kmRef ?? 0;
      final kmMois = v.kmMois ?? kmRef;
      final kmMaxVid = kmRef + sVid;
      final kmMaxFrein = kmRef + sFrein;

      final alertVid = kmMois >= kmMaxVid;
      final alertFr = kmMois >= kmMaxFrein;

      final ctText = v.prochainCtTech ?? '';

      tableRows.add(
        pw.TableRow(
          decoration: i.isOdd
              ? const pw.BoxDecoration(color: kOddRowBg)
              : const pw.BoxDecoration(),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            _pdfBodyCell(v.immatriculation.toUpperCase()),
            _pdfBodyCell((v.baseGeo ?? '').toUpperCase()),
            _pdfBodyCell(v.collaborateur ?? ''),
            _pdfBodyCell(v.statut ?? ''),
            _pdfBodyCell(ctText),
            _pdfBodyCell((v.kitSecurite ?? false) ? 'Oui' : 'Non'),
            _pdfBodyCell(_fmtKm(kmRef)),
            _pdfBodyCell(_fmtKm(kmMois)),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  _pdfAlertMark(label: 'VID', isAlert: alertVid),
                  pw.SizedBox(width: 6),
                  _pdfAlertMark(label: 'FR', isAlert: alertFr),
                ],
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          header,
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: kTableLine, width: 0.4),
              outside: const pw.BorderSide(color: kTableLine, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), // Immat.
              1: pw.FlexColumnWidth(0.8), // Base
              2: pw.FlexColumnWidth(1.5), // Collab
              3: pw.FlexColumnWidth(1.0), // Statut
              4: pw.FlexColumnWidth(1.2), // CT
              5: pw.FlexColumnWidth(0.9), // Kit
              6: pw.FlexColumnWidth(1.0), // Km ref
              7: pw.FlexColumnWidth(1.0), // Km mois
              // 8: pw.FlexColumnWidth(1.0), // Alertes
            },
            children: tableRows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
  );

  pw.Widget _pdfBodyCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
  );

  String _fmtKm(int v) =>
      '${NumberFormat.decimalPattern("fr_FR").format(v)} km';

  pw.Widget _pdfAlertMark({required String label, required bool isAlert}) {
    final PdfColor c = isAlert ? kRed : kGreen;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: c, width: 0.6),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(width: 4),
          pw.Text(
            isAlert ? '✗' : '✓',
            style: pw.TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int filtered, int total, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car, size: 16),
          const SizedBox(width: 6),
          Text(
            '$filtered',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (total > 0 && filtered != total) ...[
            const Text(' / '),
            Text('$total'),
          ],
        ],
      ),
    );
  }
}

class _EntretienInfo {
  final String type;
  final int kmEntr;
  _EntretienInfo({required this.type, required this.kmEntr});
}
