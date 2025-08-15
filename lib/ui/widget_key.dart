import 'package:flutter/cupertino.dart';

class AppWidgetKey {
  static final createFile = GlobalKey(debugLabel: "create file");
  static final selectFile = GlobalKey(debugLabel: "select file");
  static final createCategory = GlobalKey(debugLabel: "create category");
  static final selectCategory = GlobalKey(debugLabel: "select category");
  static final mainScreenCanvas = GlobalKey(debugLabel: "main screen");
  static final manageCategoryName = GlobalKey(debugLabel: "manage category name");
  static final manageCategoryIcon = GlobalKey(debugLabel: "manage category icon");
  static final saveCategoryState = GlobalKey(debugLabel: "save category state");
}
