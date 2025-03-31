import 'package:chrono_sheet/category/state/category_state.dart';
import 'package:chrono_sheet/category/widget/category_widget.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../generated/app_localizations.dart';
import '../../router/router.dart';
import '../../ui/widget_key.dart';

class CategoriesWidget extends ConsumerWidget {
  const CategoriesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(fileStateManagerProvider);
    return asyncFiles.maybeWhen(
      data: (files) =>
          files.operationInProgress == FileOperation.creation ? FileCreationWidget() : NoFileCreationWidget(),
      orElse: () => NoFileCreationWidget(),
    );
  }
}

class FileCreationWidget extends StatelessWidget {
  const FileCreationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(),
    );
  }
}

class NoFileCreationWidget extends ConsumerWidget {
  const NoFileCreationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategoryState = ref.watch(categoryStateManagerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final activeCategoryName = asyncCategoryState.maybeWhen(
          data: (categoryState) => categoryState.selected?.name,
          orElse: () => null,
        ) ??
        l10n.textNoCategory;
    return Column(
      children: [
        Text(activeCategoryName, style: theme.textTheme.displayMedium),
        SizedBox(height: AppDimension.columnVerticalInset),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                alignment: WrapAlignment.start,
                spacing: _calculateSpacing(context, constraints.maxWidth),
                runSpacing: AppDimension.elementPadding,
                children: asyncCategoryState.maybeWhen(
                  data: (categoryState) => [
                    IconButton(
                      key: AppWidgetKey.createCategory,
                      onPressed: () {
                        context.push(AppRoute.manageCategory, extra: null);
                      },
                      icon: Container(
                        width: AppDimension.getCategoryWidgetEdgeLength(context),
                        height: AppDimension.getCategoryWidgetEdgeLength(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimension.borderCornerRadius),
                          border: Border.all(
                            color: theme.disabledColor,
                            width: 1,
                          ),
                        ),
                        child: Icon(Icons.add),
                      ),
                    ),
                    ...categoryState.categories.map(
                      (category) => CategoryWidget(
                        category: category,
                        selected: category == categoryState.selected,
                        pressCallback: () {
                          ref.read(categoryStateManagerProvider.notifier).select(category);
                        },
                      ),
                    )
                  ],
                  orElse: () => [
                    Center(
                      child: CircularProgressIndicator(),
                    )
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}

double _calculateSpacing(BuildContext context, double availableWidth) {
  final categoryWidgetWidth = AppDimension.getCategoryWidgetEdgeLength(context);
  final categoryWidgetsPerRow = (availableWidth / categoryWidgetWidth).toInt();
  final totalSpacingWidth = availableWidth - (categoryWidgetWidth * categoryWidgetsPerRow);
  return totalSpacingWidth / (categoryWidgetsPerRow - 1);
}
