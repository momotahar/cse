import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String? prefillEmail;
  const ForgotPasswordDialog({super.key, this.prefillEmail});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _email.text = widget.prefillEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Réinitialiser le mot de passe'),
      content: TextField(
        controller: _email,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'prenom.nom@exemple.com',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _sending
              ? null
              : () async {
                  final email = _email.text.trim();
                  if (email.isEmpty) return;
                  setState(() => _sending = true);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Email envoyé à $email')),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: ${e.code}')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  } finally {
                    if (mounted) setState(() => _sending = false);
                  }
                },
          child: const Text('Envoyer le lien'),
        ),
      ],
    );
  }
}
