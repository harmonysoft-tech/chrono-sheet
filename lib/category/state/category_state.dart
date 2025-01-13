import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../file/model/google_file.dart';

part 'category_state.g.dart';

final _categoriesToHideInUi = {Category(Column.date), Category(Column.total)};

class CategoryState {
  static CategoryState empty = CategoryState();

  final Category? selected;
  final List<Category> categories;

  CategoryState({
    this.selected,
    this.categories = const [],
  });
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

    final selectedCategoryName = await _prefs.getString(_getSelectedCategoryKey(file));
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
    if (current.isEmpty) {
      return CategoryState.empty;
    }
    if (cached == null) {
      return CategoryState(categories: current);
    }
    final List<Category> sortedCategories = List.of(cached.categories);
    sortedCategories.removeWhere((category) => !current.contains(category));
    final categoriesToAdd = current.where((category) => !sortedCategories.contains(category));
    sortedCategories.addAll(categoriesToAdd);

    Category? selected = cached.selected;
    if (selected == null || !sortedCategories.contains(selected)) {
      selected = sortedCategories.first;
    }
    return CategoryState(selected: selected, categories: sortedCategories);
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
  }

  Future<List<Category>> _parseCategories(GoogleFile file) async {
    final info = await parseSheetDocument(file);
    final result =
        info.columns.keys.map((name) => Category(name)).where((c) => !_categoriesToHideInUi.contains(c)).toList();
    result.sort();
    return result;
  }

  String _getSelectedCategoryKey(GoogleFile file) {
    return "category.${file.id}.selected";
  }

  String _getCategoryKey(GoogleFile file, int index) {
    return "category.${file.id}.$index";
  }

  Future<CategoryState> select(Category category) async {
    final current = await future;
    if (current.selected == category) {
      return current;
    }
    List<Category> categoriesToUse = current.categories;
    if (!current.categories.contains(category)) {
      final newCategories = [...current.categories, category];
      newCategories.sort();
      categoriesToUse = newCategories;
    }
    CategoryState newState = CategoryState(selected: category, categories: categoriesToUse);
    state = AsyncValue.data(newState);
    final fileState = await ref.read(fileStateManagerProvider.future);
    final file = fileState.selected;
    if (file != null) {
      await _cacheCategoryState(file, newState);
    }
    return newState;
  }
}
