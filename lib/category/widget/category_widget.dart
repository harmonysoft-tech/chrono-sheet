import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/router.dart';
import '../model/category.dart';

final _logger = getNamedLogger();

enum _Menu {
  edit,
}

class CategoryWidget extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback pressCallback;

  const CategoryWidget({
    super.key,
    required this.category,
    required this.selected,
    required this.pressCallback,
  });

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMenu<_Menu>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: _Menu.edit,
          child: Text(l10n.actionEdit),
        ),
      ],
    );
    switch (result) {
      case _Menu.edit:
        if (context.mounted) {
          context.push(AppRoute.manageCategory, extra: category);
        } else {
          _logger.info("skipped request to edit category '$category' because the context is unmount");
        }
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final edgeLength = AppDimension.getCategoryWidgetEdgeLength(context);
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPressStart: (details) {
        _showMenu(context, details.globalPosition);
      },
      child: IconButton(
        onPressed: pressCallback,
        icon: Container(
          width: edgeLength,
          height: edgeLength,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimension.borderCornerRadius),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.disabledColor,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: _buildRepresentation(category.representation, theme, selected),
        ),
      ),
    );
  }

  Widget _buildRepresentation(CategoryRepresentation representation, ThemeData theme, bool selected) {
    return switch (representation) {
      TextCategoryRepresentation(text: final t) => Text(
          t,
          style: selected
              ? theme.textTheme.displaySmall
              : theme.textTheme.displaySmall?.copyWith(color: theme.disabledColor),
        ),
      ImageCategoryRepresentation(file: final f) => Image.file(f),
    };
  }
}
