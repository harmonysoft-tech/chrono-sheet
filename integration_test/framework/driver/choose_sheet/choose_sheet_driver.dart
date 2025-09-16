import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test_common/context/test_context.dart';
import '../../../category/integration_test_common.dart';

final _logger = getNamedLogger();

class ChooseSheetScreenDriver {
  final WidgetTester tester;

  const ChooseSheetScreenDriver(this.tester);

  Future<void> selectTestSheet() async {
    final sheetName = TestContext.current.testId;
    final fileFinder = find.widgetWithText(ListTile, sheetName);
    await UiVerificationUtil.waitForWidget(
      description: "a google sheet created for the current test",
      tester: tester,
      finder: fileFinder,
    );
    _logger.info("selected google sheet file '$sheetName'");

    await tester.tap(fileFinder);
    await tester.pumpAndSettle();
  }
}
