import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/state/categories_state.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryWidget extends ConsumerWidget {
  const CategoryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(filesInfoHolderProvider);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(),
        ),
      ),
      child: asyncFiles.maybeWhen(
        data: (files) =>
            files.operationInProgress == FileOperation.creation ? FileCreationWidget() : NoFileCreationWidget(),
        orElse: () => NoFileCreationWidget(),
      ),
    );
  }
}

class FileCreationWidget extends StatelessWidget {
  const FileCreationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localization = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: null,
          icon: Icon(Icons.add),
        ),
        Expanded(
          child: Center(
            child: Text(
              localization.progressFileCreationInProgress,
              style: TextStyle(color: theme.disabledColor),
            ),
          ),
        ),
        DisabledPopupMenuButtonWidget(),
      ],
    );
  }
}

class NoFileCreationWidget extends ConsumerWidget {
  const NoFileCreationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(fileCategoriesProvider);
    final theme = Theme.of(context);
    final localization = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => _addCategory(context, ref.read(fileCategoriesProvider.notifier)),
          icon: Icon(Icons.add),
        ),
        Expanded(
          child: Center(
            child: asyncCategories.when(
              data: (data) => Text(
                data.selected?.name ?? localization.hintCreateCategory,
                style: data.selected == null ? TextStyle(color: theme.disabledColor) : null,
              ),
              error: (_, __) => Text(
                localization.errorCanNotParseCategories,
                style: TextStyle(color: theme.disabledColor),
              ),
              loading: () => Text(
                localization.progressParsingCategories,
                style: TextStyle(color: theme.disabledColor),
              ),
            ),
          ),
        ),
        asyncCategories.maybeWhen(
          data: (data) => data.categories.isEmpty
              ? DisabledPopupMenuButtonWidget()
              : PopupMenuButton<Category>(
                  icon: Icon(Icons.arrow_drop_down),
                  onSelected: (category) => ref.read(fileCategoriesProvider.notifier).select(category),
                  itemBuilder: (context) => data.categories.map((c) {
                    return PopupMenuItem(
                      value: c,
                      child: Text(c.name),
                    );
                  }).toList(),
                ),
          orElse: () => DisabledPopupMenuButtonWidget(),
        ),
      ],
    );
  }
}

class DisabledPopupMenuButtonWidget extends StatelessWidget {
  const DisabledPopupMenuButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.arrow_drop_down),
      itemBuilder: (context) => [],
    );
  }
}

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
