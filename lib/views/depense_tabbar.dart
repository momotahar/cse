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
  // Palette alignée sur tes autres écrans (sobre & pro)
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _ink = Color(0xFF0F172A); // slate-900 (texte)
  static const _muted = Color(0xFF64748B); // slate-500
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _bg = Color(0xFFF1F5F9); // slate-100 (fond)

  @override
  void initState() {
    super.initState();
    // Chargement initial silencieux de la période "globale"
    // => réutilise setFilters(...) de ton provider Firebase
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
    final tabs = const [
      Tab(icon: Icon(Icons.edit_note), text: 'Saisie'),
      Tab(icon: Icon(Icons.list_alt), text: 'Liste'),
      Tab(icon: Icon(Icons.analytics_outlined), text: 'Tableau de bord'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Dépenses'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: TabBar(
                    tabs: tabs,
                    isScrollable: false,
                    labelColor: _brand,
                    unselectedLabelColor: _muted,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: _brand, width: 3),
                      insets: EdgeInsets.symmetric(horizontal: 24),
                    ),
                    indicatorColor: _brand,
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: _border),
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
