import 'dart:io';

import 'package:chrono_sheet/category/service/category_icon_selector.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../test_common/context/test_context.dart';

class ManageCategoryScreenDriver {

  final WidgetTester tester;

  ManageCategoryScreenDriver(this.tester);

  Future<void> setCategoryName(String name) async {
    final nameField = find.byKey(AppWidgetKey.manageCategoryName);
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, name);
    await tester.pumpAndSettle();
  }

  Future<void> selectIcon(String icon) async {
    final iconFile = File("${TestContext.current.rootLocalDirPath}/$icon");
    if (!iconFile.existsSync()) {
      throw AssertionError("icon file with name '$icon' does not exist at path: ${iconFile.path}");
    }
    selectCategoryIcon = (BuildContext context, String category) async {
      return iconFile;
    };

    final iconButton = find.byKey(AppWidgetKey.manageCategoryIcon);
    expect(iconButton, findsOneWidget);

    await tester.tap(iconButton);
    await tester.pumpAndSettle();
  }

  Future<void> saveChanges() async {
    final saveButton = find.byKey(AppWidgetKey.saveCategoryState);
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }
}