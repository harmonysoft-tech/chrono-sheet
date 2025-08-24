import 'dart:convert';

import 'package:chrono_sheet/category/model/icon_info.dart';
import 'package:chrono_sheet/category/service/category_manager.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/google/login/state/google_login_state.dart';
import 'package:chrono_sheet/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis_auth/auth.dart';
import 'package:integration_test/integration_test.dart';

import '../../test_common/google/service/google_service_test_common.dart';
import '../framework/driver/category/manage/category_manage_screen_driver.dart';
import '../framework/driver/google/google_driver.dart';
import '../framework/driver/main/main_screen_driver.dart';
import '../framework/path/test_path.dart';
import 'integration_test_common.dart';

int _contextCounter = 0;
late AutoRefreshingAuthClient _googleClient;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestContext();
    _googleClient = await getTestGoogleClient(++_contextCounter, TestAppPaths.rootDir);
    setCategoryGoogleRootDirPathOverride(TestContext.current.rootGoogleDataDirPath);
    setDataOverride(CachedGoogleIdentity(id: "dummy-id", email: "dummy-email"), _googleClient);
  });

  tearDown(() async {
    // TODO uncomment
    // await GoogleDriver.cleanup();
  });

  // TODO name accordingly
  testWidgets("integration-test", (WidgetTester tester) async {
    final main = MainScreenDriver(tester);
    final google = GoogleDriver(tester);
    final manageCategory = ManageCategoryScreenDriver(tester);
    final gService = GoogleDriveService();

    app.main();
    await tester.pumpAndSettle();

    await google.selectFile();

    await main.clickAddCategory();

    await manageCategory.setCategoryName(TestCategory.category1);
    await manageCategory.selectIcon(TestIcon.icon1);
    await manageCategory.saveChanges();

    String categoryIconMetaFileRemoteId = await getGoogleFileId(
      "${CategoryGooglePaths.mappingDirPath}/${TestCategory.category1}.csv",
    );
    List<int> rawCategoryIconMetaFileContent = await gService.getFileContent(categoryIconMetaFileRemoteId);
    String categoryIconMetaFileContent = utf8.decode(rawCategoryIconMetaFileContent).trim();
    Either<String, IconInfo> iconInfoParseResult = IconInfo.parse(categoryIconMetaFileContent);
    IconInfo iconInfo = iconInfoParseResult.getOrElse((l) => fail(l));

    String iconFileRemotePath = "${CategoryGooglePaths.picturesDirPath}/${iconInfo.fileName}";
    String? iconFileRemoteId = await gService.getFileId(iconFileRemotePath);
    if (iconFileRemoteId == null) {
      fail("remote file is not found at path $iconFileRemotePath");
    }
  });
}
