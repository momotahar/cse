import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'authz_service.dart';

class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? fallback;
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthzService>();
    if (authz.can(feature)) return child;
    return fallback ?? const _LockedTile();
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Accès restreint'))),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 28),
            SizedBox(height: 6),
            Text('Accès restreint'),
          ],
        ),
      ),
    );
  }
}
