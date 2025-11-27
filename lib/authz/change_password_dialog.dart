import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  bool _ob1 = true, _ob2 = true, _obC = true;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  String? _validate(String p1, String p2) {
    if (p1 != p2) return 'Les mots de passe ne correspondent pas.';
    if (p1.length < 8) return '8 caractères minimum.';
    // Optionnel: ajoute tes règles (majuscule, chiffre, etc.)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Changer le mot de passe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            decoration: InputDecoration(
              labelText: 'Mot de passe actuel',
              suffixIcon: IconButton(
                icon: Icon(_obC ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obC = !_obC),
              ),
            ),
            obscureText: _obC,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _new1,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              suffixIcon: IconButton(
                icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ob1 = !_ob1),
              ),
            ),
            obscureText: _ob1,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _new2,
            decoration: InputDecoration(
              labelText: 'Confirmer le nouveau mot de passe',
              suffixIcon: IconButton(
                icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ob2 = !_ob2),
              ),
            ),
            obscureText: _ob2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || user.email == null) return;
                  final v = _validate(_new1.text, _new2.text);
                  if (v != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(v)));
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    // Réauth obligatoire
                    final cred = EmailAuthProvider.credential(
                      email: user.email!,
                      password: _current.text,
                    );
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(_new1.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mot de passe mis à jour.'),
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    final msg = switch (e.code) {
                      'wrong-password' => 'Mot de passe actuel incorrect.',
                      'weak-password' => 'Mot de passe trop faible.',
                      'requires-recent-login' =>
                        'Session trop ancienne. Déconnectez-vous puis reconnectez-vous.',
                      _ => 'Erreur: ${e.code}',
                    };
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Mettre à jour'),
        ),
      ],
    );
  }
}
