// lib/views/pdf_models_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_brases_in_flow_control_structures, deprecated_member_use, unused_element_parameter, unused_field

import 'package:cse_kch/views/pdf_blanks.dart';
import 'package:flutter/material.dart';

class PdfModelsScreen extends StatefulWidget {
  const PdfModelsScreen({super.key});

  @override
  State<PdfModelsScreen> createState() => _PdfModelsScreenState();
}

class _PdfModelsScreenState extends State<PdfModelsScreen> {
  // ====== Palette & styles pro ======
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _brandDark = Color(0xFF0A3FCF);
  static const _ink = Color(0xFF0F172A); // slate-900
  static const _muted = Color(0xFF64748B); // slate-500
  static const _cardBg = Color(0xFFF8FAFC); // slate-50
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _shadow = Color(0x1A0F172A); // 10% d’opacité

  Future<void> _runWithProgress(
    BuildContext context,
    Future<void> Function() job,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await job();
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _makeVehiculesVierge() async {
    await _runWithProgress(context, () async {
      final path = await PdfBlanks.saveVehiculesPdfVierge(
        baseLabel: null, // ou "Paris" si tu veux figer une base
        lignesVides: 20, // lignes blanches
        openAfterSave: true, // ouvrir après génération
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF généré : $path')));
    });
  }

  Future<void> _makeKilometrageVierge() async {
    final now = DateTime.now();
    final selYear = now.year;
    final selMonth = now.month;

    await _runWithProgress(context, () async {
      final path = await PdfBlanks.saveKilometragePdfViergeParMois(
        annee: selYear, // juste pour le nom du fichier
        mois: selMonth, // juste pour le nom du fichier
        basePourNom: null, // pas de base dans le nom
        lignesVides: 20, // <— 20 lignes fixes
        openAfterSave: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF généré : $path')));
    });
  }

  Future<void> _makeCommandesVierge() async {
    await _runWithProgress(context, () async {
      final path = await PdfBlanks.saveCommandesPdfVierge(
        // Tu laisses vide pour que les collègues remplissent à la main :
        periodeLabel: null,
        baseLabel: null,
        lignesVides: 20,
        openAfterSave: true,
        // format: PdfPageFormat.a4.landscape, // (par défaut déjà paysage)
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF généré : $path')));
    });
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label — bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_PdfItem>[
      _PdfItem(
        title: 'Véhicules',
        subtitle: 'Tableau vierge',
        icon: Icons.picture_as_pdf,
        onTap: _makeVehiculesVierge,
        accent: _brand,
      ),
      _PdfItem(
        title: 'Kilométrage',
        subtitle: 'Formulaire vierge',
        icon: Icons.picture_as_pdf,
        onTap: _makeKilometrageVierge, // ⬅️ appel ici
        accent: const Color(0xFF059669),
      ),
      _PdfItem(
        title: 'Commandes',
        subtitle: 'Tableau vierge',
        icon: Icons.picture_as_pdf,
        onTap: _makeCommandesVierge,
        accent: const Color(0xFFDB2777),
      ),
      _PdfItem(
        title: 'Incidents',
        subtitle: 'À venir',
        icon: Icons.picture_as_pdf,
        onTap: () => _comingSoon('Incidents'),
        accent: const Color(0xFF2563EB),
      ),
      _PdfItem(
        title: 'Dépenses',
        subtitle: 'À venir',
        icon: Icons.picture_as_pdf,
        onTap: () => _comingSoon('Dépenses'),
        accent: const Color(0xFF0EA5E9),
      ),

      _PdfItem(
        title: 'Règlements',
        subtitle: 'À venir',
        icon: Icons.picture_as_pdf,
        onTap: () => _comingSoon('Règlements'),
        accent: const Color(0xFFF59E0B),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modèles PDF'),
        elevation: 0,
        // foregroundColor: Colors.white,
        // flexibleSpace: Container(
        //   decoration: const BoxDecoration(
        //     gradient: LinearGradient(
        //       colors: [_brand, _brandDark],
        //       begin: Alignment.topLeft,
        //       end: Alignment.bottomRight,
        //     ),
        //   ),
        // ),
      ),
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      body: LayoutBuilder(
        builder: (context, constraints) {
          // grille responsive
          final w = constraints.maxWidth;
          int cross = 2;
          if (w >= 1200) {
            cross = 5;
          } else if (w >= 1000) {
            cross = 4;
          } else if (w >= 700) {
            cross = 3;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (_, i) => _PdfTilePro(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PdfItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  _PdfItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.accent,
  });
}

class _PdfTilePro extends StatefulWidget {
  const _PdfTilePro({required this.item, super.key});
  final _PdfItem item;

  @override
  State<_PdfTilePro> createState() => _PdfTileProState();
}

class _PdfTileProState extends State<_PdfTilePro> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const ink = _PdfModelsScreenState._ink;
    const muted = _PdfModelsScreenState._muted;
    const cardBg = _PdfModelsScreenState._cardBg;
    const border = _PdfModelsScreenState._border;
    const shadow = _PdfModelsScreenState._shadow;

    final isSoon = widget.item.subtitle.toLowerCase().contains('venir');

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.985 : 1,
      child: Material(
        color: cardBg,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.item.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          splashColor: widget.item.accent.withOpacity(.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(color: shadow, blurRadius: 10, offset: Offset(0, 6)),
              ],
              gradient: LinearGradient(
                colors: [Colors.white, widget.item.accent.withOpacity(0.03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône dans médaillon
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.item.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.item.accent.withOpacity(0.22),
                    ),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 28,
                    color: widget.item.accent,
                  ),
                ),
                const SizedBox(height: 14),
                // Titre
                Text(
                  widget.item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Sous-titre + badge état
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.item.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: isSoon ? 'Bientôt' : 'Prêt',
                      color: isSoon
                          ? const Color(0xFF64748B) // gris
                          : const Color(0xFF16A34A), // vert
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Lien subtil
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Générer',
                      style: TextStyle(
                        color: widget.item.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: widget.item.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          letterSpacing: .3,
        ),
      ),
    );
  }
}
