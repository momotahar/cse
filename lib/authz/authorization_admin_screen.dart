import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'authz_service.dart';
import 'feature_keys.dart';

class AuthorizationAdminScreen extends StatefulWidget {
  const AuthorizationAdminScreen({super.key});

  @override
  State<AuthorizationAdminScreen> createState() =>
      _AuthorizationAdminScreenState();
}

class _AuthorizationAdminScreenState extends State<AuthorizationAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _emailCtrl = TextEditingController();
  bool _busy = false;

  // --- Traduction FR des erreurs Firestore/Firebase ---
  String _errFr(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      switch (code) {
        case 'permission-denied':
          return 'Permission refusée.';
        case 'unauthenticated':
          return 'Authentification requise.';
        case 'not-found':
          return 'Document introuvable.';
        case 'already-exists':
          return 'Le document existe déjà.';
        case 'invalid-argument':
          return 'Paramètre invalide.';
        case 'failed-precondition':
          return 'Précondition non remplie.';
        case 'aborted':
          return 'Opération interrompue. Réessayez.';
        case 'out-of-range':
          return 'Valeur hors limite.';
        case 'unimplemented':
          return 'Fonction non disponible.';
        case 'internal':
          return 'Erreur interne du serveur.';
        case 'unavailable':
          return 'Service indisponible. Réessayez plus tard.';
        case 'deadline-exceeded':
          return 'Délai dépassé. Réessayez.';
        case 'cancelled':
          return 'Opération annulée.';
        case 'data-loss':
          return 'Perte de données détectée.';
        default:
          return 'Erreur (${error.code}). Réessayez.';
      }
    }
    return 'Erreur inattendue. Réessayez.';
  }

  Future<void> _ensureUserDoc(String email) async {
    final id = email.trim().toLowerCase();
    final ref = _db.collection('users').doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': id,
        'allowed_features': <String>[],
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthzService>();
    final theme = Theme.of(context);

    if (!(authz.isAdmin || authz.can(FeatureKeys.adminAuthz))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Autorisation'), centerTitle: false),
        body: const Center(child: Text('Accès refusé')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorisation — Admin'),
        centerTitle: false,
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            // Bandeau supérieur — champ email + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Champ email
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: InputDecoration(
                            labelText: 'Email utilisateur',
                            hintText: 'ex: user@exemple.com',
                            prefixIcon: const Icon(Icons.alternate_email),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton Ajouter / Ouvrir
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                final email = _emailCtrl.text.trim();
                                if (email.isEmpty) return;
                                setState(() => _busy = true);
                                try {
                                  await _ensureUserDoc(email);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Utilisateur prêt : $email',
                                        ),
                                      ),
                                    );
                                  }
                                } on FirebaseException catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(_busy ? '...' : 'Ajouter / Ouvrir'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Titre de section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Utilisateurs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Liste des utilisateurs
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('users')
                          .orderBy('email')
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_errFr(snap.error!)),
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('Aucun utilisateur.'),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => Divider(
                            color: theme.colorScheme.outlineVariant,
                            height: 16,
                          ),
                          itemBuilder: (ctx, i) {
                            final d = docs[i];
                            final email =
                                (d.data()['email'] as String?) ?? d.id;
                            final allowed =
                                (d.data()['allowed_features'] as List?)
                                    ?.cast<String>() ??
                                <String>[];

                            return _UserCard(
                              email: email,
                              allowed: allowed.toSet(),
                              onSave: (newSet) async {
                                try {
                                  await d.reference.update({
                                    'allowed_features': newSet.toList(),
                                  });
                                  if (authz.uid == email) {
                                    await authz.reloadProfile();
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Droits enregistrés.'),
                                      ),
                                    );
                                  }
                                } on FirebaseException catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                }
                              },
                              onDelete: () async {
                                try {
                                  await d.reference.delete();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Utilisateur supprimé.'),
                                      ),
                                    );
                                  }
                                } on FirebaseException catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(_errFr(e)),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
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
    );
  }
}

class _UserCard extends StatefulWidget {
  final String email;
  final Set<String> allowed;
  final Future<void> Function(Set<String>) onSave;
  final Future<void> Function() onDelete;

  const _UserCard({
    required this.email,
    required this.allowed,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late Set<String> _current;
  bool _saving = false;
  bool _adminLoading = true;
  bool _isAdmin = false;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _current = {...widget.allowed};
    _db
        .collection('admins')
        .doc(widget.email.toLowerCase())
        .get()
        .then((s) {
          if (mounted) {
            setState(() {
              _isAdmin = s.exists;
              _adminLoading = false;
            });
          }
        })
        .catchError((e) {
          if (mounted) setState(() => _adminLoading = false);
          // Feedback FR si la lecture admin échoue
          final msg = _errFr(e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
            );
          }
        });
  }

  // Accès à _errFr depuis ce State
  String _errFr(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      switch (code) {
        case 'permission-denied':
          return 'Permission refusée.';
        case 'unauthenticated':
          return 'Authentification requise.';
        case 'not-found':
          return 'Document introuvable.';
        case 'already-exists':
          return 'Le document existe déjà.';
        case 'invalid-argument':
          return 'Paramètre invalide.';
        case 'failed-precondition':
          return 'Précondition non remplie.';
        case 'aborted':
          return 'Opération interrompue. Réessayez.';
        case 'out-of-range':
          return 'Valeur hors limite.';
        case 'unimplemented':
          return 'Fonction non disponible.';
        case 'internal':
          return 'Erreur interne du serveur.';
        case 'unavailable':
          return 'Service indisponible. Réessayez plus tard.';
        case 'deadline-exceeded':
          return 'Délai dépassé. Réessayez.';
        case 'cancelled':
          return 'Opération annulée.';
        case 'data-loss':
          return 'Perte de données détectée.';
        default:
          return 'Erreur (${error.code}). Réessayez.';
      }
    }
    return 'Erreur inattendue. Réessayez.';
  }

  Future<void> _setAdmin(bool makeAdmin) async {
    final doc = _db.collection('admins').doc(widget.email.toLowerCase());
    setState(() => _adminLoading = true);
    try {
      if (makeAdmin) {
        await doc.set({'granted_at': FieldValue.serverTimestamp()});
      } else {
        await doc.delete();
      }
      if (mounted) setState(() => _isAdmin = makeAdmin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              makeAdmin ? 'Droits admin accordés.' : 'Droits admin retirés.',
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_errFr(e)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_errFr(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adminLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = FeatureKeys.all.toList()..sort();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : avatar + email + switch Admin
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (widget.email.isNotEmpty ? widget.email[0] : '?')
                        .toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Text('Admin', style: theme.textTheme.labelLarge),
                        const SizedBox(width: 8),
                        _adminLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: _isAdmin,
                                onChanged: (v) => _setAdmin(v),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 12),

            // Chips de fonctionnalités (visuel modernisé)
            Text(
              'Fonctionnalités',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in features)
                  ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    selected: _current.contains(f),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _current.add(f);
                        } else {
                          _current.remove(f);
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: _current.contains(f)
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                      fontWeight: _current.contains(f)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Actions (Enregistrer / Tout retirer / Supprimer)
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await widget.onSave(_current);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('Droits enregistrés.'),
                                ),
                              );
                            }
                          } on FirebaseException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(_errFr(e)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(_errFr(e)),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? '...' : 'Enregistrer'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _current = {}),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Tout retirer'),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Supprimer cet utilisateur',
                  onPressed: _saving
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Supprimer'),
                              content: Text('Supprimer ${widget.email} ?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await widget.onDelete();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(_errFr(e)),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
