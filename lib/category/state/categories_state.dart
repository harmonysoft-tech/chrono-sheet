import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/sheet/model/sheet_column.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../file/model/google_file.dart';

part 'categories_state.g.dart';

class CategoriesInfo {
  final Category? selected;
  final List<Category> categories;

  CategoriesInfo(this.selected, [this.categories = const []]);
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
      return CategoriesInfo(null);
    }
    final categories = await _parseCategories(selectedFile);
    if (categories.isEmpty) {
      return CategoriesInfo(null);
    }

    final selectedCategoryName = await _prefs.getString(
        _getPreferencesKey(selectedFile)
    );
    if (selectedCategoryName == null) {
      return CategoriesInfo(categories.first, categories);
    }

    Category selected = Category(selectedCategoryName);
    if (categories.contains(selected)) {
      return CategoriesInfo(selected, categories);
    } else {
      return CategoriesInfo(categories.first, categories);
    }
  }

  Future<List<Category>> _parseCategories(GoogleFile file) async {
    state = AsyncValue.loading();
    final info = await parseSheetDocument(file);
    final categories = List.of(info.columns.keys).where((e) {
      return e != Column.date && e != Column.total;
    }).toList();
    categories.sort();
    return categories.map((e) => Category(e)).toList();
  }

  String _getPreferencesKey(GoogleFile file) {
    return "${_Key.selected}.${file.id}";
  }

  Future<void> setSelectedCategory(Category category) async {
    final current = await future;
    if (current.selected != category && current.categories.contains(category)) {
      state = AsyncValue.data(CategoriesInfo(category, current.categories));
    }
    final fileInfo = await ref.read(filesInfoHolderProvider.future);
    final file = fileInfo.selected;
    if (file != null) {
      _prefs.setString(_getPreferencesKey(file), category.name);
    }
  }
}