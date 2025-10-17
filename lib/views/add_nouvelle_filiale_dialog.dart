// ignore_for_file: use_build_context_synchronously

import 'package:cse_kch/models/filiale_model.dart';
import 'package:cse_kch/providers/filiale_provider.dart'; // Provider Filiale
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddNouvelFilialeDialog extends StatefulWidget {
  const AddNouvelFilialeDialog({super.key});

  @override
  State<AddNouvelFilialeDialog> createState() => _AddNouvelFilialeDialogState();
}

class _AddNouvelFilialeDialogState extends State<AddNouvelFilialeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _abrev = TextEditingController();
  final _designation = TextEditingController();
  final _adresse = TextEditingController();
  final _baseOtherCtrl = TextEditingController();
  final _abrevFocus = FocusNode();

  // Base: presets + éventuel "AUTRE…"
  static const String _kOther = 'AUTRE…';
  static const List<String> _basesPresets = ['SUD', 'NORD', 'OUEST', _kOther];
  String? _baseSel;

  bool _saving = false;

  @override
  void dispose() {
    _abrev.dispose();
    _designation.dispose();
    _adresse.dispose();
    _baseOtherCtrl.dispose();
    _abrevFocus.dispose();
    super.dispose();
  }

  String _norm(String s) => s.trim().toUpperCase();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('NOUVELLE FILIALE'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Abréviation
              TextFormField(
                controller: _abrev,
                focusNode: _abrevFocus,
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

              // Désignation
              TextFormField(
                controller: _designation,
                decoration: const InputDecoration(
                  labelText: 'Désignation',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),

              // Adresse
              TextFormField(
                controller: _adresse,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 8),

              // Base (presets + AUTRE…)
              DropdownButtonFormField<String>(
                value: _baseSel,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Base',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _basesPresets
                    .map(
                      (b) => DropdownMenuItem<String>(value: b, child: Text(b)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _baseSel = v),
                validator: (v) {
                  if (v == null) return 'Choisir une base';
                  if (v == _kOther && _baseOtherCtrl.text.trim().isEmpty) {
                    return 'Saisir la base';
                  }
                  return null;
                },
              ),
              if (_baseSel == _kOther) const SizedBox(height: 8),
              if (_baseSel == _kOther)
                TextFormField(
                  controller: _baseOtherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la base',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_baseSel == _kOther &&
                        (v == null || v.trim().isEmpty)) {
                      return 'Saisir la base';
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
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  final prov = context.read<FilialeProvider>();
                  final abrevNorm = _norm(_abrev.text);
                  // Anti-doublon **côté UI**: on regarde dans la liste chargée
                  final exists = prov.filiales.any(
                    (f) => _norm(f.abreviation) == abrevNorm,
                  );
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cette abréviation existe déjà.'),
                      ),
                    );
                    _abrevFocus.requestFocus();
                    return;
                  }

                  final chosenBase = _norm(
                    _baseSel == _kOther
                        ? _baseOtherCtrl.text
                        : (_baseSel ?? ''),
                  );

                  final filiale = FilialeModel(
                    abreviation: abrevNorm,
                    designation: _designation.text.trim(),
                    adresse: _adresse.text.trim(),
                    base: chosenBase,
                  );

                  setState(() => _saving = true);
                  try {
                    await prov.addFiliale(filiale);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filiale enregistrée')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    final msg = e.toString().contains('ABREV_DUP')
                        ? 'Cette abréviation existe déjà.'
                        : 'Erreur : $e';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
