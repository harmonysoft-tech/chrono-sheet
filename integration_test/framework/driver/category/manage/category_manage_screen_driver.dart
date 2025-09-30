import 'dart:io';

import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../test_common/context/test_context.dart';

final _logger = getNamedLogger();

class ManageCategoryScreenDriver {

  final WidgetTester tester;

  ManageCategoryScreenDriver(this.tester);

  Future<void> setCategoryName(String name) async {
    _logger.info("setting active category name as '$name'");
    final nameField = find.byKey(AppWidgetKey.manageCategoryName);
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, name);
    await tester.pumpAndSettle();
  }

  Future<void> selectIcon(String iconFileName) async {
    final iconPath = "${TestContext.current.rootLocalDirPath}/$iconFileName";
    _logger.info("selecting category icon from path $iconPath");
    final iconFile = File(iconPath);
    if (!iconFile.existsSync()) {
      throw AssertionError("icon file with name '$iconFileName' does not exist at path: ${iconFile.path}");
    }

    final iconButton = find.byKey(AppWidgetKey.manageCategoryIcon);
    expect(iconButton, findsOneWidget);

    await tester.tap(iconButton);
    await tester.pumpAndSettle();
  }

  Future<void> saveChanges() async {
    _logger.info("saving category changes");
    final saveButton = find.byKey(AppWidgetKey.saveCategoryState);
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }
}