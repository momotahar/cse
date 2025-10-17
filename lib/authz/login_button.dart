import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginButton extends StatefulWidget {
  const LoginButton({super.key});
  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  final _auth = FirebaseAuth.instance;
  bool _busy = false;

  // --- Traduction FR des erreurs Firebase Auth ---
  String _errFr(Object error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      switch (code) {
        case 'invalid-email':
          return 'Adresse e-mail invalide.';
        case 'user-disabled':
          return 'Ce compte est désactivé.';
        case 'user-not-found':
          return 'Aucun utilisateur trouvé pour cet e-mail.';
        case 'wrong-password':
          return 'Mot de passe incorrect.';
        case 'missing-password':
          return 'Mot de passe manquant.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessayez plus tard.';
        case 'network-request-failed':
          return 'Problème réseau. Vérifiez votre connexion.';
        case 'weak-password':
          return 'Mot de passe trop faible.';
        case 'email-already-in-use':
          return 'Cette adresse e-mail est déjà utilisée.';
        case 'operation-not-allowed':
          return 'Opération non autorisée pour ce projet.';
        case 'requires-recent-login':
          return 'Action sensible : reconnectez-vous et réessayez.';
        default:
          return 'Erreur (${error.code}). Réessayez.';
      }
    }
    return 'Erreur inattendue. Réessayez.';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user != null) {
      return TextButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await _auth.signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Déconnecté.')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: const Icon(Icons.logout),
        label: Text(_busy ? '...' : 'Déconnexion'),
      );
    }

    return TextButton.icon(
      onPressed: _busy ? null : () => _openLoginSheet(context),
      icon: const Icon(Icons.login),
      label: Text(_busy ? '...' : 'Connexion'),
    );
  }

  Future<void> _openLoginSheet(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Connexion',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    final email = emailCtrl.text.trim();
                                    try {
                                      // ignore: avoid_print
                                      print(
                                        '[DBG][AUTH] try_login email=$email',
                                      );
                                      await _auth.signInWithEmailAndPassword(
                                        email: email,
                                        password: passCtrl.text,
                                      );
                                      try {
                                        await _auth.currentUser?.getIdToken(
                                          true,
                                        );
                                        // ignore: avoid_print
                                        print('[DBG][AUTH] token_refreshed');
                                      } catch (e) {
                                        // ignore: avoid_print
                                        print(
                                          '[DBG][AUTH] token_refresh_error: $e',
                                        );
                                      }
                                      // ignore: avoid_print
                                      print(
                                        '[DBG][AUTH] login_ok email=$email',
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx, true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Connecté !'),
                                          ),
                                        );
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      // ignore: avoid_print
                                      print(
                                        '[DBG][AUTH] login_fail code=${e.code} msg=${e.message}',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(_errFr(e))),
                                        );
                                      }
                                    } catch (e) {
                                      // ignore: avoid_print
                                      print(
                                        '[DBG][AUTH] login_fail_unexpected: $e',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(_errFr(e))),
                                        );
                                      }
                                    } finally {
                                      if (mounted)
                                        setState(() => _busy = false);
                                    }
                                  },
                            icon: const Icon(Icons.login),
                            label: Text(_busy ? '...' : 'Se connecter'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                final email = emailCtrl.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Saisis ton email puis réessaye.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await _auth.sendPasswordResetEmail(
                                    email: email,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Lien de réinitialisation envoyé à $email',
                                        ),
                                      ),
                                    );
                                  }
                                } on FirebaseAuthException catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_errFr(e))),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_errFr(e))),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Mot de passe oublié'),
                      ),
                    ),

                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              final email = emailCtrl.text.trim();
                              try {
                                await _auth.createUserWithEmailAndPassword(
                                  email: email,
                                  password: passCtrl.text,
                                );
                                try {
                                  await _auth.currentUser?.getIdToken(true);
                                } catch (_) {}
                                if (ctx.mounted) Navigator.pop(ctx, true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Compte créé et connecté'),
                                    ),
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_errFr(e))),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_errFr(e))),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Créer un compte (optionnel)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }
}
