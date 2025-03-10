import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/category/state/category_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'category_state_test.mocks.dart';

Category _text(String name) {
  return Category(
    name: name,
    representation: TextCategoryRepresentation(name),
  );
}

Category _fullText(String name, String representation) {
  return Category(
    name: name,
    representation: TextCategoryRepresentation(representation),
  );
}

@GenerateMocks([SharedPreferencesAsync])
void main() {
  final manager = CategoryStateManager(prefs: MockSharedPreferencesAsync());

  test("when category has multiple words then default representation is as expected", () {
    final actual = manager.ensureNoDuplicateTextRepresentations([_text("category one"), _text("cat two")]);
    expect(actual, [_fullText("category one", "co"), _fullText("cat two", "ct")]);
  });

  test("when categories have different number of words then representation works as expected", () {
    final actual = manager.ensureNoDuplicateTextRepresentations([_text("a bb"), _text("a")]);
    expect(actual, [_fullText("a bb", "ab"), _fullText("a", "a")]);
  });

  test(
    "when there are categories with difference only at the end of the name then they are correctly differentiated",
    () {
      final actual = manager.ensureNoDuplicateTextRepresentations([_text("column1"), _text("column2")]);
      expect(actual, [_fullText("column1", "c1"), _fullText("column2", "c2")]);
    },
  );
}
