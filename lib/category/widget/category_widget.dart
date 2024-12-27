import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/state/categories_state.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryWidget extends ConsumerStatefulWidget {

  const CategoryWidget({super.key});

  @override
  CategoryState createState() => CategoryState();
}

class CategoryState extends ConsumerState<CategoryWidget> {

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!_editing) {
      setState(() {
        _editing = true;
        FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  void _onCategorySelected(Category category) {
    if (_editing) {
      setState(() {
        _editing = false;
        _controller.text = '';
      });
    }
    ref.read(fileCategoriesProvider.notifier).setSelectedCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(filesInfoHolderProvider, (previous, next) {
      if (_editing && previous?.value?.selected != next.value?.selected) {
        setState(() {
          _editing = false;
          _controller.text = '';
        });
      }
    });
    final asyncInfo = ref.watch(fileCategoriesProvider);
    final theme = Theme.of(context);
    final localization = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: Dimension.historyIconButtonSize,
        right: Dimension.historyIconButtonSize,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide()
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _startEditing,
                child: _editing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    )
                  : asyncInfo.when(
                      data: (data) => Text(
                        data.selected?.name
                            ?? localization.hintTapToCreateCategory,
                        style: data.selected == null
                          ? TextStyle(color: theme.disabledColor)
                          : null,
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
              )
            ),
            asyncInfo.when(
              data: (data) => PopupMenuButton<Category>(
                icon: Icon(Icons.arrow_drop_down),
                onSelected: data.categories.isEmpty ? null : _onCategorySelected,
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
              loading: () =>  PopupMenuButton(
                icon: Icon(Icons.arrow_drop_down),
                itemBuilder: (context) => [],
              ),
            )
          ],
        ),
      ),
    );
  }
}