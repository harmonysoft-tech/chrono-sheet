import 'dart:math';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';

enum HintLocation {
  above,
  below,
}

class HintException implements Exception {
  final String message;

  const HintException(this.message);

  @override
  String toString() => message;
}

class HintBounds {
  final Rect rect;
  final double maxTextWidth;

  /// coordinate of the leftmost hint arrow point (relative to the hint widget)
  final Point<double> pointerLeft;

  /// coordinate of the hint arrow point (relative to the hint widget)
  final Point<double> pointerArrow;

  /// coordinate of the rightmost hint arrow point (relative to the hint widget)
  final Point<double> pointerRight;

  HintBounds({
    required this.rect,
    required this.maxTextWidth,
    required this.pointerLeft,
    required this.pointerArrow,
    required this.pointerRight,
  });

  @override
  String toString() {
    return 'HintBounds{rect: $rect, maxTextWidth: $maxTextWidth, pointerLeft: $pointerLeft, '
        'pointerArrow: $pointerArrow, pointerRight: $pointerRight}';
  }
}

final Map<GlobalKey, String Function(AppLocalizations)> key2hintText = {
  AppWidgetKey.createFile: (l10n) => l10n.hintCreateFile,
  AppWidgetKey.selectFile: (l10n) => l10n.hintSelectFile,
  AppWidgetKey.createCategory: (l10n) => l10n.hintCreateCategory,
  AppWidgetKey.selectCategory: (l10n) => l10n.hintSelectCategory,
};
