import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppDimension {
  static const double screenPadding = 16.0;
  static const double elementPadding = 8.0;
  static const double historyIconButtonSize = 40.0;
  static const double labelVerticalInset = 8.0;
  static const double hintBorderRadius = 8.0;
  static const double hintInsets = 8.0;
  static const double minHintArrowIndent = 8.0;
  static const double hintArrowHeight = 8.0;
  static const double hintArrowWidth = hintArrowHeight * 2;
  static const borderCornerRadius = 12.0;

  static double getCategoryWidgetEdgeLength(BuildContext context) {
    return MediaQuery.of(context).size.width / 6;
  }
}

Size getTextSize(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: null,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    textHeightBehavior: TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
  )..layout(maxWidth: maxWidth);
  double minWidth = -1.0;
  double height = 0.0;
  for (final line in painter.computeLineMetrics()) {
    if (minWidth < line.width) {
      minWidth = line.width;
    }
    height += line.height;
  }
  if (minWidth < 0.0) {
    minWidth = maxWidth;
  }
  return Size(minWidth, height);
}