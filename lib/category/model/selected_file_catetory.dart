import 'package:chrono_sheet/category/model/category.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_file_catetory.g.dart';

@riverpod
class FileCategories extends _$FileCategories {

  @override
  List<Category> build() {
    return [];
  }

  void setCategories(List<Category> categories) {
    List<Category> newState = List.from(categories);
    newState.sort();
    state = newState;
  }
}