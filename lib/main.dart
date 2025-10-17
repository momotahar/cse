// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:cse_kch/providers/agent_provider.dart';
import 'package:cse_kch/providers/billet_provider.dart';
import 'package:cse_kch/providers/commande_provider.dart';
import 'package:cse_kch/providers/depense_provider.dart';
import 'package:cse_kch/providers/entretien_provider.dart';
import 'package:cse_kch/providers/filiale_provider.dart';
import 'package:cse_kch/providers/incident_provider.dart';
import 'package:cse_kch/providers/kilometrage_provider.dart';
import 'package:cse_kch/providers/presence_provider.dart';
import 'package:cse_kch/providers/reglement_provider.dart';
import 'package:cse_kch/providers/vehicule_provider.dart';

import 'package:cse_kch/authz/authz_service.dart';
import 'package:cse_kch/authz/authorization_admin_screen.dart'; // ← ROUTE ADMIN

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'views/home_screen.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      // IMPORTANT: bindings dans la même zone que runApp
      WidgetsFlutterBinding.ensureInitialized();

      // (Optionnel) Rendre les erreurs de zone fatales en debug
      assert(() {
        // ignore: invalid_use_of_visible_for_testing_member
        BindingBase.debugZoneErrorsAreFatal = true;
        return true;
      }());

      // Erreurs Flutter
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };

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
        debugPrint('⚠️ Fenêtre: $e\n$st');
      }

      // Locale FR
      try {
        await initializeDateFormatting('fr_FR', null);
      } catch (e, st) {
        debugPrint('⚠️ Locale/date: $e\n$st');
      }

      // Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print(
          '[DBG][FIREBASE] projectId=${DefaultFirebaseOptions.currentPlatform.projectId} '
          'bundleId=${DefaultFirebaseOptions.currentPlatform.iosBundleId}',
        );

        debugPrint('✅ Firebase initialisé');
      } on PlatformException catch (e, st) {
        debugPrint('❌ Firebase PlatformException: $e\n$st');
        rethrow;
      } catch (e, st) {
        debugPrint('❌ Firebase init: $e\n$st');
        rethrow;
      }

      // App
      runApp(
        MultiProvider(
          providers: [
            // Authz en tout premier pour que Home puisse l'écouter
            ChangeNotifierProvider(create: (_) => AuthzService()),

            // Tes providers métier
            ChangeNotifierProvider(
              create: (_) => VehiculeProvider()..loadVehicules(),
            ),
            ChangeNotifierProvider(create: (_) => KilometrageProvider()),
            ChangeNotifierProvider(create: (_) => EntretienProvider()),
            ChangeNotifierProvider(create: (_) => BilletProvider()),
            ChangeNotifierProvider(create: (_) => FilialeProvider()),
            ChangeNotifierProvider(create: (_) => AgentProvider()),
            ChangeNotifierProvider(create: (_) => DepenseProvider()),
            ChangeNotifierProvider(
              create: (_) => CommandeProvider()..loadCommandes(),
            ),
            ChangeNotifierProvider(
              create: (_) => ReglementProvider()..loadReglements(),
            ),
            ChangeNotifierProvider(
              create: (_) => IncidentProvider()..loadIncidents(),
            ),
            ChangeNotifierProvider(create: (_) => PresenceProvider()),
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
    try {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        theme: ThemeData(useMaterial3: true),
        home: const HomeScreen(),

        // ← ROUTES nommées (inclut l’admin des autorisations)
        routes: {
          '/authorizationAdmin': (_) => const AuthorizationAdminScreen(),
        },
      );
    } catch (e, st) {
      debugPrint('❌ MyApp.build: $e\n$st');
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Erreur au démarrage de l’application')),
        ),
      );
    }
  }
}
