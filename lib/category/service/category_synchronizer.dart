import 'package:chrono_sheet/category/service/impl/category_synchronizer_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../google/drive/service/google_drive_service.dart';
import '../model/category.dart';

part 'category_synchronizer.g.dart';

@Riverpod(keepAlive: true)
CategorySynchronizer categoryManager(Ref ref) {
  final googleDriveService = ref.watch(googleDriveServiceProvider);
  return CategorySynchronizerImpl(googleDriveService);
}

abstract interface class CategorySynchronizer {

  Future<Category?> getCategory(String categoryName);

  Future<void> synchronizeIfNecessary([bool force = false]);

  Future<void> onNewCategory(Category category);

  Future<void> onReplaceCategory(Category from, Category to);
}
