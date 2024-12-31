import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/state/categories_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryWidget extends ConsumerWidget {
  const CategoryWidget({super.key});

  void _addCategory(BuildContext context, FileCategories categoriesNotifier) {
    final controller = TextEditingController();
    final hasCategoryNameNotifier = ValueNotifier(false);
    controller.addListener(() => hasCategoryNameNotifier.value = controller.text.trim().isNotEmpty);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.titleAddNewCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.labelCategoryName,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.textCancel),
          ),
          ValueListenableBuilder(
            valueListenable: hasCategoryNameNotifier,
            builder: (context, enabled, child) => ElevatedButton(
              onPressed: enabled
                  ? () {
                      final categoryName = controller.text;
                      categoriesNotifier.select(Category(categoryName));
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Text(l10n.textAdd),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(fileCategoriesProvider);
    final theme = Theme.of(context);
    final localization = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _addCategory(context, ref.read(fileCategoriesProvider.notifier)),
            icon: Icon(Icons.add),
          ),
          Expanded(
            child: asyncInfo.when(
              data: (data) => Container(
                color: Colors.transparent,
                child: Center(
                  child: Text(
                    data.selected?.name ?? localization.hintTapToCreateCategory,
                    style: data.selected == null ? TextStyle(color: theme.disabledColor) : null,
                  ),
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  localization.errorCanNotParseCategories,
                  style: TextStyle(color: theme.disabledColor),
                ),
              ),
              loading: () => Center(
                child: Text(
                  localization.progressParsingCategories,
                  style: TextStyle(color: theme.disabledColor),
                ),
              ),
            ),
          ),
          asyncInfo.when(
            data: (data) => PopupMenuButton<Category>(
              icon: Icon(Icons.arrow_drop_down),
              onSelected: (category) => ref.read(fileCategoriesProvider.notifier).select(category),
              itemBuilder: (context) => data.categories.map((c) {
                return PopupMenuItem(
                  value: c,
                  child: Text(c.name),
                );
              }).toList(),
            ),
            error: (_, __) => PopupMenuButton(
              icon: Icon(Icons.arrow_drop_down),
              itemBuilder: (context) => [],
            ),
            loading: () => PopupMenuButton(
              icon: Icon(Icons.arrow_drop_down),
              itemBuilder: (context) => [],
            ),
          ),
        ],
      ),
    );
  }
}
