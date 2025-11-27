// lib/views/billets_tabbar.dart
// ignore_for_file: deprecated_member_use

import 'package:cse_kch/views/billet_screen.dart';
import 'package:cse_kch/views/commande_screen.dart';
import 'package:cse_kch/views/reglement_screen.dart';
import 'package:flutter/material.dart';
import 'billets_dashboard_screen.dart';

class BilletsTabBar extends StatelessWidget {
  const BilletsTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Commandes + Règlements + Tableau de bord + Catalogue
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Material(
                elevation: 2,
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
                  indicator: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  overlayColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.primary.withOpacity(.04),
                  ),
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.7),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.receipt_long, color: Color(0xFF4facfe)),
                      text: 'Commandes',
                    ),
                    Tab(
                      icon: Icon(Icons.payments, color: Color(0xFFf6a821)),
                      text: 'Règlements',
                    ),
                    Tab(
                      icon: Icon(Icons.insights, color: Color(0xFF00BFA6)),
                      text: 'Tableau de bord',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.local_activity,
                        color: Color(0xFFa18cd1),
                      ),
                      text: 'Catalogue',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: const [
                    CommandesScreen(),
                    ReglementsScreen(),
                    BilletsDashboardScreen(),
                    BilletsScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
