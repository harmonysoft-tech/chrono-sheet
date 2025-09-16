import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter_test/flutter_test.dart';

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
}