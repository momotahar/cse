// lib/views/depenses_tabbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/depense_provider.dart';
import 'depenses_form_screen.dart';
import 'depenses_list_screen.dart';
import 'depenses_dashboard_screen.dart';

class DepensesTabBar extends StatefulWidget {
  const DepensesTabBar({super.key});

  @override
  State<DepensesTabBar> createState() => _DepensesTabBarState();
}

class _DepensesTabBarState extends State<DepensesTabBar>
    with SingleTickerProviderStateMixin {
  // Accent de marque (facultatif)
  static const _brand = Color(0xFF0B5FFF);

  @override
  void initState() {
    super.initState();
    // Chargement initial silencieux (dataset global)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DepenseProvider>().setFilters(
        from: null,
        to: null,
        fournisseurLike: null,
        silent: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tabs = const [
      Tab(icon: Icon(Icons.edit_note), text: 'Saisie'),
      Tab(icon: Icon(Icons.list_alt), text: 'Liste'),
      Tab(icon: Icon(Icons.analytics_outlined), text: 'Tableau de bord'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // Laisse le thème gérer le fond
        appBar: AppBar(
          title: const Text('Dépenses'),
          elevation: 0,
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Splash/Highlight discrets, couleurs pilotées par le thème
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: TabBar(
                    tabs: tabs,
                    isScrollable: false,
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(color: cs.primary, width: 3),
                      insets: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    indicatorColor: cs.primary,
                  ),
                ),
                Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            DepensesFormScreen(), // création / édition
            DepensesListScreen(), // liste + actions
            DepensesDashboardScreen(), // KPI & heatmap fournisseur×mois
          ],
        ),
      ),
    );
  }
}
