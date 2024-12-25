import 'package:chrono_sheet/AuthenticatedHttpClient.dart';
import 'package:chrono_sheet/measurement/widget/stop_watch_widget.dart';
import 'package:chrono_sheet/selected_file/widget/selected_file_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() async {
    final signIn = GoogleSignIn(scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      sheets.SheetsApi.driveReadonlyScope
    ]);
    try {
      var googleAccount = await signIn.signIn();
      if (googleAccount != null) {
        final headers = await googleAccount.authHeaders;
        final client = AuthenticatedHttpClient(headers);
        final driveApi = drive.DriveApi(client);
        final sheetDocuments = await driveApi.files.list(
            q: "mimeType='application/vnd.google-apps.spreadsheet'",
            spaces: 'drive',
            $fields: 'files(id, name)');
        sheetDocuments.files?.forEach((file) {
          print('found file ${file.name}');
        });
      }
    } catch (error) {
      print(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StopWatch(),
              SizedBox(height: 24),
              SelectedFileWidget(),
            ],
          )),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Do Google Action',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
