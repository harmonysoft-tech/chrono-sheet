import 'package:chrono_sheet/category/widget/category_widget.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../category/integration_test_common.dart';

final _logger = getNamedLogger();

class MainScreenDriver {
  final WidgetTester tester;

  MainScreenDriver(this.tester);

  Future<void> clickSelectGoogleFile() async {
    _logger.info("clicking 'select google file' widget");
    final selectFileWidget = find.byKey(AppWidgetKey.selectFile);
    expect(selectFileWidget, findsOneWidget);

    await tester.tap(selectFileWidget);
    await tester.pumpAndSettle();
  }

  Future<void> clickAddCategory() async {
    _logger.info("clicking 'add category' widget");
    final createCategoryButton = find.byKey(AppWidgetKey.createCategory);
    expect(createCategoryButton, findsOneWidget);

    await tester.tap(createCategoryButton);
    await tester.pumpAndSettle();
  }

  Future<void> startCategoryEditing(String categoryName) async {
    _logger.info("start editing category '$categoryName'");
    final fileFinder = find.byWidgetPredicate(
      (widget) => widget is CategoryWidget && widget.category.name == categoryName,
    );

    // make sure that the category widget is available
    await UiVerificationUtil.waitForWidget(
      description: "a category widget",
      tester: tester,
      finder: fileFinder,
    );

    // open context menu
    await tester.longPress(fileFinder);
    await tester.pumpAndSettle();

    // click the 'edit' menu item
    await tester.tap(find.text("Edit"));
    await tester.pumpAndSettle();
  }
}
