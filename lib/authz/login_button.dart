import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'authz_service.dart';
import 'change_password_dialog.dart';
import 'forgot_password_dialog.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authz = context.watch<AuthzService>();

    if (user == null) {
      return IconButton(
        tooltip: 'Se connecter',
        icon: const Icon(Icons.login),
        onPressed: () async {
          final creds = await showDialog<_Creds?>(
            context: context,
            builder: (_) => const _LoginDialog(),
          );
          if (creds == null) return;
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: creds.email.trim(),
              password: creds.password,
            );

            // crée/maj immédiatement /users/{uid} (en plus du bootstrap)
            try {
              await context.read<AuthzService>().forceRefreshNow();
            } catch (_) {}

            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Connecté.')));
            }
          } on FirebaseAuthException catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Login échoué: ${e.code}')));
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Login échoué: $e')));
          }
        },
      );
    } else {
      return PopupMenuButton<String>(
        tooltip: user.email ?? 'Compte',
        icon: const Icon(Icons.account_circle),
        onSelected: (v) async {
          if (v == 'changePwd') {
            showDialog(
              context: context,
              builder: (_) => const ChangePasswordDialog(),
            );
          } else if (v == 'sync') {
            try {
              await context.read<AuthzService>().forceRefreshNow();
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil synchronisé.')),
              );
            } catch (e) {
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Sync impossible: $e')));
            }
          } else if (v == 'logout') {
            await authz.signOut();
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Déconnecté.')));
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'email',
            enabled: false,
            child: Text(user.email ?? '(sans email)'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'changePwd',
            child: Text('Changer le mot de passe'),
          ),
          const PopupMenuItem(
            value: 'sync',
            child: Text('Synchroniser mon profil'),
          ),
          const PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
        ],
      );
    }
  }
}

class _Creds {
  final String email;
  final String password;
  _Creds(this.email, this.password);
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connexion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pwd,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            obscureText: _obscure,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // ferme le dialog de login
                showDialog(
                  context: context,
                  builder: (_) =>
                      ForgotPasswordDialog(prefillEmail: _email.text.trim()),
                );
              },
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<_Creds?>(context, null),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop<_Creds?>(context, _Creds(_email.text, _pwd.text));
          },
          child: const Text('Se connecter'),
        ),
      ],
    );
  }
}
