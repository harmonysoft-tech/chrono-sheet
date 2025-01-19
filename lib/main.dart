import 'dart:async';

import 'package:chrono_sheet/di/di.dart';
import 'package:chrono_sheet/log/boostrap/log_bootstrap.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'generated/app_localizations.dart';
import 'log/util/log_util.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  setupLogging();
  final logger = getNamedLogger();

  runZonedGuarded(() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      var error = "flutter error - ${details.exception}";
      if (details.stack != null) {
        error += "\n";
        error += details.stack.toString();
      }
      logger.severe(error);
    };
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(
      child: MyApp(),
    ));
  }, (error, stackTrace) {
    logger.severe("unexpected exception - $error\n$stackTrace");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      diContainer = ProviderScope.containerOf(context);
    });
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
