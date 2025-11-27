// lib/views/home_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cse_kch/views/depots_screen.dart';
import 'package:cse_kch/views/syndic_event_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cse_kch/authz/login_button.dart';
import 'package:cse_kch/authz/authz_service.dart';
import 'package:cse_kch/authz/feature_keys.dart';
import 'package:cse_kch/authz/feature_gate.dart'; // ← AJOUT

import 'package:cse_kch/views/billets_tabbar.dart';
import 'package:cse_kch/views/depense_tabbar.dart';
import 'package:cse_kch/views/incidents_tabbar.dart';
import 'package:cse_kch/views/list_agents.dart';
import 'package:cse_kch/views/list_filiales.dart';
import 'package:cse_kch/views/liste_vehicules_screen.dart';
import 'package:cse_kch/views/pdf_models_screen.dart';
import 'package:cse_kch/views/presence_list_screen.dart';
import 'package:cse_kch/views/presence_stats_screen.dart';

// ▼ Ajout : provider de thème
import 'package:cse_kch/providers/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authz = context.watch<AuthzService>();
    final themeProvider = context
        .watch<ThemeProvider>(); // ← lit l’état dark/light

    return Scaffold(
      appBar: AppBar(
        // ▼ Bouton Dark/Light en haut à gauche
        leading: IconButton(
          tooltip: themeProvider.isDark ? 'Mode clair' : 'Mode sombre',
          icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => context.read<ThemeProvider>().toggle(),
        ),
        title: const Text('Accueil'),
        elevation: 0,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: LoginButton()),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.1, 0.5, 1],
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceVariant.withOpacity(.5),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final width = constraints.maxWidth;

            final items = <_HomeItem>[
              _HomeItem(
                featureKey: FeatureKeys.billetterie,
                label: 'Billetterie',
                icon: Icons.confirmation_number,
                colors: const [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.billetterie,
                  const BilletsTabBar(),
                ),
              ),
              _HomeItem(
                featureKey: FeatureKeys.planningSyndical,
                label: 'Planning syndical',
                icon: Icons.event,
                colors: const [
                  Color.fromARGB(255, 25, 243, 105),
                  Color(0xFF8fd3f4),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.planningSyndical,
                  const SyndicEventList(),
                ),
              ),
              _HomeItem(
                featureKey: FeatureKeys.depotsAdmin,
                label: 'Dépôts',
                icon: Icons.add_location_alt,
                colors: const [
                  Color.fromARGB(255, 132, 210, 248),
                  Color.fromARGB(255, 0, 101, 155),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.depotsAdmin,
                  const DepotsScreen(),
                ),
              ),
              _HomeItem(
                featureKey: FeatureKeys.participations,
                label: 'Participations',
                icon: Icons.event_available,
                colors: const [
                  Color.fromARGB(255, 24, 150, 247),
                  Color(0xFF8fd3f4),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.participations,
                  PresenceListScreen(),
                ),
              ),

              _HomeItem(
                featureKey: FeatureKeys.statsParticipations,
                label: 'Stats Participations',
                icon: Icons.insights,
                colors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.statsParticipations,
                  PresenceStatsScreen(),
                ),
              ),

              _HomeItem(
                featureKey: FeatureKeys.agents,
                label: 'Agents',
                icon: Icons.groups_2,
                colors: const [
                  Color(0xFF00c6ff),
                  Color.fromARGB(255, 113, 172, 245),
                ],
                onTapAllowed: () =>
                    _safeGoGated(ctx, FeatureKeys.agents, const ListAgents()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.filiales,
                label: 'Filiales',
                icon: Icons.apartment,
                colors: const [
                  Color.fromARGB(255, 1, 141, 52),
                  Color(0xFF8fd3f4),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.filiales,
                  const FilialeListScreen(),
                ),
              ),
              _HomeItem(
                featureKey: FeatureKeys.modeles,
                label: 'Modèles',
                icon: Icons.description,
                colors: const [
                  Color.fromARGB(255, 182, 110, 1),
                  Color.fromARGB(255, 250, 226, 69),
                ],
                onTapAllowed: () =>
                    _safeGoGated(ctx, FeatureKeys.modeles, PdfModelsScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.vehicules,
                label: 'Véhicules',
                icon: Icons.directions_car,
                colors: const [
                  Color(0xFF00c6ff),
                  Color.fromARGB(255, 179, 248, 170),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.vehicules,
                  const ListVehiculesScreen(),
                ),
              ),
              // _HomeItem(
              //   featureKey: FeatureKeys.entretien,
              //   label: 'Entretien',
              //   icon: Icons.build,
              //   colors: const [Color(0xFF5ee7df), Color(0xFFb490ca)],
              //   onTapAllowed: () =>
              //       _safeGoGated(ctx, FeatureKeys.entretien, EntretienScreen()),
              // ),
              // _HomeItem(
              //   featureKey: FeatureKeys.kilometrage,
              //   label: 'Kilométrage',
              //   icon: Icons.speed,
              //   colors: const [
              //     Color(0xFFf093fb),
              //     Color.fromARGB(255, 130, 198, 253),
              //   ],
              //   onTapAllowed: () {
              //     final currentYear = DateTime.now().year;
              //     _safeGoGated(
              //       ctx,
              //       FeatureKeys.kilometrage,
              //       KilometrageScreen(initialAnnee: currentYear),
              //     );
              //   },
              // ),
              _HomeItem(
                featureKey: FeatureKeys.incidents,
                label: 'Incidents',
                icon: Icons.report_problem,
                colors: const [Color(0xFFf6d365), Color(0xFFfda085)],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.incidents,
                  const IncidentsTabBar(),
                ),
              ),
              _HomeItem(
                featureKey: FeatureKeys.comptabilite,
                label: 'Comptabilité',
                icon: Icons.groups,
                colors: const [
                  Color.fromARGB(255, 161, 167, 2),
                  Color.fromARGB(255, 219, 225, 46),
                ],
                onTapAllowed: () => _safeGoGated(
                  ctx,
                  FeatureKeys.comptabilite,
                  DepensesTabBar(),
                ),
              ),
            ];

            final canSeeAuthz =
                authz.isAdmin || authz.can(FeatureKeys.adminAuthz);
            items.add(
              canSeeAuthz
                  ? _HomeItem(
                      featureKey: FeatureKeys.adminAuthz,
                      label: 'Autorisation',
                      icon: Icons.admin_panel_settings_rounded,
                      colors: const [
                        Color.fromARGB(255, 99, 190, 247),
                        Color.fromARGB(255, 163, 176, 251),
                      ],
                      // On garde ta nav nommée existante
                      onTapAllowed: () =>
                          Navigator.pushNamed(ctx, '/authorizationAdmin'),
                    )
                  : _HomeItem.locked(
                      label: 'Autorisation',
                      icon: Icons.admin_panel_settings_rounded,
                      colors: const [
                        Color.fromARGB(255, 99, 190, 247),
                        Color.fromARGB(255, 163, 176, 251),
                      ],
                    ),
            );

            final cols = width >= 1200 ? 4 : (width >= 900 ? 3 : 2);
            const spacing = 14.0;
            final childAspectRatio = width < 600
                ? 2.0
                : (width < 1000 ? 2.2 : 2.4);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (_, i) =>
                        _GatedHomeActionButton(item: items[i]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<void> _safeGo(BuildContext ctx, Widget? screen) async {
    try {
      if (screen == null) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Écran non prêt.')));
        return;
      }
      await Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Navigation impossible: $e')));
    }
  }

  // ← AJOUT : helper qui wrappe l’écran dans un FeatureGate à la navigation
  static Future<void> _safeGoGated(
    BuildContext ctx,
    String featureKey,
    Widget screen,
  ) async {
    await _safeGo(ctx, FeatureGate(feature: featureKey, child: screen));
  }
}

