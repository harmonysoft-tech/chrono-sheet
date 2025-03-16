import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../file/service/loader/google_files_loader.dart';
import '../../../generated/app_localizations.dart';
import '../../../ui/dimension.dart';

class ChooseSheetScreen extends ConsumerStatefulWidget {
  const ChooseSheetScreen({super.key});

  @override
  ChooseSheetState createState() => ChooseSheetState();
}

class ChooseSheetState extends ConsumerState<ChooseSheetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedFilesProvider.notifier).loadFiles(initialLoad: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedFilesProvider);
    final notifier = ref.read(paginatedFilesProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).titleSelectFile),
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadFiles(initialLoad: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter == 0 &&
                state.nextPageToken != null &&
                !state.loading) {
              notifier.loadFiles();
            }
            return false;
          },
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: state.files.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Image.asset(
                      "assets/icon/google-sheet.png",
                      width: AppDimension.iconSize,
                      height: AppDimension.iconSize,
                      fit: BoxFit.contain,
                    ),
                    title: Text(
                      state.files[index].name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    onTap: () {
                      ref.read(fileStateManagerProvider.notifier).select(state.files[index]);
                      context.pop();
                    },
                  ),
                  separatorBuilder: (context, index) => Divider(),
                ),
              ),
              if (state.loading) ...[Padding(padding: const EdgeInsets.all(16.0), child: LinearProgressIndicator())]
            ],
          ),
        ),
      ),
    );
  }
}
