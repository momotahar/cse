// lib/authz/feature_gate.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'authz_service.dart';

class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;
  const FeatureGate({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthzService>();
    if (authz.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authz.can(feature)) return child;

    return Scaffold(
      appBar: AppBar(title: const Text('Accès restreint')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Vous n’avez pas l’autorisation pour cet écran.\nContactez un administrateur.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Utilisateur : ${authz.email ?? '-'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
