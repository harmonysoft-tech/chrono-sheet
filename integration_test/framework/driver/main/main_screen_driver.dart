import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter_test/flutter_test.dart';

class MainScreenDriver {

  final WidgetTester tester;

  MainScreenDriver(this.tester);

  Future<void> clickAddCategory() async {
    final createCategoryButton = find.byKey(AppWidgetKey.createCategory);
    expect(createCategoryButton, findsOneWidget);

    await tester.tap(createCategoryButton);
    await tester.pumpAndSettle();
  }
}