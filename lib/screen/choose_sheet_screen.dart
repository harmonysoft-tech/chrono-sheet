import 'package:chrono_sheet/file/selected/model/selected_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../file/loader/google_files_loader.dart';

class ChooseSheetScreen extends ConsumerStatefulWidget {

  const ChooseSheetScreen({super.key});

  @override
  ConsumerState createState() => ChooseSheetState();
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
        title: Text('Choose Google Sheet File'), // TODO implement i18n
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification
              && notification.metrics.extentAfter == 0
              && state.nextPageToken != null
              && !state.loading
          ) {
            notifier.loadFiles();
          }
          return false;
        },
        child: Column(
          children: [
            Expanded(
                child: ListView.builder(
                  itemCount: state.files.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(
                      child: Icon(Icons.table_chart)
                    ),
                    title: Text(
                      state.files[index].name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    onTap: () {
                      ref.read(selectedFileProvider.notifier).select(
                          state.files[index]
                      );
                      context.pop();
                    },
                  ),
                )
            ),
            if (state.loading) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LinearProgressIndicator()
              )
            ]
          ],
        ),
      ),
    );
  }
}