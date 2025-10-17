import 'package:cse_kch/views/incidents_form_screen.dart';
import 'package:cse_kch/views/incidents_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
// import 'incidents_form_screen.dart';
// import 'incidents_list_screen.dart';
import 'incidents_dashboard_screen.dart';

class IncidentsTabBar extends StatefulWidget {
  const IncidentsTabBar({super.key});

  @override
  State<IncidentsTabBar> createState() => _IncidentsTabBarState();
}

class _IncidentsTabBarState extends State<IncidentsTabBar>
    with SingleTickerProviderStateMixin {
  // Palette alignée sur PdfModelsScreen (sobre & pro)
  static const _brand = Color(0xFF0B5FFF); // bleu corporate
  static const _ink = Color(0xFF0F172A); // slate-900 (texte)
  static const _muted = Color(0xFF64748B); // slate-500
  static const _border = Color(0xFFE2E8F0); // slate-200
  static const _bg = Color(0xFFF1F5F9); // slate-100 (fond)

  @override
  void initState() {
    super.initState();
    // Chargement silencieux initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().loadIncidents(silent: true);
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
          title: const Text('Incidents'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          centerTitle: false,
          // TabBar en bas de l’AppBar + fine séparation
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Theme(
                  // Thème local = splash discret, typo un peu renforcée
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
                    indicator: UnderlineTabIndicator(
                      borderSide: const BorderSide(color: _brand, width: 3),
                      insets: const EdgeInsets.symmetric(horizontal: 24),
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
            IncidentsFormScreen(), // création / édition
            IncidentsListScreen(), // liste + actions
            IncidentsDashboardScreen(), // stats simples
          ],
        ),
      ),
    );
  }
}
