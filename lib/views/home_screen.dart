// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cse_kch/authz/login_button.dart';
import 'package:cse_kch/authz/authz_service.dart';
import 'package:cse_kch/authz/feature_keys.dart';

import 'package:cse_kch/views/billets_tabbar.dart';
import 'package:cse_kch/views/depense_tabbar.dart';
import 'package:cse_kch/views/entretien_screen.dart';
import 'package:cse_kch/views/incidents_tabbar.dart';
import 'package:cse_kch/views/kilometrage_screen.dart';
import 'package:cse_kch/views/list_agents.dart';
import 'package:cse_kch/views/list_filiales.dart';
import 'package:cse_kch/views/liste_vehicules_screen.dart';
import 'package:cse_kch/views/pdf_models_screen.dart';
import 'package:cse_kch/views/presence_list_screen.dart';
import 'package:cse_kch/views/presence_stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authz = context.watch<AuthzService>();

    return Scaffold(
      appBar: AppBar(
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
                onTapAllowed: () => _safeGo(ctx, const BilletsTabBar()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.vehicules,
                label: 'Véhicules',
                icon: Icons.directions_car,
                colors: const [Color(0xFF00c6ff), Color(0xFF0072ff)],
                onTapAllowed: () => _safeGo(ctx, const ListVehiculesScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.entretien,
                label: 'Entretien',
                icon: Icons.build,
                colors: const [Color(0xFF5ee7df), Color(0xFFb490ca)],
                onTapAllowed: () => _safeGo(ctx, EntretienScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.kilometrage,
                label: 'Kilométrage',
                icon: Icons.speed,
                colors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                onTapAllowed: () {
                  final currentYear = DateTime.now().year;
                  _safeGo(ctx, KilometrageScreen(initialAnnee: currentYear));
                },
              ),

              _HomeItem(
                featureKey: FeatureKeys.incidents,
                label: 'Incidents',
                icon: Icons.report_problem,
                colors: const [Color(0xFFf6d365), Color(0xFFfda085)],
                onTapAllowed: () => _safeGo(ctx, const IncidentsTabBar()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.comptabilite,
                label: 'Comptabilité',
                icon: Icons.groups,
                colors: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                onTapAllowed: () => _safeGo(ctx, DepensesTabBar()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.modeles,
                label: 'Modèles',
                icon: Icons.description,
                colors: const [Color(0xFF96fbc4), Color(0xFFf9f586)],
                onTapAllowed: () => _safeGo(ctx, PdfModelsScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.agents,
                label: 'Agents',
                icon: Icons.groups_2,
                colors: const [Color(0xFF00c6ff), Color(0xFF0072ff)],
                onTapAllowed: () => _safeGo(ctx, const ListAgents()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.filiales,
                label: 'Filiales',
                icon: Icons.apartment,
                colors: const [Color(0xFF84fab0), Color(0xFF8fd3f4)],
                onTapAllowed: () => _safeGo(ctx, const FilialeListScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.participations,
                label: 'Participations',
                icon: Icons.event_available,
                colors: const [
                  Color.fromARGB(255, 24, 150, 247),
                  Color(0xFF8fd3f4),
                ],
                onTapAllowed: () => _safeGo(ctx, PresenceListScreen()),
              ),
              _HomeItem(
                featureKey: FeatureKeys.statsParticipations,
                label: 'Stats Participations',
                icon: Icons.insights,
                colors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                onTapAllowed: () => _safeGo(ctx, PresenceStatsScreen()),
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
                        Color.fromARGB(255, 166, 249, 40),
                        Color.fromARGB(255, 223, 193, 204),
                      ],
                      onTapAllowed: () =>
                          Navigator.pushNamed(ctx, '/authorizationAdmin'),
                    )
                  : _HomeItem.locked(
                      label: 'Autorisation',
                      icon: Icons.admin_panel_settings_rounded,
                      colors: const [
                        Color.fromARGB(255, 166, 249, 40),
                        Color.fromARGB(255, 223, 193, 204),
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
