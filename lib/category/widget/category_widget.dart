import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/state/category_state.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryWidget extends ConsumerWidget {
  const CategoryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(fileStateManagerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
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
        ),
        SizedBox(height: AppDimension.labelVerticalInset),
        Text(
          l10n.labelCategory,
          style: TextStyle(fontSize: theme.textTheme.labelMedium?.fontSize),
        ),
      ],
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
          icon: Icon(
            Icons.add,
            key: AppWidgetKey.createCategory,
          ),
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
    final asyncCategories = ref.watch(categoryStateManagerProvider);
    final theme = Theme.of(context);
    final localization = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => _addCategory(context, ref.read(categoryStateManagerProvider.notifier)),
          icon: Icon(
            Icons.add,
            key: AppWidgetKey.createCategory,
          ),
        ),
        Expanded(
          child: Center(
            child: asyncCategories.when(
              data: (data) => Text(
                data.selected?.name ?? "",
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
                  key: AppWidgetKey.selectCategory,
                  icon: Icon(Icons.arrow_drop_down),
                  onSelected: (category) => ref.read(categoryStateManagerProvider.notifier).select(category),
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

void _addCategory(BuildContext context, CategoryStateManager categoriesNotifier) {
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
          child: Text(l10n.actionCancel),
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
            child: Text(l10n.actionAdd),
          ),
        ),
      ],
    ),
  );
}
