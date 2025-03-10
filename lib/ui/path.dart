import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static late String categoryIconDir;

  static void init(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    AppPaths.categoryIconDir = "${directory.path}/icon/category";
  }
}