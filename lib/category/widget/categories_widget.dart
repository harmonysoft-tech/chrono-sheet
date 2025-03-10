import 'package:chrono_sheet/category/state/category_state.dart';
import 'package:chrono_sheet/category/widget/category_widget.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/router.dart';

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
    return SizedBox.expand(
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            alignment: WrapAlignment.start,
            spacing: _calculateSpacing(context, constraints.maxWidth),
            runSpacing: AppDimension.elementPadding,
            children: asyncCategoryState.maybeWhen(
              data: (categoryState) => [
                IconButton(
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
                ...categoryState.selected == null
                    ? []
                    : [
                        CategoryWidget(
                          category: categoryState.selected!,
                          selected: true,
                          pressCallback: () {},
                        ),
                      ],
                ...categoryState.categories.map(
                  (category) => CategoryWidget(
                    category: category,
                    selected: false,
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
    );
  }
}

double _calculateSpacing(BuildContext context, double availableWidth) {
  final categoryWidgetWidth = AppDimension.getCategoryWidgetEdgeLength(context);
  final categoryWidgetsPerRow = (availableWidth / categoryWidgetWidth).toInt();
  final totalSpacingWidth = availableWidth - (categoryWidgetWidth * categoryWidgetsPerRow);
  return totalSpacingWidth / (categoryWidgetsPerRow - 1);
}