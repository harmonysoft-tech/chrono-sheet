import 'package:flutter_test/flutter_test.dart';

class TestPath {
  static final rootRemoteDirPath = "integration-test";
}

class TestIcon {
  static final icon1 = "icon1.png";
  static final icon2 = "icon2.png";
}

class TestCategory {
  static final category1 = "category1";
}

class UiVerificationUtil {
  static Future<void> waitForWidget({
    required String description,
    required WidgetTester tester,
    required Finder finder,
    Duration ttl = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    final endTime = DateTime.now().add(ttl);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(pollInterval);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    fail("can not find target widget - $description");
  }
}
