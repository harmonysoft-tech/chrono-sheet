import 'dart:async';

import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

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
    runApp(const ProviderScope(child: MyApp()));
  }, (error, stackTrace) {
    logger.severe("unexpected exception - $error\n$stackTrace");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo', // TODO implement i18n
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: MaterialApp.router(
          routerConfig: router,
      ),
    );
  }
}