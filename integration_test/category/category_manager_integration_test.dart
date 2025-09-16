import 'dart:convert';

import 'package:chrono_sheet/category/model/icon_info.dart';
import 'package:chrono_sheet/category/service/shared_category_data_manager.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/main.dart' as app;
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';

import '../../test_common/context/test_context.dart';
import '../../test_common/google/service/google_service_test_common.dart';
import '../framework/driver/category/manage/category_manage_screen_driver.dart';
import '../framework/driver/choose_sheet/choose_sheet_driver.dart';
import '../framework/driver/main/main_screen_driver.dart';
import 'integration_test_common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestContext(TestPath.rootRemoteDirPath);
    await GoogleTestUtil.setUp();
    setCategoryGoogleRootDirPathOverride(TestContext.current.rootRemoteDataDirPath);
  });

  tearDown(() async {
    resetCategoryRootDirPathOverride();
    await GoogleTestUtil.tearDown();
  });

  Future<void> createDataFileIfNecessary(GoogleDriveService gService) async {
    final testContext = TestContext.current;
    final remoteDirId = await gService.getOrCreateDirectory(testContext.rootRemoteDataDirPath);
    await gService.getOrCreateFile(remoteDirId, testContext.testId, sheetMimeType, true);
  }

  testWidgets("saving category icons in remote storage", (WidgetTester tester) async {
    final main = MainScreenDriver(tester);
    final chooseSheet = ChooseSheetScreenDriver(tester);
    final manageCategory = ManageCategoryScreenDriver(tester);
    final gService = GoogleDriveService();

    await createDataFileIfNecessary(gService);

    app.main();
    await tester.pumpAndSettle();

    await main.clickSelectGoogleFile();
    await chooseSheet.selectTestSheet();

    await main.clickAddCategory();

    await manageCategory.setCategoryName(TestCategory.category1);
    await manageCategory.selectIcon(TestIcon.icon1);
    await manageCategory.saveChanges();

    String categoryIconMetaFileRemoteId = await GoogleTestUtil.getGoogleFileId(
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
