// lib/views/entretien_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/vehicule.dart';
import '../models/entretien.dart';
import '../providers/vehicule_provider.dart';
import '../providers/entretien_provider.dart';
import '../providers/kilometrage_provider.dart';

// ─────────────────── Styles ───────────────────
const _brand = Color(0xFF0B5FFF);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);
const _cardBg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _shadow = Color(0x1A0F172A);

// ───────── Décorateur compact pour tous les champs ─────────
InputDecoration _decField({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    prefixIcon: icon != null ? Icon(icon, size: 16) : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    border: const OutlineInputBorder(),
  );
}

// Bases (filtre) et alertes
const List<String> _basePresets = <String>[
  'Toutes',
  'SUD',
  'NORD',
  'OUEST',
  'EST',
  'PARIS',
  'AUTRE',
];
const List<String> _alertFilters = <String>[
  'Toutes',
  'En retard',
  'Bientôt',
  'À jour',
];

// Types d’entretien proposés
const List<String> _typeEntretienOptions = <String>[
  'Vidange',
  'Plaquettes de frein',
  'Pneus',
  'Contrôle technique',
  'Révision générale',
  'Filtre à air',
  'Filtre à carburant',
  'Courroie de distribution',
  'Autre',
];

class EntretienScreen extends StatefulWidget {
  const EntretienScreen({super.key});

  @override
  State<EntretienScreen> createState() => _EntretienScreenState();
}

class _EntretienScreenState extends State<EntretienScreen> {
  final _vehSearchCtrl = TextEditingController();
  String _baseFilter = _basePresets.first;
  String _alertFilter = _alertFilters.first;
  int? _selectedVehiculeId;

