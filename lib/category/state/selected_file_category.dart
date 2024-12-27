import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/sheet/model/sheet_column.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../file/model/google_file.dart';

part 'selected_file_category.g.dart';

@riverpod
class FileCategories extends _$FileCategories {

  @override
  Future<List<Category>> build() async {
    final files = await ref.watch(filesInfoHolderProvider.future);
    final selected = files.selected;
    if (selected == null) {
      return [];
    }
    return await _parseCategories(selected);
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
}