import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/google/login/state/google_login_state.dart';
import 'package:chrono_sheet/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

import '../../test_common/google/service/google_service_test_common.dart';
import '../framework/driver/google/google_driver.dart';
import '../framework/path/test_path.dart';
import '../framework/driver/category/manage/category_manage_screen_driver.dart';
import '../framework/driver/main/main_screen_driver.dart';

int _contextCounter = 0;
String _testId = "test";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final categoryName = "category1";

  setUp(() async {
    _testId = Uuid().v4();
    final client = await getTestGoogleClient(++_contextCounter, TestAppPaths.rootDir);
    setDataOverride(CachedGoogleIdentity(id: "dummy-id", email: "dummy-email"), client);

    await GoogleDriver.createMeasurementsFile(_testId);
  });

  // TODO name accordingly
  testWidgets("xxx", (WidgetTester tester) async {
    final main = MainScreenDriver(tester);
    final google = GoogleDriver(tester);
    final manageCategory = ManageCategoryScreenDriver(tester);

    app.main();
    await tester.pumpAndSettle();

    await google.selectFile();

    await main.clickAddCategory();

    await manageCategory.setCategoryName(categoryName);
    await manageCategory.selectIcon("icon1.png");
    await manageCategory.saveChanges();

    // TODO remove
    while (true) {
      await Future.delayed(const Duration(milliseconds: 10000));
    }
  });
}