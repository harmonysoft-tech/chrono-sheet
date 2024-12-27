import 'package:chrono_sheet/category/state/selected_file_category.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategorySelector extends ConsumerWidget {

  const CategorySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(fileCategoriesProvider);
    return Center(
      child: categories.when(
        data: (data) => Text(data.toString()),
        error: (_, __) => Text('error'),
        loading: () => Text('loading')
      ),
    );
  }
}