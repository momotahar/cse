// lib/views/incidents_tabbar.dart
import 'package:cse_kch/views/incidents_form_screen.dart';
import 'package:cse_kch/views/incidents_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
import 'incidents_dashboard_screen.dart';

class IncidentsTabBar extends StatefulWidget {
  const IncidentsTabBar({super.key});

  @override
  State<IncidentsTabBar> createState() => _IncidentsTabBarState();
}

class _IncidentsTabBarState extends State<IncidentsTabBar>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().loadIncidents(silent: true);
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
        appBar: AppBar(
          title: const Text('Incidents'),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Style directement sur TabBar (compatible toutes versions)
                TabBar(
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
                ),
                Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            IncidentsFormScreen(),
            IncidentsListScreen(),
            IncidentsDashboardScreen(),
          ],
        ),
      ),
    );
  }
}
