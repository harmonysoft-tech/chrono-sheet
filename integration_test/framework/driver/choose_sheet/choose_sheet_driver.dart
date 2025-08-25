import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../category/integration_test_common.dart';

class ChooseSheetScreenDriver {
  final WidgetTester tester;

  const ChooseSheetScreenDriver(this.tester);

  Future<void> selectTestSheet() async {
    final fileFinder = find.widgetWithText(ListTile, TestContext.current.testId);
    await UiVerificationUtil.waitForWidget(
      description: "a google sheet created for the current test",
      tester: tester,
      finder: fileFinder,
    );
    await tester.tap(fileFinder);
    await tester.pumpAndSettle();
  }
}
