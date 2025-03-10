import 'dart:async';

import 'package:chrono_sheet/di/di.dart';
import 'package:chrono_sheet/log/boostrap/log_bootstrap.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/ui/path.dart';
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

class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppPaths.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      diContainer = ProviderScope.containerOf(context);
      Timer.periodic(Duration(minutes: 1), (_) {
        diContainer?.read(sheetUpdaterProvider.notifier).storeUnsavedMeasurements();
      });
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
