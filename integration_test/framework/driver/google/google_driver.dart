import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class GoogleDriver {

  final WidgetTester tester;

  GoogleDriver(this.tester);

  static Future<GoogleFile> createMeasurementsFile(String testId) async {
    final service = GoogleDriveService();
    final rootDirectoryId = await service.getOrCreateDirectory("test/$testId");
    final fileId = await service.getOrCreateFile(rootDirectoryId, testId, sheetMimeType, true);
    return GoogleFile(fileId, testId);
  }

  Future<void> selectFile() async {
    final fileWidget = find.byKey(AppWidgetKey.selectFile);
    expect(fileWidget, findsOneWidget);

    await tester.tap(fileWidget);
    await tester.pump();

    final filesFinder = find.byType(ListTile);
    final startTime = DateTime.now();
    while (filesFinder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      if (DateTime.now().difference(startTime) > const Duration(seconds: 10)) {
        throw AssertionError("cannot load a list of google sheet files");
      }
    }

    expect(filesFinder, findsWidgets);

    await tester.tap(filesFinder.first);
    await tester.pumpAndSettle();
  }
}