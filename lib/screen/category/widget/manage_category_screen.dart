import 'dart:io';

import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/category/service/category_icon_selector.dart';
import 'package:chrono_sheet/category/state/categories_state.dart';
import 'package:chrono_sheet/category/widget/category_widget.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../category/model/category.dart';
import '../../../generated/app_localizations.dart';
import '../../../ui/dimension.dart';
import '../../../util/snackbar_util.dart';

final _logger = getNamedLogger();

class ManageCategoryScreen extends ConsumerStatefulWidget {
  final Category? category;

  const ManageCategoryScreen({super.key, this.category});

  @override
  ConsumerState createState() => ManageCategoryScreenState();
}

class ManageCategoryScreenState extends ConsumerState<ManageCategoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  File? _iconFile;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      switch (category.representation) {
        case TextCategoryRepresentation():
          break;
        case ImageCategoryRepresentation(file: final f):
          _iconFile = f;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectIcon(BuildContext context) async {
    final category = _nameController.text.trim();
    final fileToStore = await selectCategoryIcon(context, category);
    if (fileToStore == null) {
      _logger.info("skipped icon selection for category '$category' - no file is selected");
      return;
    }

    if (context.mounted) {
      setState(() {
        _iconFile = fileToStore;
      });
    } else {
      _logger.info("skipped icon selection for category '$category' - the build context is not mounted");
    }
  }

  Future<void> _saveCategoryIfPossible(BuildContext context, CategoriesStateManager stateManager) async {
    if (_nameController.text.trim().isEmpty) {
      SnackBarUtil.showL10nMessage(context, _logger, (l10n) => l10n.errorCategoryNameMustBeProvided);
    }

    final l10n = AppLocalizations.of(context);
    final categoryName = _nameController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorCategoryNameMustBeProvided)));
      return;
    }

    final CategoryRepresentation representation;
    final file = _iconFile;
    if (file == null) {
      representation = TextCategoryRepresentation(categoryName);
    } else {
      representation = ImageCategoryRepresentation(file);
    }

    final Category newCategory = Category(
      name: categoryName,
      representation: representation,
      persistedInGoogle: widget.category?.persistedInGoogle ?? false,
    );
    final originalCategory = widget.category;
    final ManageCategoryResult saveResult;
    if (originalCategory == null) {
      saveResult = await stateManager.addNewCategory(newCategory);
    } else {
      saveResult = await stateManager.replaceCategory(originalCategory, newCategory);
    }
    if (context.mounted) {
      if (saveResult == ManageCategoryResult.success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveResult.getMessage(l10n))));
      }
    } else {
      _logger.info(
        "cannot handle category save attempt for category '$categoryName' "
        "($saveResult) - the build context is not mounted",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labelTheme = theme.textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(title: Text(widget.category == null ? l10n.titleCreateCategory : l10n.titleEditCategory)),
      body: Padding(
        padding: const EdgeInsets.all(AppDimension.screenPadding),
        child: Column(
          children: [
            Row(
              children: [
                Text(l10n.labelName, style: labelTheme),
                SizedBox(width: AppDimension.elementPadding),
                Expanded(
                  child: TextField(
                    key: AppWidgetKey.manageCategoryName,
                    focusNode: _nameFocusNode,
                    controller: _nameController,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimension.elementPadding),
            Row(
              children: [
                Text(l10n.labelIcon, style: labelTheme),
                SizedBox(width: AppDimension.elementPadding),
                _iconFile == null
                    ? IconButton(
                      key: AppWidgetKey.manageCategoryIcon,
                      onPressed: () {
                        _selectIcon(context);
                      },
                      icon: Container(
                        width: AppDimension.getCategoryWidgetEdgeLength(context),
                        height: AppDimension.getCategoryWidgetEdgeLength(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimension.borderCornerRadius),
                          border: Border.all(color: theme.disabledColor, width: 1),
                        ),
                        child: Icon(Icons.add),
                      ),
                    )
                    : CategoryWidget(
                      key: AppWidgetKey.manageCategoryIcon,
                      category: Category(
                        name: _nameController.text,
                        representation: ImageCategoryRepresentation(_iconFile!),
                        persistedInGoogle: widget.category?.persistedInGoogle ?? false,
                      ),
                      selected: false,
                      pressCallback: () {
                        _selectIcon(context);
                      },
                    ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: AppWidgetKey.saveCategoryState,
        onPressed: () => _saveCategoryIfPossible(context, ref.read(categoriesStateManagerProvider.notifier)),
        child: Icon(Icons.save),
      ),
    );
  }
}
