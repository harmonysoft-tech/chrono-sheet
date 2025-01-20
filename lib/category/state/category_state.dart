import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../file/model/google_file.dart';

part 'category_state.g.dart';

final _categoriesToHideInUi = {Category(Column.date), Category(Column.total)};
final _logger = getNamedLogger();

class CategoryState {
  static CategoryState empty = CategoryState();

  final Category? selected;
  final List<Category> categories;

  CategoryState({
    this.selected,
    this.categories = const [],
  });

  @override
  String toString() {
    return 'CategoryState{selected: $selected, categories: $categories}';
  }
}

@riverpod
class CategoryStateManager extends _$CategoryStateManager {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<CategoryState> build() async {
    final fileState = await ref.watch(fileStateManagerProvider.future);
    final selectedFile = fileState.selected;
    if (selectedFile == null) {
      return CategoryState.empty;
    }
    final cached = await _getCachedCategoryState(selectedFile);
    if (cached != null) {
      _logger.info("found cached category state: $cached");
      state = AsyncValue.data(cached);
    }
    final categories = await _parseCategories(selectedFile);
    final newCategoryState = merge(cached, categories);
    await _cacheCategoryState(selectedFile, newCategoryState);
    return newCategoryState;
  }

  Future<CategoryState?> _getCachedCategoryState(GoogleFile file) async {
    List<Category> categories = [];
    for (int i = 0; ; i++) {
      final key = _getCategoryKey(file, i);
      final categoryName = await _prefs.getString(key);
      if (categoryName == null) {
        break;
      }
      categories.add(Category(categoryName));
    }
    _logger.info("found ${categories.length} categories for file ${file.id} (${file.name}): ${categories.join(", ")}");
    if (categories.isEmpty) {
      return null;
    }

    final selectedCategoryName = await _prefs.getString(_getSelectedCategoryKey(file));
    _logger.info("found selected category '$selectedCategoryName' for file ${file.id} (${file.name})");
    if (selectedCategoryName == null) {
      return CategoryState(categories: categories);
    }

    final selectedCategory = Category(selectedCategoryName);
    if (categories.contains(selectedCategory)) {
      return CategoryState(selected: selectedCategory, categories: categories);
    } else {
      return CategoryState(categories: categories);
    }
  }

  CategoryState merge(CategoryState? cached, List<Category> current) {
    _logger.info("merging cached categories state ($cached) and current categories (${current.join(", ")})");
    if (current.isEmpty) {
      return CategoryState.empty;
    }
    if (cached == null) {
      final selected = current.first;
      current.removeAt(0);
      return CategoryState(selected: selected, categories: current);
    }
    final List<Category> sortedCategories = List.of(cached.categories);
    sortedCategories.removeWhere((category) => !current.contains(category));
    final categoriesToAdd = current.where((category) => !sortedCategories.contains(category));
    sortedCategories.addAll(categoriesToAdd);

    Category? selected = cached.selected;
    if (selected == null || !sortedCategories.contains(selected)) {
      selected = sortedCategories.first;
    }
    sortedCategories.remove(selected);
    final result = CategoryState(selected: selected, categories: sortedCategories);
    _logger.info("categories after merge: $result");
    return result;
  }

  Future<void> _cacheCategoryState(GoogleFile file, CategoryState state) async {
    final selected = state.selected;
    if (selected == null) {
      await _prefs.remove(_getSelectedCategoryKey(file));
    } else {
      await _prefs.setString(_getSelectedCategoryKey(file), selected.name);
    }

    final categories = state.categories;
    for (int i = 0; i < categories.length; i++) {
      await _prefs.setString(_getCategoryKey(file, i), categories[i].name);
    }
    await _prefs.remove(_getCategoryKey(file, categories.length));
    _logger.info("cached categories state for file ${file.id} (${file.name}): $state");
  }

  Future<List<Category>> _parseCategories(GoogleFile file) async {
    final info = await parseSheetDocument(file);
    final result =
        info.columns.keys.map((name) => Category(name)).where((c) => !_categoriesToHideInUi.contains(c)).toList();
    result.sort();
    _logger.info("parsed ${result.length} categories from google sheet document '${file.name}': ${result.join(", ")}");
    return result;
  }

  String _getSelectedCategoryKey(GoogleFile file) {
    return "category.${file.id}.selected";
  }

  String _getCategoryKey(GoogleFile file, int index) {
    return "category.${file.id}.$index";
  }

  Future<CategoryState> select(Category category) async {
    _logger.info("got a request to select category '$category'");
    final current = await future;
    if (current.selected == category) {
      _logger.info("category '$category' is already selected");
      return current;
    }
    List<Category> categoriesToUse = List.of(current.categories);
    categoriesToUse.remove(category);
    final selected = current.selected;
    if (selected != null) {
      categoriesToUse.remove(selected);
      categoriesToUse.insert(0, selected);
    }
    CategoryState newState = CategoryState(selected: category, categories: categoriesToUse);
    state = AsyncValue.data(newState);
    final fileState = await ref.read(fileStateManagerProvider.future);
    final file = fileState.selected;
    if (file != null) {
      await _cacheCategoryState(file, newState);
    }
    _logger.info("categories state after '$category' is selected: $newState");
    return newState;
  }
}