class _HomeItem {
  final String? featureKey; // null => tuile verrouillée
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTapAllowed;

  _HomeItem({
    required this.featureKey,
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTapAllowed,
  });

  _HomeItem.locked({
    required this.label,
    required this.icon,
    required this.colors,
  }) : featureKey = null,
       onTapAllowed = null;
}

class _GatedHomeActionButton extends StatelessWidget {
  final _HomeItem item;
  const _GatedHomeActionButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthzService>();
    final allowed = item.featureKey == null
        ? false
        : authz.can(item.featureKey!);

    if (allowed && item.onTapAllowed != null) {
      return _HomeActionButton(
        icon: item.icon,
        label: item.label,
        colors: item.colors,
        onTap: item.onTapAllowed!,
        enabled: true,
      );
    }
    return _HomeActionButton(
      icon: item.icon,
      label: item.label,
      colors: item.colors.map((c) => c.withOpacity(.45)).toList(),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès restreint. Contactez l’administrateur.'),
          ),
        );
      },
      enabled: false,
    );
  }
}

class _HomeActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool enabled;

  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_HomeActionButton> createState() => _HomeActionButtonState();
}

class _HomeActionButtonState extends State<_HomeActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    final textColor = widget.enabled ? Colors.white : Colors.white70;
    final chevronColor = widget.enabled ? Colors.white : Colors.white38;

    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Material(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onTapDown: (_) {
            if (widget.enabled) setState(() => _pressed = true);
          },
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(.25),
                            width: 1,
                          ),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 22),
                      ),
                      if (!widget.enabled)
                        const Positioned(
                          right: -6,
                          top: -6,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.lock,
                              size: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: chevronColor, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
