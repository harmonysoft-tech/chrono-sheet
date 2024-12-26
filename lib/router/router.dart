import 'package:chrono_sheet/screen/choose_sheet_screen.dart';
import 'package:chrono_sheet/screen/main_screen.dart';
import 'package:go_router/go_router.dart';

class AppRoute {
  static const root = '/';
  static const chooseSheet = '/sheet/choose';
}

final router = GoRouter(
    routes: [
      GoRoute(
          path: AppRoute.root,
          builder: (context, state) => MainScreen()
      ),
      GoRoute(
          path: AppRoute.chooseSheet,
          builder: (context, state) => ChooseSheetScreen()
      )
    ]
);