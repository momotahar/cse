// lib/views/presence_list_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cse_kch/views/presences_list_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

import 'package:cse_kch/constants/app_constants.dart';
import 'package:cse_kch/models/presence_model.dart';
import 'package:cse_kch/providers/presence_provider.dart';

import 'package:cse_kch/providers/agent_provider.dart';
import 'package:cse_kch/models/agent_model.dart';

import 'package:cse_kch/utils/build_picker_date.dart';
import 'package:cse_kch/utils/build_time_picker.dart';
import 'package:cse_kch/utils/build_textForm_deroulant_list.dart';

class PresenceListScreen extends StatefulWidget {
  const PresenceListScreen({super.key});

  @override
  State<PresenceListScreen> createState() => _PresenceListScreenState();
}

class _PresenceListScreenState extends State<PresenceListScreen> {
  String searchKeyword = '';
  DateTime? selectedDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    // Charge présences + agents au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.wait([
          context.read<PresenceProvider>().fetchPresences(),
          context.read<AgentProvider>().loadAgents(),
        ]);
      } catch (e, st) {
        debugPrint('init load error: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement données: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final presenceProv = context.watch<PresenceProvider>();
    final presences = presenceProv.presences;

    // Thème
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Filtre UI avec try/catch sur parsing date
    final filtered = <PresenceModel>[];
    try {
      for (final p in presences) {
        final kw = searchKeyword.trim().toLowerCase();
        final matchKw = kw.isEmpty || p.reunion.toLowerCase().contains(kw);
        bool matchDate = true;
        if (selectedDate != null) {
          try {
            final d = DateFormat('dd-MM-yyyy').parse(p.date);
            matchDate =
                d.year == selectedDate!.year &&
                d.month == selectedDate!.month &&
                d.day == selectedDate!.day;
          } catch (_) {
            matchDate = false;
          }
        }
        if (matchKw && matchDate) filtered.add(p);
      }
    } catch (e) {
      // Silencieux + garde-fou
      debugPrint('filter error: $e');
    }

    // Tri (date desc puis heure)
    try {
      filtered.sort((a, b) {
        try {
          final aDate = DateFormat('dd-MM-yyyy').parse(a.date);
          final bDate = DateFormat('dd-MM-yyyy').parse(b.date);
          if (aDate != bDate) return bDate.compareTo(aDate);
        } catch (_) {
          // si parsing échoue, on tombe sur le tri heure brut
        }
        return b.time.compareTo(a.time);
      });
    } catch (e) {
      debugPrint('sort error: $e');
    }

    // Groupement par date/heure/type
    Map<String, List<PresenceModel>> grouped;
    try {
      grouped = groupBy(
        filtered,
        (PresenceModel p) => '${p.date}_${p.time}_${p.reunion}',
      );
    } catch (e) {
      debugPrint('groupBy error: $e');
      grouped = {};
    }

    InputDecoration _searchDeco() => InputDecoration(
      hintText: 'Rechercher une réunion…',
      prefixIcon: const Icon(Icons.search),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      filled: true,
      fillColor: cs.surface,
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 1.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );

    BoxDecoration _cardBox() => BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: theme.brightness == Brightness.dark
              ? Colors.black.withOpacity(.30)
              : Colors.black.withOpacity(.08),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('Participations'),
            if (_exporting)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'Exporter en PDF',
                icon: Icon(Icons.picture_as_pdf, color: cs.primary),
                onPressed: () async {
                  try {
                    setState(() => _exporting = true);
                    await PresencesListPdfGenerator.generate(
                      context: context,
                      presencesFiltrees: filtered,
                    );
                  } catch (e) {
                    debugPrint('export error: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur export: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  try {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _DeclarePresenceDialog(),
                    );
                    if (ok == true) {
                      await context.read<PresenceProvider>().fetchPresences();
                    }
                  } catch (e) {
                    debugPrint('open add dialog error: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur ouverture: $e')),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary,
                  child: Icon(Icons.add, color: cs.onPrimary, size: 20),
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      // Laisse le thème gérer le fond
      body: Column(
        children: [
          // Barre de recherche + filtre date
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 6),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    onChanged: (v) {
                      try {
                        setState(() => searchKeyword = v);
                      } catch (e) {
                        debugPrint('search setState error: $e');
                      }
                    },
                    decoration: _searchDeco(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Choisir une date',
                  icon: Icon(Icons.date_range, color: cs.primary),
                  onPressed: () async {
                    try {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    } catch (e) {
                      debugPrint('date picker error: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur sélection date: $e')),
                      );
                    }
                  },
                ),
                if (selectedDate != null)
                  IconButton(
                    tooltip: 'Effacer le filtre date',
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      try {
                        setState(() => selectedDate = null);
                      } catch (e) {
                        debugPrint('clear date error: $e');
                      }
                    },
                  ),
              ],
            ),
          ),

          // Liste des groupes
          Expanded(
            child: grouped.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Aucune présence trouvée.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      try {
                        final entry = grouped.entries.elementAt(i);
                        final vals = entry.value;
                        final first = vals.first;
                        final date = first.date;
                        final time = first.time;
                        final reunion = first.reunion;
                        final hasLate = vals.any(
                          (p) => p.isLate && (p.lateMinutes > 0),
                        );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(15, 2, 15, 2),
                          child: Container(
                            decoration: _cardBox(),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // En-tête
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '📅 $date   🕒 $time   📌 $reunion'
                                          '${hasLate ? '   ⏱️ Retards' : ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                      // ✏️ MODIFIER
                                      IconButton(
                                        tooltip: 'Modifier cette réunion',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          try {
                                            final updated =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) =>
                                                      _DeclarePresenceDialog(
                                                        existingPresences: vals,
                                                      ),
                                                );
                                            if (updated == true) {
                                              await context
                                                  .read<PresenceProvider>()
                                                  .fetchPresences();
                                            }
                                          } catch (e) {
                                            debugPrint('edit dialog error: $e');
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Erreur modification: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      // 🗑️ SUPPRIMER
                                      IconButton(
                                        tooltip: 'Supprimer ce groupe',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          try {
                                            final confirm =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: const Text(
                                                      'Confirmer',
                                                    ),
                                                    content: const Text(
                                                      'Supprimer cette présence ?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'Annuler',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          'Supprimer',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ) ??
                                                false;

                                            if (!confirm) return;

                                            for (final e in vals) {
                                              if (e.id != null) {
                                                try {
                                                  await context
                                                      .read<PresenceProvider>()
                                                      .deletePresence(e.id!);
                                                } catch (delErr) {
                                                  debugPrint(
                                                    'delete item error: $delErr',
                                                  );
                                                }
                                              }
                                            }
                                          } catch (e) {
                                            debugPrint(
                                              'delete group error: $e',
                                            );
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Erreur suppression: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),

                                  // Participants
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      title: Text(
                                        'Participants',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2.0,
                                          ),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: vals.map((p) {
                                              final showLate =
                                                  p.isLate &&
                                                  (p.lateMinutes > 0);
                                              return Chip(
                                                backgroundColor: cs.surface,
                                                side: BorderSide(
                                                  color: cs.outlineVariant,
                                                ),
                                                label: Text.rich(
                                                  TextSpan(
                                                    text: p.agent,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: cs.onSurface,
                                                    ),
                                                    children: [
                                                      if (showLate)
                                                        TextSpan(
                                                          text:
                                                              ' (${p.lateMinutes} min)',
                                                          style: TextStyle(
                                                            color: cs.error,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } catch (e) {
                        debugPrint('list item build error: $e');
                        return const SizedBox.shrink();
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────
// Dialog d’ajout/modification AVEC retard par agent
class _DeclarePresenceDialog extends StatefulWidget {
  final List<PresenceModel>? existingPresences;

  const _DeclarePresenceDialog({this.existingPresences});

  bool get isEditing =>
      existingPresences != null && existingPresences!.isNotEmpty;

  @override
  State<_DeclarePresenceDialog> createState() => _DeclarePresenceDialogState();
}

class _DeclarePresenceDialogState extends State<_DeclarePresenceDialog> {
  final _formKey = GlobalKey<FormState>();

  final reunionCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final timeCtrl = TextEditingController();

  DateTime? selectedDate;
  bool _saving = false;

  final Set<String> _selectedAgents = {};
  final Map<String, bool> _agentIsLate = {};
  final Map<String, int> _agentLateMinutes = {};

  @override
  void initState() {
    super.initState();
    try {
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      dateCtrl.text = '${two(now.day)}-${two(now.month)}-${now.year}';
      timeCtrl.text = '${two(now.hour)}:${two(now.minute)}';
      selectedDate = now;

      if (widget.isEditing) {
        final first = widget.existingPresences!.first;
        dateCtrl.text = first.date;
        timeCtrl.text = first.time;
        reunionCtrl.text = first.reunion;

        for (final p in widget.existingPresences!) {
          _selectedAgents.add(p.agent);
          _agentIsLate[p.agent] = p.isLate;
          _agentLateMinutes[p.agent] = p.lateMinutes;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await context.read<AgentProvider>().loadAgents();
        } catch (e) {
          debugPrint('loadAgents in dialog error: $e');
        }
      });
    } catch (e) {
      debugPrint('dialog init error: $e');
    }
  }

  @override
  void dispose() {
    try {
      reunionCtrl.dispose();
      dateCtrl.dispose();
      timeCtrl.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _openParticipantsPicker(List<String> allAgents) async {
    final tempSelected = Set<String>.from(_selectedAgents);
    final tempIsLate = Map<String, bool>.from(_agentIsLate);
    final tempLateMin = Map<String, int>.from(_agentLateMinutes);
    final searchCtrl = TextEditingController();

    final cs = Theme.of(context).colorScheme;

    try {
      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setLocal) {
            try {
              final q = searchCtrl.text.trim().toLowerCase();
              final list = allAgents
                  .where((a) => q.isEmpty || a.toLowerCase().contains(q))
                  .toList();

              return AlertDialog(
                title: Text(
                  widget.isEditing
                      ? 'Modifier participants'
                      : 'Choisir les participants',
                ),
                content: SizedBox(
                  width: 560,
                  height: 520,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher…',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: cs.surface,
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          try {
                            setLocal(() {});
                          } catch (e) {
                            debugPrint('search setState picker error: $e');
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: .4,
                            color: cs.outlineVariant,
                          ),
                          itemBuilder: (_, i) {
                            try {
                              final name = list[i];
                              final selected = tempSelected.contains(name);
                              final late = tempIsLate[name] ?? false;
                              final minutes = tempLateMin[name] ?? 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: (v) {
                                        try {
                                          if (v == true) {
                                            tempSelected.add(name);
                                          } else {
                                            tempSelected.remove(name);
                                            tempIsLate.remove(name);
                                            tempLateMin.remove(name);
                                          }
                                          setLocal(() {});
                                        } catch (e) {
                                          debugPrint('toggle select error: $e');
                                        }
                                      },
                                    ),
                                    Expanded(child: Text(name)),
                                    Opacity(
                                      opacity: selected ? 1 : .4,
                                      child: Row(
                                        children: [
                                          const Text('Retard ?'),
                                          Checkbox(
                                            value: late,
                                            onChanged: selected
                                                ? (v) {
                                                    try {
                                                      tempIsLate[name] =
                                                          v ?? false;
                                                      if (v != true) {
                                                        tempLateMin[name] = 0;
                                                      }
                                                      setLocal(() {});
                                                    } catch (e) {
                                                      debugPrint(
                                                        'toggle late error: $e',
                                                      );
                                                    }
                                                  }
                                                : null,
                                          ),
                                          SizedBox(
                                            width: 70,
                                            child: TextField(
                                              enabled: selected && late,
                                              controller:
                                                  TextEditingController(
                                                      text: minutes.toString(),
                                                    )
                                                    ..selection =
                                                        TextSelection.collapsed(
                                                          offset: minutes
                                                              .toString()
                                                              .length,
                                                        ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: false,
                                                  ),
                                              onChanged: (s) {
                                                try {
                                                  tempLateMin[name] =
                                                      int.tryParse(s) ?? 0;
                                                } catch (e) {
                                                  debugPrint(
                                                    'late minutes parse error: $e',
                                                  );
                                                }
                                              },
                                              decoration: InputDecoration(
                                                isDense: true,
                                                labelText: 'min',
                                                filled: true,
                                                fillColor: cs.surface,
                                                border:
                                                    const OutlineInputBorder(),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            cs.outlineVariant,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: cs.primary,
                                                        width: 1.2,
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
                            } catch (e) {
                              debugPrint('picker row build error: $e');
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      try {
                        Navigator.pop(ctx);
                      } catch (_) {}
                    },
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      try {
                        _selectedAgents
                          ..clear()
                          ..addAll(tempSelected);
                        _agentIsLate
                          ..clear()
                          ..addAll({
                            for (final a in _selectedAgents)
                              a: tempIsLate[a] ?? false,
                          });
                        _agentLateMinutes
                          ..clear()
                          ..addAll({
                            for (final a in _selectedAgents)
                              a: (tempIsLate[a] ?? false)
                                  ? (tempLateMin[a] ?? 0)
                                  : 0,
                          });
                        Navigator.pop(ctx);
                        setState(() {});
                      } catch (e) {
                        debugPrint('picker validate error: $e');
                      }
                    },
                    child: const Text('Valider'),
                  ),
                ],
              );
            } catch (e) {
              debugPrint('picker build error: $e');
              return const SizedBox.shrink();
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('open picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection participants: $e')),
        );
      }
    } finally {
      try {
        searchCtrl.dispose();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    List<AgentModel> agentModels = const [];
    List<String> agentOptions = const [];
    bool hasAgents = false;

    try {
      agentModels = context.watch<AgentProvider>().agents;
      agentOptions =
          agentModels.map((a) => '${a.name} ${a.surname}'.trim()).toList()
            ..sort();
      hasAgents = agentOptions.isNotEmpty;
    } catch (e) {
      debugPrint('agents build error: $e');
    }

    return AlertDialog(
      title: Text(
        widget.isEditing ? 'Modifier la réunion' : 'Déclarer une présence',
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildDatePicker(
                context,
                dateCtrl,
                "Date",
                onSelected: (d) => selectedDate = d,
              ),
              const SizedBox(height: 8),
              buildTimePicker(
                context,
                timeCtrl,
                "Heure",
                borderColor: cs.outline,
              ),
              const SizedBox(height: 8),
              DeroulantTextFormField(
                controller: reunionCtrl,
                labelText: 'Réunion',
                options: AppConstants.typesReunion,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: hasAgents
                        ? () => _openParticipantsPicker(agentOptions)
                        : null,
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Choisir'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedAgents.isEmpty
                    ? Text(
                        'Aucun participant',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedAgents
                            .map(
                              (a) => Chip(
                                backgroundColor: cs.surface,
                                side: BorderSide(color: cs.outlineVariant),
                                label: Text(
                                  _agentIsLate[a] == true &&
                                          (_agentLateMinutes[a] ?? 0) > 0
                                      ? '$a (${_agentLateMinutes[a]} min)'
                                      : a,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onDeleted: () {
                                  try {
                                    setState(() {
                                      _selectedAgents.remove(a);
                                      _agentIsLate.remove(a);
                                      _agentLateMinutes.remove(a);
                                    });
                                  } catch (e) {
                                    debugPrint('chip delete error: $e');
                                  }
                                },
                              ),
                            )
                            .toList(),
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
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEditing ? 'Mettre à jour' : 'Enregistrer'),
          onPressed: (_saving || !hasAgents)
              ? null
              : () async {
                  if (dateCtrl.text.isEmpty || timeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Renseignez date et heure.'),
                      ),
                    );
                    return;
                  }
                  if (_selectedAgents.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sélectionnez au moins un participant.'),
                      ),
                    );
                    return;
                  }

                  setState(() => _saving = true);
                  try {
                    final provider = context.read<PresenceProvider>();

                    // ÉDITION : suppression des anciens puis réinsertion
                    if (widget.isEditing) {
                      for (final old in widget.existingPresences!) {
                        if (old.id != null) {
                          try {
                            await provider.deletePresence(old.id!);
                          } catch (delErr) {
                            debugPrint('delete during edit error: $delErr');
                          }
                        }
                      }
                    }

                    // Insertion des nouveaux enregistrements
                    for (final agent in _selectedAgents) {
                      final late = _agentIsLate[agent] ?? false;
                      final minutes = _agentLateMinutes[agent] ?? 0;

                      final p = PresenceModel(
                        agent: agent,
                        reunion: reunionCtrl.text.trim(),
                        date: dateCtrl.text.trim(),
                        time: timeCtrl.text.trim(),
                        isLate: late && minutes > 0,
                        lateMinutes: late ? minutes : 0,
                      );

                      try {
                        await provider.addPresence(p);
                      } catch (addErr) {
                        debugPrint('add presence error for $agent: $addErr');
                      }
                    }

                    if (mounted) Navigator.pop(context, true);
                  } catch (e) {
                    debugPrint('save dialog error: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
        ),
      ],
    );
  }
}
