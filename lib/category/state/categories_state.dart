import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../file/model/google_file.dart';

part 'categories_state.g.dart';

final _categoriesToHideInUi = {Category(Column.date), Category(Column.total)};

class CategoriesInfo {

  static CategoriesInfo empty = CategoriesInfo();

  final Category? selected;
  final List<Category> categories;

  CategoriesInfo({
    this.selected,
    this.categories = const [],
  });
}

class _Key {
  static const selected = "category.selected";
}

@riverpod
class FileCategories extends _$FileCategories {

  final _prefs = SharedPreferencesAsync();

  @override
  Future<CategoriesInfo> build() async {
    final files = await ref.watch(filesInfoHolderProvider.future);
    final selectedFile = files.selected;
    if (selectedFile == null) {
      return CategoriesInfo.empty;
    }
    final categories = await _parseCategories(selectedFile);
    if (categories.isEmpty) {
      return CategoriesInfo.empty;
    }

    final selectedCategoryName = await _prefs.getString(
        _getPreferencesKey(selectedFile)
    );
    if (selectedCategoryName == null) {
      return CategoriesInfo(selected: categories.first, categories: categories);
    }

    Category selected = Category(selectedCategoryName);
    if (categories.contains(selected)) {
      return CategoriesInfo(selected: selected, categories: categories);
    } else {
      return CategoriesInfo(selected: categories.first, categories: categories);
    }
  }

  Future<List<Category>> _parseCategories(GoogleFile file) async {
    state = AsyncValue.loading();
    final info = await parseSheetDocument(file);
    final result = info.columns.keys.map((name) => Category(name))
        .where((c) => !_categoriesToHideInUi.contains(c))
        .toList();
    result.sort();
    return result;
  }

  String _getPreferencesKey(GoogleFile file) {
    return "${_Key.selected}.${file.id}";
  }

  Future<CategoriesInfo> select(Category category) async {
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
    CategoriesInfo newState = CategoriesInfo(selected: category, categories: categoriesToUse);
    state = AsyncValue.data(newState);
    final fileInfo = await ref.read(filesInfoHolderProvider.future);
    final file = fileInfo.selected;
    if (file != null) {
      await _prefs.setString(_getPreferencesKey(file), category.name);
    }
    return newState;
  }
}