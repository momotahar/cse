// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_kch/providers/depot_provider.dart';
import 'package:cse_kch/providers/entretien_provider.dart';
import 'package:cse_kch/providers/parametres_provider.dart';
import 'package:cse_kch/providers/syndic_event_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import 'firebase_options.dart';

// Providers existants
import 'providers/theme_provider.dart';
import 'providers/vehicule_provider.dart';
import 'providers/billet_provider.dart';
import 'providers/filiale_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/depense_provider.dart';
import 'providers/commande_provider.dart';
import 'providers/reglement_provider.dart';
import 'providers/incident_provider.dart';
import 'providers/presence_provider.dart';

// Authz
import 'authz/authz_service.dart';
import 'authz/authorization_admin_screen.dart';

// UI
import 'views/home_screen.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Fenêtre desktop
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          setWindowTitle('CSE KCH');
          final info = await getWindowInfo();
          if (info.screen != null) {
            const width = 1350.0, height = 700.0;
            final screen = info.screen!.visibleFrame;
            setWindowFrame(
              Rect.fromLTWH(
                ((screen.width - width) / 2).roundToDouble(),
                ((screen.height - height) / 2).roundToDouble(),
                width,
                height,
              ),
            );
            setWindowMinSize(const Size(1200, 700));
          }
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Fenêtre (desktop) error: $e');
          debugPrint(st.toString());
        }
      }

      // Locale FR
      try {
        await initializeDateFormatting('fr_FR', null);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('initializeDateFormatting error: $e');
          debugPrint(st.toString());
        }
      }

      // Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (kDebugMode) {
          debugPrint(
            '✅ Firebase OK: ${DefaultFirebaseOptions.currentPlatform.projectId}',
          );
        }
      } on PlatformException catch (e, st) {
        debugPrint('❌ Firebase PlatformException: $e');
        debugPrint(st.toString());
        rethrow;
      } catch (e, st) {
        debugPrint('❌ Firebase init error: $e');
        debugPrint(st.toString());
        rethrow;
      }

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AuthzService()),

            // IMPORTANT : pas de chargements Firestore au démarrage
            ChangeNotifierProvider(create: (_) => VehiculeProvider()),
            ChangeNotifierProvider(create: (_) => BilletProvider()),
            ChangeNotifierProvider(create: (_) => FilialeProvider()),
            ChangeNotifierProvider(create: (_) => AgentProvider()),
            ChangeNotifierProvider(create: (_) => DepenseProvider()),
            ChangeNotifierProvider(create: (_) => CommandeProvider()),
            ChangeNotifierProvider(create: (_) => ReglementProvider()),
            ChangeNotifierProvider(create: (_) => IncidentProvider()),
            ChangeNotifierProvider(create: (_) => PresenceProvider()),
            ChangeNotifierProvider(create: (_) => DepotProvider()),
            ChangeNotifierProvider(create: (_) => SyndicEventProvider()),
            ChangeNotifierProvider(create: (_) => EntretienProvider()),
            ChangeNotifierProvider(create: (_) => ParametresProvider()),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('❌ Uncaught (zone): $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, theme, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr', 'FR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
          themeMode: theme.mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF0B5FFF),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF0B5FFF),
          ),
          home: const AuthBootstrapper(child: HomeScreen()),
          routes: {
            '/authorizationAdmin': (_) => const AuthorizationAdminScreen(),
          },
        );
      },
    );
  }
}

/// Lance le bootstrap après login (ne change pas ton HomeScreen)
class AuthBootstrapper extends StatefulWidget {
  final Widget child;
  const AuthBootstrapper({super.key, required this.child});
  @override
  State<AuthBootstrapper> createState() => _AuthBootstrapperState();
}

class _AuthBootstrapperState extends State<AuthBootstrapper> {
  String? _lastUid;
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    try {
      _sub = FirebaseAuth.instance.authStateChanges().listen(
        (u) async {
          if (u != null && u.uid != _lastUid) {
            _lastUid = u.uid;
            try {
              await context.read<AuthzService>().forceRefreshNow();
              if (kDebugMode) {
                debugPrint('[BOOTSTRAP] for ${u.email} (${u.uid})');
              }
            } catch (e, st) {
              debugPrint('[BOOTSTRAP][ERR] $e');
              debugPrint(st.toString());
            }
          }
        },
        onError: (e, st) {
          debugPrint('[AuthBootstrapper] authStateChanges error: $e');
          debugPrint(st.toString());
        },
      );
    } catch (e, st) {
      debugPrint('[AuthBootstrapper.initState] error: $e');
      debugPrint(st.toString());
    }
  }

  @override
  void dispose() {
    try {
      _sub?.cancel();
    } catch (e, st) {
      debugPrint('[AuthBootstrapper.dispose] error: $e');
      debugPrint(st.toString());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
