// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:cse_kch/models/agent_model.dart';
import 'package:cse_kch/models/filiale_model.dart';
import 'package:cse_kch/providers/filiale_provider.dart';
import 'package:cse_kch/providers/agent_provider.dart';

class AddNouvelAgentDialog extends StatefulWidget {
  const AddNouvelAgentDialog({super.key});

  @override
  State<AddNouvelAgentDialog> createState() => _AddNouvelAgentDialogState();
}

class _AddNouvelAgentDialogState extends State<AddNouvelAgentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _ordreCtrl = TextEditingController(text: '0');

  String? _statutSel;
  String? _filialeSel; // on stocke l'abréviation choisie
  bool _saving = false;

  final List<String> _statuts = const [
    'DS',
    'Titulaire',
    'DS-Titulaire',
    'Suppléant',
    'RS',
    'RP',
    'Invité',
  ];

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _ordreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filialeProv = context.watch<FilialeProvider>();
    final filiales = filialeProv.filiales;
    final filialeAbrevs = filiales.map((f) => f.abreviation).toList();
    final noFiliale = filialeAbrevs.isEmpty;

    return AlertDialog(
      title: const Text('NOUVEL AGENT'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (noFiliale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Aucune filiale trouvée. Créez d’abord une filiale.",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Nom
              TextFormField(
                controller: _nom,
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

              // Prénom
              TextFormField(
                controller: _prenom,
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

              // Statut
              DropdownButtonFormField<String>(
                value: _statutSel,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _statuts
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _statutSel = v),
                validator: (v) => v == null ? 'Choisir un statut' : null,
              ),
              const SizedBox(height: 8),

              // Filiale
              DropdownButtonFormField<String>(
                value: _filialeSel,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Filiale',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: filialeAbrevs
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: noFiliale
                    ? null
                    : (v) => setState(() => _filialeSel = v),
                validator: (v) => noFiliale
                    ? null
                    : (v == null ? 'Choisir une filiale' : null),
              ),
              const SizedBox(height: 8),

              // Ordre (optionnel)
              TextFormField(
                controller: _ordreCtrl,
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
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: (_saving || noFiliale)
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _saving = true);
                  try {
                    // Sélection filiale sécurisée
                    final FilialeModel filiale = filiales.firstWhere(
                      (f) => f.abreviation == _filialeSel,
                      orElse: () => throw Exception(
                        'Filiale inconnue. Rafraîchissez la liste.',
                      ),
                    );

                    final ordreVal = int.tryParse(_ordreCtrl.text.trim()) ?? 0;

                    final agent = AgentModel(
                      name: _nom.text.trim().toUpperCase(),
                      surname: _prenom.text.trim().toUpperCase(),
                      statut: _statutSel!, // validé par le form
                      filiale: filiale, // contient un id valide (FK)
                      dateAjout: DateTime.now(),
                      ordre: ordreVal,
                    );

                    await context.read<AgentProvider>().addAgent(agent);

                    if (!mounted) return;
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Agent enregistré')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
