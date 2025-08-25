import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class TestPath {
  static final rootTestDir = "integration-test";
}

class TestIcon {
  static final icon1 = "icon1.png";
}

class TestCategory {
  static final category1 = "category1";
}

class TestContext {
  final String testId;

  TestContext([String? testId]) : testId = testId ?? Uuid().v4() {
    current = this;
  }

  static late TestContext current;

  String get rootGoogleDataDirPath => "${TestPath.rootTestDir}/$testId";
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
