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
