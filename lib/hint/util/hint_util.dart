import 'dart:math';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/hint/model/hint_model.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/material.dart';

final _logger = getNamedLogger();

HintBounds? calculateHintBounds({
  required GlobalKey anchorKey,
  required GlobalKey canvasKey,
  required HintLocation location,
}) {
  final anchorScreenRect = _calculateScreenPosition(anchorKey);
  if (anchorScreenRect == null) {
    return null;
  }
  final canvasScreenRect = _calculateScreenPosition(canvasKey);
  if (canvasScreenRect == null) {
    return null;
  }

  final context = canvasKey.currentContext;
  if (context == null) {
    _logger.fine("can not calculate hint bounds for '$anchorKey' - build context is undefined");
    return null;
  }
  final screenSize = MediaQuery.of(context).size;
  final style = Theme.of(context).textTheme.bodyMedium;
  if (style == null) {
    _logger.fine("can not calculate hint bounds for '$anchorKey' - text style is undefined");
    return null;
  }
  final l10n = AppLocalizations.of(context);
  final text = key2hintText[anchorKey]?.call(l10n);
  if (text == null) {
    _logger.fine("can not calculate hint bounds for '$anchorKey' - hint text is undefined");
    return null;
  }
  final hintTextSize =
      getTextSize(text, style, screenSize.width / 2) + Offset(AppDimension.hintInsets * 2, AppDimension.hintInsets * 2);
  final hintX = _calculateHintX(screenSize, hintTextSize, anchorScreenRect);
  final hintY = _calculateHintY(hintTextSize, anchorScreenRect, location);

  final offset = Offset(canvasScreenRect.left, canvasScreenRect.top);
  final hintRect = Rect.fromLTWH(
      hintX.screenHintLeft - offset.dx, hintY.hintTop - offset.dy, hintTextSize.width, hintTextSize.height);

  final result = HintBounds(
    rect: hintRect,
    maxTextWidth: hintTextSize.width - AppDimension.hintInsets * 2,
    pointerLeft: Point(hintX.arrowBaseLeft, hintY.arrowBase),
    pointerArrow: Point(hintX.arrowBaseLeft + AppDimension.hintArrowWidth / 2, hintY.arrowPoint),
    pointerRight: Point(hintX.arrowBaseLeft + AppDimension.hintArrowWidth, hintY.arrowBase),
  );
  _logger.fine("generated the following hint bounds for $anchorKey: $result");
  return result;
}

Rect? _calculateScreenPosition(GlobalKey key) {
  var context = key.currentContext;
  if (context == null) {
    _logger.fine("can not calculate screen position for widget '$key' - build context is undefined");
    return null;
  }
  final box = context.findRenderObject();
  if (box == null) {
    _logger.fine("can not calculate screen position for widget '$key' - the widget is not drawn now");
    return null;
  }
  final matrix = box.getTransformTo(null);
  return MatrixUtils.transformRect(matrix, box.paintBounds);
}

_HintX _calculateHintX(Size screenSize, Size hintTextSize, Rect anchorRect) {
  double screenHintX = (screenSize.width - hintTextSize.width) / 2;
  final screenArrowBaseLeft = anchorRect.left + anchorRect.width / 2 - AppDimension.hintArrowWidth / 2;
  final screenMinX = screenArrowBaseLeft - AppDimension.minHintArrowIndent;
  final screenMaxX = screenArrowBaseLeft + AppDimension.hintArrowWidth + AppDimension.minHintArrowIndent;
  if (screenHintX > screenMinX) {
    return _HintX(screenMinX, AppDimension.minHintArrowIndent);
  } else if (screenHintX < screenMaxX) {
    return _HintX(screenMaxX, hintTextSize.width - AppDimension.minHintArrowIndent);
  } else {
    return _HintX(screenHintX, screenArrowBaseLeft - screenHintX);
  }
}

_HintY _calculateHintY(Size hintTextSize, Rect anchorRect, HintLocation location) {
  if (location == HintLocation.above) {
    final base = anchorRect.top - AppDimension.hintArrowHeight;
    // we do -1 here in order to cover the border
    return _HintY(
        base - hintTextSize.height, hintTextSize.height - 1, hintTextSize.height + AppDimension.hintArrowHeight - 1);
  } else {
    final base = anchorRect.bottom + AppDimension.hintArrowHeight;
    // we do +1 here in order to cover the board
    return _HintY(base, 1, 1 - AppDimension.hintArrowHeight);
  }
}

class _HintX {
  final double screenHintLeft;
  final double arrowBaseLeft;

  _HintX(this.screenHintLeft, this.arrowBaseLeft);

  @override
  String toString() {
    return '_HintX{hintLeft: $screenHintLeft, arrowBaseLeft: $arrowBaseLeft}';
  }
}

class _HintY {
  final double hintTop;
  final double arrowBase;
  final double arrowPoint;

  _HintY(this.hintTop, this.arrowBase, this.arrowPoint);

  @override
  String toString() {
    return '_HintY{hintTop: $hintTop, arrowBase: $arrowBase, arrowPoint: $arrowPoint}';
  }
}
