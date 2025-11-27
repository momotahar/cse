// lib/views/depots_screen.dart
// Tableau 100% visible (pas de scroll horizontal) + clipping + wrap adresse

// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/depot.dart';
import '../providers/depot_provider.dart';

// ——— UI helpers ———
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class DepotsScreen extends StatefulWidget {
  const DepotsScreen({super.key});
  @override
  State<DepotsScreen> createState() => _DepotsScreenState();
}

class _DepotsScreenState extends State<DepotsScreen> {
  final _searchCtrl = TextEditingController();
  final _vScrollCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DepotProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Filtre
    final q = _searchCtrl.text.trim().toLowerCase();
    final rows = (q.isEmpty)
        ? prov.items
        : prov.items.where((d) {
            final s = [
              d.nom,
              d.adresse,
              d.ville ?? '',
              d.cp ?? '',
            ].join(' ').toLowerCase();
            return s.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépôts'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // ——— Barre filtres + actions ———
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black.withOpacity(.25)
                              : Colors.black.withOpacity(.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: _decField(
                              context,
                              label: 'Rechercher (nom, adresse, ville, CP)',
                              icon: Icons.search,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        _StatChip(
                          icon: Icons.location_city,
                          label: '${rows.length}',
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: () => _openForm(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: rows.isEmpty
                              ? null
                              : () => _exportDepotsPdf(rows),
                          icon: Icon(
                            Icons.picture_as_pdf,
                            color: cs.onPrimary,
                            size: 18,
                          ),
                          label: Text(
                            'PDF',
                            style: TextStyle(color: cs.onPrimary),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ——— Tableau (sans scroll horizontal) ———
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (rows.isEmpty) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Aucun dépôt trouvé.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );
                        }

                        // Largeur totale
                        final total = constraints.maxWidth;

                        // Marges internes du DataTable :
                        // horizontalMargin * 2 + columnSpacing * (cols - 1)
                        const cols = 5;
                        const horizontalMargin = 8.0;
                        const columnSpacing = 12.0;
                        final innerLoss =
                            horizontalMargin * 2 + columnSpacing * (cols - 1);

                        final usable = (total - innerLoss).clamp(300, total);

                        // Répartition sur la largeur utile
                        double nameW = (usable * .24).clamp(120, 260);
                        double addrW = (usable * .44).clamp(220, 520);
                        double cpW = (usable * .12).clamp(70, 120);
                        double villeW = (usable * .14).clamp(90, 160);
                        double actW = (usable * .06).clamp(80, 120);

                        // Ajuste si les min/max créent un dépassement
                        final sum = nameW + addrW + cpW + villeW + actW;
                        if (sum > usable) {
                          final overflow = sum - usable;
                          // retire d’abord à l’adresse, puis au nom
                          final cutAddr = overflow * .7;
                          final cutName = overflow * .3;
                          addrW = (addrW - cutAddr).clamp(180, addrW);
                          nameW = (nameW - cutName).clamp(110, nameW);
                        }

                        final dataCols = const [
                          DataColumn(label: Text('Nom')),
                          DataColumn(label: Text('Adresse')),
                          DataColumn(label: Text('CP')),
                          DataColumn(label: Text('Ville')),
                          DataColumn(label: Text('Actions')),
                        ];

                        final dataRows = rows.map((d) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: nameW,
                                  child: Text(
                                    d.nom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: addrW,
                                  child: Text(
                                    d.adresse,
                                    maxLines: 2, // ← wrap contrôlé
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true, // ← reste dans la cellule
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: cpW,
                                  child: Text(
                                    d.cp ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: villeW,
                                  child: Text(
                                    d.ville ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: actW,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Modifier',
                                        onPressed: () =>
                                            _openForm(context, existing: d),
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.green,
                                        ),
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 28,
                                              height: 28,
                                            ),
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        onPressed: () =>
                                            _confirmDelete(context, d),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 28,
                                              height: 28,
                                            ),
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList();

                        final table = DataTable(
                          headingRowHeight: 30,
                          // on autorise une 2e ligne pour adresse
                          dataRowMinHeight: 28,
                          dataRowMaxHeight:
                              44, // ← plus haut si adresse sur 2 lignes
                          columnSpacing: columnSpacing,
                          horizontalMargin: horizontalMargin,
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontSize: 12,
                          ),
                          headingRowColor: WidgetStateProperty.resolveWith(
                            (_) => cs.surface,
                          ),
                          columns: dataCols,
                          rows: dataRows,
                        );

                        final framedTable = Container(
                          width: double.infinity,
                          clipBehavior:
                              Clip.hardEdge, // ← clip tout débordement
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.black.withOpacity(.25)
                                    : Colors.black.withOpacity(.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: table,
                        );

                        // Scroll vertical uniquement
                        return Scrollbar(
                          thumbVisibility: true,
                          controller: _vScrollCtrl,
                          notificationPredicate: (n) =>
                              n.metrics.axis == Axis.vertical,
                          child: SingleChildScrollView(
                            controller: _vScrollCtrl,
                            child: framedTable,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ——— Dialog CRUD ———
  Future<void> _openForm(BuildContext context, {Depot? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nom = TextEditingController(text: existing?.nom ?? '');
    final adresse = TextEditingController(text: existing?.adresse ?? '');
    final ville = TextEditingController(text: existing?.ville ?? '');
    final cp = TextEditingController(text: existing?.cp ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Modifier le dépôt' : 'Nouveau dépôt'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 520,
            height: 240,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.6,
              children: [
                _field(context, 'Nom', nom, required: true),
                _field(context, 'Adresse', adresse, required: true),
                _field(context, 'Ville', ville),
                _field(context, 'Code postal', cp),
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

              final data = {
                'nom': _toTitleCaseFr(nom.text.trim()),
                'adresse': _toTitleCaseFr(adresse.text.trim()),
                'ville': ville.text.trim().isEmpty
                    ? null
                    : _toTitleCaseFr(ville.text.trim()),
                'cp': cp.text.trim().isEmpty ? null : cp.text.trim(),
              };

              try {
                final prov = context.read<DepotProvider>();
                if (isEdit) {
                  await prov.update(existing!.id, data);
                } else {
                  await prov.add(
                    data['nom'] as String,
                    data['adresse'] as String,
                    ville: data['ville'] as String?,
                    cp: data['cp'] as String?,
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Dépôt mis à jour' : 'Dépôt ajouté',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    nom.dispose();
    adresse.dispose();
    ville.dispose();
    cp.dispose();
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return SizedBox(
      width: 360,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 12),
        decoration: _decField(context, label: label),
        validator: !required
            ? null
            : (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Depot d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer “${d.nom}” ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<DepotProvider>().remove(d.id);
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
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ——— Export PDF ———
  Future<Uint8List> _buildDepotsPdfBytes(
    List<Depot> rows,
    PdfPageFormat format,
  ) async {
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );

    const kPdfHeaderBg = PdfColor.fromInt(0xFFEFF6FF);
    const kPdfOddRow = PdfColor.fromInt(0xFFF8FAFC);
    const kPdfTableLine = PdfColor.fromInt(0xFFE2E8F0);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Liste des dépôts',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                ),
                pw.Text(
                  'Généré le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(DateTime.now())}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: kPdfTableLine, width: 0.4),
              outside: const pw.BorderSide(color: kPdfTableLine, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6), // Nom
              1: pw.FlexColumnWidth(2.4), // Adresse
              2: pw.FlexColumnWidth(0.8), // CP
              3: pw.FlexColumnWidth(1.0), // Ville
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: kPdfHeaderBg),
                children: [
                  _PdfHeaderCell('Nom'),
                  _PdfHeaderCell('Adresse'),
                  _PdfHeaderCell('CP'),
                  _PdfHeaderCell('Ville'),
                ],
              ),
              ...List.generate(rows.length, (i) {
                final d = rows[i];
                final deco = (i % 2 == 1)
                    ? const pw.BoxDecoration(color: kPdfOddRow)
                    : const pw.BoxDecoration();
                return pw.TableRow(
                  decoration: deco,
                  children: [
                    _PdfBodyCell(d.nom),
                    _PdfBodyCell(d.adresse),
                    _PdfBodyCell(d.cp ?? ''),
                    _PdfBodyCell(d.ville ?? ''),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportDepotsPdf(List<Depot> rows) async {
    try {
      final bytes = await _buildDepotsPdfBytes(rows, PdfPageFormat.a4);
      final dir = await getTemporaryDirectory();
      final name =
          'depots_${DateTime.now().toIso8601String().split('T').first}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
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
}

// ——— Pastille stat ———
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ——— Widgets PDF ———
class _PdfHeaderCell extends pw.StatelessWidget {
  final String text;
  _PdfHeaderCell(this.text);
  @override
  pw.Widget build(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
  );
}

class _PdfBodyCell extends pw.StatelessWidget {
  final String text;
  _PdfBodyCell(this.text);
  @override
  pw.Widget build(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
  );
}

// ——— TitleCase français ———
String _toTitleCaseFr(String input) {
  if (input.isEmpty) return input;
  final buffer = StringBuffer();
  final regex = RegExp(r"([^\s\-\.'/]+|[\s\-\.'/]+)");
  for (final m in regex.allMatches(input.toLowerCase())) {
    final chunk = m.group(0)!;
    if (chunk.trim().isEmpty || RegExp(r"[\s\-\.'/]+").hasMatch(chunk)) {
      buffer.write(chunk);
    } else {
      final first = chunk.characters.first.toUpperCase();
      final rest = chunk.characters.skip(1).toString();
      buffer.write(first + rest);
    }
  }
  String out = buffer.toString();
  out = out.replaceAllMapped(
    RegExp(r"(?<=\S)\b(De|Du|Des|La|Le|Les|Et|À|Au|Aux)\b"),
    (m) => m.group(0)!.toLowerCase(),
  );
  out = out.replaceAllMapped(
    RegExp(r"(?<=\S)\b(D'|L')"),
    (m) => m.group(0)!.toLowerCase(),
  );
  return out;
}
