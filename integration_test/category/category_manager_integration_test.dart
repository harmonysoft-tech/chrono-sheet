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

  Future<void> createRemoteDataFileIfNecessary(GoogleDriveService gService) async {
    final testContext = TestContext.current;
    final remoteDirId = await gService.getOrCreateDirectory(testContext.rootRemoteDataDirPath);
    await gService.getOrCreateFile(remoteDirId, testContext.testId, sheetMimeType, true);
  }

  Future<_IntegrationTestContext> prepare(WidgetTester tester) async {
    final context = _IntegrationTestContext(tester);
    await createRemoteDataFileIfNecessary(context.gService);

    app.main();
    await tester.pumpAndSettle();

    await context.screen.main.clickSelectGoogleFile();
    await context.screen.chooseSheet.selectTestSheet();
    return context;
  }

  Future<void> addCategory({required _IntegrationTestContext context, required String name, String? iconFileName}) async {
    await context.screen.main.clickAddCategory();

    await context.screen.manageCategory.setCategoryName(TestCategory.category1);
    if (iconFileName != null) {
      await context.screen.manageCategory.selectIcon(TestIcon.icon1);
    }
    await context.screen.manageCategory.saveChanges();
  }

  Future<void> editCategory({
    required _IntegrationTestContext context,
    required String initialCategoryName,
    String? newCategoryName,
    String? iconFileName,
  }) async {
    if (newCategoryName == null && iconFileName == null) {
      throw AssertionError("can not edit category '$initialCategoryName', new category name or icon must be provided");
    }

    await context.screen.main.startCategoryEditing(initialCategoryName);

    if (newCategoryName != null) {
      await context.screen.manageCategory.setCategoryName(TestCategory.category1);
    }

    if (iconFileName != null) {
      await context.screen.manageCategory.selectIcon(TestIcon.icon1);
    }
    await context.screen.manageCategory.saveChanges();
  }

  Future<void> ensureRemoteCategoryIconFileExists(_IntegrationTestContext context, String category) async {
    String categoryIconMetaFileRemoteId = await GoogleTestUtil.getGoogleFileId(
      "${CategoryGooglePaths.metaInfoDirPath}/$category.csv",
    );
    List<int> rawCategoryIconMetaFileContent = await context.gService.getFileContent(categoryIconMetaFileRemoteId);
    String categoryIconMetaFileContent = utf8.decode(rawCategoryIconMetaFileContent).trim();
    Either<String, IconInfo> iconInfoParseResult = IconInfo.parse(categoryIconMetaFileContent);
    IconInfo iconInfo = iconInfoParseResult.getOrElse((l) => fail(l));

    String iconFileRemotePath = "${CategoryGooglePaths.picturesDirPath}/${iconInfo.fileName}";
    String? iconFileRemoteId = await context.gService.getFileId(iconFileRemotePath);
    if (iconFileRemoteId == null) {
      fail("remote file is not found at path $iconFileRemotePath");
    }
  }

  testWidgets("new category with icon", (WidgetTester tester) async {
    final context = await prepare(tester);

    await addCategory(context: context, name: TestCategory.category1, iconFileName: TestIcon.icon1);

    await ensureRemoteCategoryIconFileExists(context, TestCategory.category1);
  });

  testWidgets("set icon to existing category without icon", (WidgetTester tester) async {
    final context = await prepare(tester);

    await addCategory(context: context, name: TestCategory.category1);
    await editCategory(context: context, initialCategoryName: TestCategory.category1, iconFileName: TestIcon.icon1);

    await ensureRemoteCategoryIconFileExists(context, TestCategory.category1);
  });
}

class _IntegrationTestContext {
  final _Screens screen;
  final GoogleDriveService gService;

  _IntegrationTestContext(WidgetTester tester) : screen = _Screens(tester), gService = GoogleDriveService();
}

class _Screens {
  final MainScreenDriver main;
  final ChooseSheetScreenDriver chooseSheet;
  final ManageCategoryScreenDriver manageCategory;

  _Screens(WidgetTester tester)
    : main = MainScreenDriver(tester),
      chooseSheet = ChooseSheetScreenDriver(tester),
      manageCategory = ManageCategoryScreenDriver(tester);
}
