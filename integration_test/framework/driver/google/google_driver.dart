import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../category/integration_test_common.dart';

class GoogleDriver {

  final WidgetTester tester;

  GoogleDriver(this.tester);

  Future<void> createDataFileIfNecessary() async {
    final service = GoogleDriveService();
    final testContext = TestContext.current;
    final remoteDirId = await service.getOrCreateDirectory(testContext.rootGoogleDataDirPath);
    await service.getOrCreateFile(remoteDirId, testContext.testId, sheetMimeType, true);
  }

  Future<void> selectFile() async {
    await createDataFileIfNecessary();

    final fileWidget = find.byKey(AppWidgetKey.selectFile);
    expect(fileWidget, findsOneWidget);

    await tester.tap(fileWidget);
    await tester.pump();

    final filesFinder = find.byType(ListTile);
    final startTime = DateTime.now();
    bool selected = false;
    while (DateTime.now().difference(startTime) > const Duration(seconds: 10)) {
      final tiles = filesFinder.evaluate();
      if (tiles.isEmpty) {
        continue;
      }
      print(tiles);
      selected = true;
    }
    while (filesFinder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      if (DateTime.now().difference(startTime) > const Duration(seconds: 10)) {
        fail("cannot load a list of google sheet files");
      }
    }

    expect(filesFinder, findsWidgets);

    await tester.tap(filesFinder.first);
    await tester.pumpAndSettle();
  }

  static Future<void> cleanup() async {
    final service = GoogleDriveService();

    final rootTestDirId = await service.getOrCreateDirectory(TestPath.rootTestDir);

    final rootEntries = await service.list();
    for (final entry in rootEntries) {
      if (entry.name != TestPath.rootTestDir) {
        await service.delete(entry.id);
      }
    }

    final testDirEntries = await service.listFiles(rootTestDirId);
    for (final entry in testDirEntries) {
      await service.delete(entry.id);
    }
  }
}