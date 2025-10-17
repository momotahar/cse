// lib/views/incidents_form_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../providers/incident_provider.dart';

class IncidentsFormScreen extends StatefulWidget {
  final Incident? incident; // si fourni => édition

  const IncidentsFormScreen({super.key, this.incident});

  @override
  State<IncidentsFormScreen> createState() => _IncidentsFormScreenState();
}

class _IncidentsFormScreenState extends State<IncidentsFormScreen> {
  // ===== Palette & styles pro =====
  static const _brand = Color(0xFF0B5FFF);
  static const _ink = Color(0xFF0F172A);
  static const _bg = Color(0xFFF1F5F9);
  static const _cardBg = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _shadow = Color(0x1A0F172A);

  final _formKey = GlobalKey<FormState>();

  final _agentCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  DateTime _dateIncident = DateTime.now();
  DateTime? _dateContact;
  bool _arretTravail = false;

  // Liste des bases disponibles
  static const List<String> _bases = [
    'Base Sud',
    'Base Nord',
    'Base Ouest',
    'Autre',
  ];
  String? _selectedBase;

  /// Nom libre quand "Autre" est sélectionné
  final _baseOtherCtrl = TextEditingController();

  // ----- Formatage FR -----
  final DateFormat _df = DateFormat('dd/MM/yyyy');
  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    try {
      return _df.format(dt);
    } catch (_) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$d/$m/$y';
    }
  }

  @override
  void initState() {
    super.initState();
    final inc = widget.incident;
    if (inc != null) {
      _agentCtrl.text = inc.agentNom;
      _telCtrl.text = inc.telephone ?? '';
      _commentCtrl.text = inc.commentaire ?? '';
      _dateIncident = inc.dateIncident;
      _dateContact = inc.dateContact;
      _arretTravail = inc.arretTravail;

      // Normalise pour que le sélecteur corresponde
      final normalized = _normalizeBaseForSelector(inc.base);
      _selectedBase = normalized.selectorValue;

      // Si "Autre", pré-remplir le champ libre avec la base d'origine
      if (_selectedBase == 'Autre') {
        _baseOtherCtrl.text = normalized.freeText ?? inc.base;
      }
    }
  }

  @override
  void dispose() {
    _agentCtrl.dispose();
    _telCtrl.dispose();
    _commentCtrl.dispose();
    _baseOtherCtrl.dispose();
    super.dispose();
  }

  /// Retourne la valeur à afficher dans le sélecteur + éventuel texte libre.
  _BaseSelectorValue _normalizeBaseForSelector(String base) {
    final b = base.trim().toLowerCase();
    if (b.contains('sud')) return _BaseSelectorValue('Base Sud', null);
    if (b.contains('nord')) return _BaseSelectorValue('Base Nord', null);
    if (b.contains('ouest')) return _BaseSelectorValue('Base Ouest', null);
    // tout autre cas => "Autre" + conserve la valeur originale en libre
    return _BaseSelectorValue('Autre', base);
  }

  Future<void> _pickDateIncident() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateIncident,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _dateIncident = d);
  }

  Future<void> _pickDateContact() async {
    final init = _dateContact ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _dateContact = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<IncidentProvider>();

    // Base finale à enregistrer
    final String baseToSave = _selectedBase == 'Autre'
        ? _baseOtherCtrl.text.trim()
        : (_selectedBase ?? '').trim();

    final model = Incident(
      id: widget.incident?.id,
      agentNom: _agentCtrl.text.trim(),
      base: baseToSave, // non-null + cohérent
      dateIncident: _dateIncident,
      arretTravail: _arretTravail,
      telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      dateContact: _dateContact,
      commentaire: _commentCtrl.text.trim().isEmpty
          ? null
          : _commentCtrl.text.trim(),
    );

    try {
      if (model.id == null) {
        await prov.addIncident(model);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident ajouté.')));
        _formKey.currentState!.reset();
        setState(() {
          _dateIncident = DateTime.now();
          _dateContact = null;
          _arretTravail = false;
          _selectedBase = null;
          _baseOtherCtrl.clear();
        });
        _agentCtrl.clear();
        _telCtrl.clear();
        _commentCtrl.clear();
      } else {
        await prov.updateIncident(model);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident mis à jour.')));
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l’enregistrement.')),
      );
    }
  }

  // ===== Décoration unifiée des champs =====
  InputDecoration _dec({required String label, IconData? icon}) {
    return InputDecoration(
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
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.incident != null;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: _shadow,
                      blurRadius: 12,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Agent
                      TextFormField(
                        controller: _agentCtrl,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _dec(
                          label: 'Nom de l’agent *',
                          icon: Icons.person,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: 10),

                      // Base (sélecteur)
                      DropdownButtonFormField<String>(
                        value: _selectedBase,
                        isExpanded: true,
                        decoration: _dec(
                          label: 'Base *',
                          icon: Icons.location_city,
                        ),
                        items: _bases
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b,
                                child: Text(b),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedBase = val),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),

                      // Champ libre si "Autre"
                      if (_selectedBase == 'Autre') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _baseOtherCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: 'Nom de la base *',
                            icon: Icons.edit_location_alt,
                          ),
                          validator: (v) {
                            if (_selectedBase == 'Autre') {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requis';
                              }
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Dates (incident / contact)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDateIncident,
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: _dec(
                                  label: 'Date de l’incident *',
                                  icon: Icons.event,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _fmt(_dateIncident),
                                        style: const TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _pickDateIncident,
                                        style: TextButton.styleFrom(
                                          foregroundColor: _brand,
                                        ),
                                        child: const Text('Choisir'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDateContact,
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: _dec(
                                  label: 'Date de contact',
                                  icon: Icons.call,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _fmt(_dateContact),
                                        style: const TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _pickDateContact,
                                        style: TextButton.styleFrom(
                                          foregroundColor: _brand,
                                        ),
                                        child: const Text('Choisir'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Arrêt de travail
                      SwitchListTile(
                        value: _arretTravail,
                        onChanged: (v) => setState(() => _arretTravail = v),
                        title: const Text('Arrêt de travail'),
                        secondary: const Icon(Icons.health_and_safety_outlined),
                        contentPadding: EdgeInsets.zero,
                        activeColor: _brand,
                      ),
                      const SizedBox(height: 10),

                      // Téléphone
                      TextFormField(
                        controller: _telCtrl,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(label: 'Téléphone', icon: Icons.phone),
                      ),
                      const SizedBox(height: 10),

                      // Commentaire
                      TextFormField(
                        controller: _commentCtrl,
                        minLines: 2,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        autocorrect: true,
                        enableSuggestions: true,
                        textCapitalization: TextCapitalization.sentences,
                        smartDashesType: SmartDashesType.enabled,
                        smartQuotesType: SmartQuotesType.enabled,
                        enableIMEPersonalizedLearning: true,
                        decoration: _dec(
                          label: 'Commentaire',
                          icon: Icons.notes,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                isEdit ? 'Mettre à jour' : 'Enregistrer',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _formKey.currentState?.reset();
                                _agentCtrl.clear();
                                _telCtrl.clear();
                                _commentCtrl.clear();
                                _baseOtherCtrl.clear();
                                setState(() {
                                  _selectedBase = null;
                                  _dateIncident = DateTime.now();
                                  _dateContact = null;
                                  _arretTravail = false;
                                });
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Réinitialiser'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: _border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BaseSelectorValue {
  final String
  selectorValue; // 'Base Sud' | 'Base Nord' | 'Base Ouest' | 'Autre'
  final String? freeText; // si Autre, conserver la valeur affichée
  _BaseSelectorValue(this.selectorValue, this.freeText);
}
