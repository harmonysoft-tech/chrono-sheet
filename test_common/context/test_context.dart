import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class TestContext {
  final String rootLocalDirPath = "/data/local/tmp";
  final String rootRemoteDirPath;
  final String testId;
  final ProviderContainer container = ProviderContainer();

  TestContext(this.rootRemoteDirPath, [String? testId]) : testId = testId ?? Uuid().v4() {
    current = this;
  }

  static late TestContext current;

  String get rootRemoteDataDirPath => "$rootRemoteDirPath/$testId";

  void dispose() {
    container.dispose();
  }
}