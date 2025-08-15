import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static late String categoryIconRootDir;
  static late String categoryIconDataDir;

  static void init(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    AppPaths.categoryIconRootDir = "${directory.path}/icon/category";
    AppPaths.categoryIconDataDir = "$categoryIconRootDir/data";
  }
}