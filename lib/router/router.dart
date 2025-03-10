import 'dart:io';

import 'package:chrono_sheet/screen/category/widget/manage_category_screen.dart';
import 'package:chrono_sheet/screen/choose_sheet/widget/choose_sheet_screen.dart';
import 'package:chrono_sheet/screen/crop_icon/widget/crop_icon_screen.dart';
import 'package:chrono_sheet/screen/log/log_screen.dart';
import 'package:chrono_sheet/screen/main/widget/main_screen.dart';
import 'package:go_router/go_router.dart';

import '../category/model/category.dart';
import '../screen/activity_log/widget/activity_log_screen.dart';

class AppRoute {
  static const root = '/';
  static const chooseSheet = '/sheet/choose';
  static const logs = '/logs';
  static const activity = '/activity';
  static const manageCategory = '/category/manage';
  static const cropIcon = '/icon/crop';
}

final router = GoRouter(routes: [
  GoRoute(path: AppRoute.root, builder: (context, state) => MainScreen()),
  GoRoute(path: AppRoute.chooseSheet, builder: (context, state) => ChooseSheetScreen()),
  GoRoute(path: AppRoute.logs, builder: (context, state) => LogScreen()),
  GoRoute(path: AppRoute.activity, builder: (context, state) => ActivityLogScreen()),
  GoRoute(
    path: AppRoute.manageCategory,
    builder: (context, state) => ManageCategoryScreen(category: state.extra as Category?),
  ),
  GoRoute(path: AppRoute.cropIcon, builder: (context, state) => CropIconScreen(imageFile: state.extra as File)),
]);
