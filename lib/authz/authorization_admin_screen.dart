// lib/authz/authorization_admin_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_kch/debug/vehicule_seed.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'authz_service.dart';
import 'feature_keys.dart';

class AuthorizationAdminScreen extends StatelessWidget {
  const AuthorizationAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthzService>();
    if (!authz.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Réservé aux administrateurs.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorisations'),
        actions: [
          IconButton(
            tooltip: 'Seed véhicules (une seule fois)',
            icon: const Icon(Icons.cloud_upload),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Importer les véhicules ?'),
                  content: const Text(
                    'Cette opération crée/actualise les véhicules à partir de la liste embarquée.\n'
                    'Tu peux la relancer sans risque (idempotent).',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Importer'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Import en cours…')));
              try {
                await seedVehiculesAdminAligned();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import terminé.')),
                );
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Erreur import: $e')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('email', descending: false)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun utilisateur.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final uid = d.id;
              final data = d.data();
              final email = data['email'] as String? ?? '(sans email)';
              final isAdmin = (data['role'] ?? 'user') == 'admin';
              final features = Set<String>.from(
                (data['features'] as List?)?.cast<String>() ?? [],
              );

              return ExpansionTile(
                title: Text(email),
                subtitle: Text(isAdmin ? 'admin' : 'user'),
                trailing: Switch(
                  value: isAdmin,
                  onChanged: (v) async {
                    await context.read<AuthzService>().setAdmin(uid, v);
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FeatureKeys.all.map((f) {
                        final selected = features.contains(f);
                        return FilterChip(
                          label: Text(f),
                          selected: selected,
                          onSelected: (v) async {
                            final next = Set<String>.from(features);
                            if (v) {
                              next.add(f);
                            } else {
                              next.remove(f);
                            }
                            await context.read<AuthzService>().setFeatures(
                              uid,
                              next,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
