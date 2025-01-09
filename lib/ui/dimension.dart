import 'package:flutter/cupertino.dart';

class AppDimension {
  static const double historyIconButtonSize = 40.0;
  static const double labelVerticalInset = 8.0;
  static const double hintBorderRadius = 8.0;
  static const double hintInsets = 8.0;
  static const double minHintArrowIndent = 8.0;
  static const double hintArrowHeight = 8.0;
  static const double hintArrowWidth = hintArrowHeight * 2;
}

Size getTextSize(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: null,
    textDirection: TextDirection.ltr
  )..layout(maxWidth: maxWidth);
  double minWidth = -1.0;
  for (final line in painter.computeLineMetrics()) {
    if (minWidth < line.width) {
      minWidth = line.width;
    }
  }
  if (minWidth < 0.0) {
    minWidth = maxWidth;
  }
  return Size(minWidth, painter.height);
}