  final _vehListCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<VehiculeProvider>().loadVehicules();
      } catch (e) {
        _toast('Erreur de chargement des véhicules : $e');
      }
      try {
        await context.read<KilometrageProvider>().loadByAnnee(
          DateTime.now().year,
        );
      } catch (_) {}

      final vehs = context.read<VehiculeProvider>().vehicules;
      if (vehs.isNotEmpty) {
        setState(() => _selectedVehiculeId = vehs.first.id);
        await _loadEntretienForSelected();
      }
    });
  }

  Future<void> _loadEntretienForSelected() async {
    final id = _selectedVehiculeId;
    if (id == null) return;
    try {
      await context.read<EntretienProvider>().loadByVehicule(id);
    } catch (e) {
      _toast('Erreur lors du chargement des entretiens : $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _vehSearchCtrl.dispose();
    _vehListCtrl.dispose();
    super.dispose();
  }

  // Normalise une valeur vers une option existante (insensible à la casse)
  String? _matchOptionCI(List<String> options, String? raw) {
    if (raw == null) return null;
    final i = options.indexWhere(
      (o) => o.trim().toLowerCase() == raw.trim().toLowerCase(),
    );
    return i == -1 ? null : options[i];
  }

  @override
  Widget build(BuildContext context) {
    final vehProv = context.watch<VehiculeProvider>();
    final entProv = context.watch<EntretienProvider>();
    final kmProv = context.watch<KilometrageProvider>();

    final search = _vehSearchCtrl.text.trim().toLowerCase();
    final allVehs = vehProv.vehicules;

    final filteredVehs = allVehs.where((v) {
      final matchesText =
          v.immatriculation.toLowerCase().contains(search) ||
          (v.baseGeo ?? '').toLowerCase().contains(search) ||
          (v.dateEntree ?? '').toLowerCase().contains(search);
      final matchesBase = _baseFilter == 'Toutes'
          ? true
          : ((v.baseGeo ?? '').trim().toUpperCase() == _baseFilter);
      bool matchesAlert = true;
      if (_alertFilter != 'Toutes') {
        final status = _vehicleAlertStatus(v, entProv, kmProv);
        matchesAlert = _mapAlertToFr(status) == _alertFilter;
      }
      return matchesText && matchesBase && matchesAlert;
    }).toList()..sort((a, b) => a.immatriculation.compareTo(b.immatriculation));

    // véhicule sélectionné robuste
    Vehicule? selectedVeh;
    if (_selectedVehiculeId != null) {
      selectedVeh = filteredVehs
          .where((x) => x.id == _selectedVehiculeId)
          .cast<Vehicule?>()
          .firstOrNull;
    }
    selectedVeh ??= filteredVehs.firstOrNull;
    _selectedVehiculeId = selectedVeh?.id;

    final entretiens = _selectedVehiculeId == null
        ? const <Entretien>[]
        : entProv.byVehicule(_selectedVehiculeId!);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Suivi des entretiens'),
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
          // ───────── Colonne gauche : liste véhicules (compacte) ─────────
          SizedBox(
            width: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: _card(
                    child: Column(
                      children: [
                        TextField(
                          controller: _vehSearchCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: _decField(
                            label: 'immat., base, date…',
                            icon: Icons.search,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _baseFilter,
                                isDense: true,
                                isExpanded: true,
                                menuMaxHeight: 280,
                                decoration: _decField(
                                  label: 'Base',
                                  icon: Icons.location_city,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                items: _basePresets
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(
                                          b,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (v) => setState(
                                  () => _baseFilter = v ?? _basePresets.first,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _alertFilter,
                                isDense: true,
                                isExpanded: true,
                                menuMaxHeight: 280,
                                decoration: _decField(
                                  label: 'Alerte',
                                  icon: Icons.warning,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                items: _alertFilters
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a,
                                        child: Text(
                                          a,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (v) => setState(
                                  () => _alertFilter = v ?? _alertFilters.first,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _card(
                      child: Scrollbar(
                        controller: _vehListCtrl,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _vehListCtrl,
                          itemCount: filteredVehs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 0.5, color: _border),
                          itemBuilder: (_, i) {
                            final v = filteredVehs[i];
                            final alert = _mapAlertToFr(
                              _vehicleAlertStatus(v, entProv, kmProv),
                            );
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              selected: v.id == _selectedVehiculeId,
                              onTap: () async {
                                setState(() => _selectedVehiculeId = v.id);
                                await _loadEntretienForSelected();
                              },
                              leading: const Icon(
                                Icons.directions_car,
                                color: _brand,
                                size: 18,
                              ),
                              title: Text(
                                v.immatriculation,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${v.baseGeo ?? '-'} • ${v.dateEntree ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              // trailing: _alertChipFr(alert),
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
          // ───────── Colonne droite : entretiens (card & table étendues) ─────────
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
                              ? 'Aucun véhicule'
                              : 'Véhicule : ${selectedVeh.immatriculation} (${selectedVeh.baseGeo ?? '-'})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: selectedVeh == null
                            ? null
                            : () => _openEntretienForm(
                                context,
                                vehiculeId: selectedVeh!.id!,
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvel entretien'),
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
                    child: SizedBox.expand(
                      child: _card(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              primary: false,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  columnSpacing: 0,
                                  horizontalMargin: 0,
                                  headingRowHeight: 32,
                                  dataRowMinHeight: 28,
                                  dataRowMaxHeight: 38,
                                  headingTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 1.0,
                                    color: _ink,
                                  ),
                                  headingRowColor:
                                      WidgetStateProperty.resolveWith(
                                        (_) => Colors.white,
                                      ),
                                  columns: [
                                    DataColumn(label: _th('Type', 70)),
                                    DataColumn(
                                      label: _th('À prévoir\navant le', 80),
                                    ),
                                    DataColumn(
                                      label: _th('Km à ne pas\ndépasser', 80),
                                    ),
                                    DataColumn(label: _th('Réalisé le', 80)),
                                    DataColumn(
                                      label: _th(
                                        'Km lors de\nl’entretien',
                                        100,
                                      ),
                                    ),
                                    DataColumn(label: _th('Statut', 80)),
                                    DataColumn(label: _th('Actions', 80)),
                                  ],
                                  rows: entretiens.map((e) {
                                    final alert = _mapAlertToFr(
                                      _alertFor(e, kmProv),
                                    );
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(e.type)),
                                        DataCell(Text(e.datePrevue ?? '')),
                                        DataCell(
                                          Text(e.kmPrevus?.toString() ?? ''),
                                        ),
                                        DataCell(Text(e.dateFaite ?? '')),
                                        DataCell(
                                          Text(e.kmFaits?.toString() ?? ''),
                                        ),
                                        DataCell(_alertChipFr(alert)),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () =>
                                                    _openEntretienForm(
                                                      context,
                                                      vehiculeId: e.vehiculeId,
                                                      entretien: e,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteEntretien(
                                                      context,
                                                      e,
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
        ],
      ),
    );
  }

  // ───────── Helpers UI ─────────
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

  Widget _alertChipFr(String label) {
    Color bg, fg;
    switch (label) {
      case 'En retard':
        bg = Colors.redAccent.shade100;
        fg = Colors.red.shade800;
        break;
      case 'Bientôt':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        break;
      default:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  // Entête compacte qui autorise le retour à la ligne
  Widget _th(String text, double w) {
    return SizedBox(
      width: w,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Helpers d'entête et de cellule (centrés, largeur fixe)
  DataCell _td(String? text, double w, {bool bold = false}) {
    return DataCell(
      SizedBox(
        width: w,
        child: Center(
          child: Text(
            text ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              height: 1.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  DataCell _tdWidget(Widget child, double w) {
    return DataCell(
      SizedBox(
        width: w,
        child: Center(child: child),
      ),
    );
  }

  // ───────── Logique d’alerte ─────────
  String _mapAlertToFr(String code) {
    switch (code) {
      case 'DUE':
        return 'En retard';
      case 'SOON':
        return 'Bientôt';
      default:
        return 'À jour';
    }
  }

  String _alertFor(Entretien e, KilometrageProvider kmProv) {
    if ((e.dateFaite != null && e.dateFaite!.trim().isNotEmpty) ||
        (e.kmFaits != null))
      return 'OK';

    final kmActuel = _kmActuelForVehicule(e.vehiculeId, kmProv);
    final dp = _parseDate(e.datePrevue);

    if (dp != null) {
      final diffDays = dp.difference(DateTime.now()).inDays;
      if (diffDays <= 0) return 'DUE';
      if (diffDays <= 14) return 'SOON';
    }
    if (e.kmPrevus != null && kmActuel != null) {
      final diff = e.kmPrevus! - kmActuel;
      if (diff <= 0) return 'DUE';
      if (diff <= 500) return 'SOON';
    }
    return 'OK';
  }

  String _vehicleAlertStatus(
    Vehicule v,
    EntretienProvider entProv,
    KilometrageProvider kmProv,
  ) {
    final list = entProv.byVehicule(v.id ?? -1);
    String worst = 'OK';
    for (final e in list) {
      final a = _alertFor(e, kmProv);
      if (a == 'DUE') return 'DUE';
      if (a == 'SOON') worst = 'SOON';
    }
    return worst;
  }

  int? _kmActuelForVehicule(int vehiculeId, KilometrageProvider kmProv) {
    try {
      final items = kmProv.items.where((k) => k.vehiculeId == vehiculeId);
      int? maxKm;
      for (final k in items) {
        if (maxKm == null || k.kilometrage > maxKm) maxKm = k.kilometrage;
      }
      return maxKm;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(String? fr) {
    if (fr == null || fr.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy', 'fr_FR').parseStrict(fr);
    } catch (_) {
      return null;
    }
  }

  // ───────── CRUD Entretien ─────────
  Future<void> _confirmDeleteEntretien(
    BuildContext context,
    Entretien e,
  ) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer l’entretien « ${e.type} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await context.read<EntretienProvider>().deleteEntretien(e.id!);
                Navigator.pop(context);
                _toast('Entretien supprimé');
              } catch (err) {
                _toast('Erreur suppression : $err');
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntretienForm(
    BuildContext context, {
    required int vehiculeId,
    Entretien? entretien,
  }) async {
    final isEdit = entretien != null;

    // Normalise la valeur existante (ex: "vidange" -> "Vidange")
    final typeCtrl = ValueNotifier<String?>(
      _matchOptionCI(_typeEntretienOptions, entretien?.type),
    );

    final prevDateCtrl = TextEditingController(
      text: entretien?.datePrevue ?? '',
    );
    final kmMaxCtrl = TextEditingController(
      text: entretien?.kmPrevus?.toString() ?? '',
    );
    final faitLeCtrl = TextEditingController(text: entretien?.dateFaite ?? '');
    final kmFaitsCtrl = TextEditingController(
      text: entretien?.kmFaits?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Modifier un entretien' : 'Nouvel entretien'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 520,
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                // Type d’entretien (Dropdown) — valeur normalisée + 'value:' (pas initialValue)
                SizedBox(
                  width: 240,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: typeCtrl,
                    builder: (_, value, __) {
                      final normalized = _matchOptionCI(
                        _typeEntretienOptions,
                        value,
                      );
                      return DropdownButtonFormField<String>(
                        value: normalized,
                        isExpanded: true,
                        items: _typeEntretienOptions
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(growable: false),
                        onChanged: (v) => typeCtrl.value = v,
                        decoration: _decField(label: 'Type d’entretien'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      );
                    },
                  ),
                ),
                // À prévoir avant le
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: prevDateCtrl,
                    readOnly: true,
                    decoration: _decField(
                      label: 'À prévoir avant le',
                      icon: Icons.event,
                    ),
                    onTap: () async {
                      try {
                        final picked = await showDatePicker(
                          context: context,
                          locale: const Locale('fr', 'FR'),
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) {
                          prevDateCtrl.text = DateFormat(
                            'dd/MM/yyyy',
                            'fr_FR',
                          ).format(picked);
                        }
                      } catch (e) {
                        _toast('Erreur date : $e');
                      }
                    },
                  ),
                ),
                // Km à ne pas dépasser
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: kmMaxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _decField(
                      label: 'Kilométrage à ne pas dépasser',
                    ),
                  ),
                ),
                // Réalisé le
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: faitLeCtrl,
                    readOnly: true,
                    decoration: _decField(
                      label: 'Réalisé le',
                      icon: Icons.event_available,
                    ),
                    onTap: () async {
                      try {
                        final picked = await showDatePicker(
                          context: context,
                          locale: const Locale('fr', 'FR'),
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) {
                          faitLeCtrl.text = DateFormat(
                            'dd/MM/yyyy',
                            'fr_FR',
                          ).format(picked);
                        }
                      } catch (e) {
                        _toast('Erreur date : $e');
                      }
                    },
                  ),
                ),
                // Km lors de l’entretien
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: kmFaitsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _decField(
                      label: 'Kilométrage lors de l’entretien',
                    ),
                  ),
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
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final canonicalType =
                    _matchOptionCI(_typeEntretienOptions, typeCtrl.value!) ??
                    typeCtrl.value!.trim();
                final e = Entretien(
                  id: entretien?.id,
                  vehiculeId: vehiculeId,
                  type: canonicalType,
                  datePrevue: prevDateCtrl.text.trim().isEmpty
                      ? null
                      : prevDateCtrl.text.trim(),
                  kmPrevus: int.tryParse(kmMaxCtrl.text.trim()),
                  dateFaite: faitLeCtrl.text.trim().isEmpty
                      ? null
                      : faitLeCtrl.text.trim(),
                  kmFaits: int.tryParse(kmFaitsCtrl.text.trim()),
                );
                final prov = context.read<EntretienProvider>();
                if (entretien == null) {
                  await prov.addEntretien(e, forVehiculeReload: vehiculeId);
                } else {
                  await prov.updateEntretien(e);
                }
                Navigator.pop(context);
                _toast(
                  entretien == null
                      ? 'Entretien ajouté'
                      : 'Entretien mis à jour',
                );
              } catch (err) {
                _toast('Erreur enregistrement : $err');
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// petite extension utilitaire
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
