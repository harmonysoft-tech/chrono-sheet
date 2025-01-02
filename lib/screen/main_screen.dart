import 'package:chrono_sheet/file/widget/view_selected_file_widget.dart';
import 'package:chrono_sheet/file/widget/selected_file_widget.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/google/state/google_login_state.dart';
import 'package:chrono_sheet/measurement/widget/stop_watch_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../category/widget/category_widget.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedInAsync = ref.watch(loginStateProvider);
    final columnVerticalInset = 24.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appName),
        actions: [
          loggedInAsync.when(
            data: (loggedIn) => loggedIn
                ? IconButton(
                    onPressed: () => ref.read(loginStateProvider.notifier).logout(),
                    icon: Icon(Icons.logout),
                  )
                : LoginWidget(),
            error: (_, __) => LoginWidget(),
            loading: () => CircularProgressIndicator(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StopWatchWidget(),
            SizedBox(height: columnVerticalInset),
            SelectedFileWidget(),
            SizedBox(height: columnVerticalInset),
            CategoryWidget(),
            SizedBox(height: columnVerticalInset),
            ViewSelectedFileWidget(),
          ],
        ),
      ),
    );
  }
}

class LoginWidget extends ConsumerWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => ref.read(loginStateProvider.notifier).login(),
      icon: Icon(Icons.login),
    );
  }
}
