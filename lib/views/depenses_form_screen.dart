// lib/views/depenses_form_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/depense.dart';
import '../providers/depense_provider.dart';

class DepensesFormScreen extends StatefulWidget {
  final Depense? depense;
  const DepensesFormScreen({super.key, this.depense});

  @override
  State<DepensesFormScreen> createState() => _DepensesFormScreenState();
}

class _DepensesFormScreenState extends State<DepensesFormScreen> {
  // Palette alignée sur la charte
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _ink = Color(0xFF0F172A); // slate-900
  static const _cardBg = Color(0xFFF8FAFC); // slate-50
  static const _bg = Color(0xFFF1F5F9); // slate-100
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _shadow = Color(0x1A0F172A); // 10% opacité

  final _formKey = GlobalKey<FormState>();

  final _fournCtrl = TextEditingController();
  final _libelleCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();

  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final d = widget.depense;
    if (d != null) {
      _fournCtrl.text = d.fournisseur;
      _libelleCtrl.text = d.libelle;
      _montantCtrl.text = d.montantTtc.toStringAsFixed(2);
      _numeroCtrl.text = d.numeroFacture ?? '';
      _date = d.date;
    }
  }

  @override
  void dispose() {
    _fournCtrl.dispose();
    _libelleCtrl.dispose();
    _montantCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  String _df(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final montant =
        double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? -1;
    if (montant < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      return;
    }

    final model = Depense(
      id: widget.depense?.id,
      date: _date,
      fournisseur: _fournCtrl.text.trim(),
      libelle: _libelleCtrl.text.trim(),
      montantTtc: montant,
      numeroFacture:
          _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
    );

    final prov = context.read<DepenseProvider>();
    if (model.id == null) {
      await prov.addDepense(model);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dépense ajoutée.')));
      }
      _formKey.currentState!.reset();
      setState(() => _date = DateTime.now());
      _fournCtrl.clear();
      _libelleCtrl.clear();
      _montantCtrl.clear();
      _numeroCtrl.clear();
    } else {
      await prov.updateDepense(model);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dépense mise à jour.')));
        Navigator.of(context).maybePop();
      }
    }
  }

  InputDecoration _decoration({required String label, IconData? icon}) {
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
    final isEdit = widget.depense != null;

    return Scaffold(
      backgroundColor: _bg,
      // appBar: AppBar(
      //   title: Text(isEdit ? 'Modifier une dépense' : 'Saisir une dépense'),
      //   elevation: 0,
      //   backgroundColor: Colors.white,
      //   foregroundColor: _ink,
      //   centerTitle: false,
      //   bottom: const PreferredSize(
      //     preferredSize: Size.fromHeight(1),
      //     child: Divider(height: 1, thickness: 1, color: _border),
      //   ),
      // ),
      body: SingleChildScrollView(
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
                    // (En-tête supprimé comme demandé)

                    // Fournisseur
                    TextFormField(
                      controller: _fournCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'Fournisseur *',
                        icon: Icons.store,
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 10),

                    // Libellé
                    TextFormField(
                      controller: _libelleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'Libellé *',
                        icon: Icons.description,
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 10),

                    // Montant TTC + N° facture
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _montantCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            decoration: _decoration(
                              label: 'Montant TTC *',
                              icon: Icons.euro,
                            ),
                            validator:
                                (v) =>
                                    (double.tryParse(
                                              (v ?? '').replaceAll(',', '.'),
                                            ) ==
                                            null)
                                        ? 'Nombre invalide'
                                        : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _numeroCtrl,
                            decoration: _decoration(
                              label: 'N° facture',
                              icon: Icons.receipt_long,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Date facture
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _decoration(
                          label: 'Date facture *',
                          icon: Icons.event,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                _df(_date),
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _pickDate,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _formKey.currentState?.reset();
                              _fournCtrl.clear();
                              _libelleCtrl.clear();
                              _montantCtrl.clear();
                              _numeroCtrl.clear();
                              setState(() => _date = DateTime.now());
                            },
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Réinitialiser'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black54,
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
