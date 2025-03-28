import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/log/state/log_state.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogScreen extends ConsumerWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logStateManagerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleLogs),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: logState.join("\n"),
              )).then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.textCopiedToClipboard)));
                }
              });
            },
            icon: Icon(Icons.copy),
          ),
          IconButton(
            onPressed: () {
              ref.read(logStateManagerProvider.notifier).clear();
            },
            icon: Icon(Icons.delete),
          ),
        ],
      ),
      body: logState.isEmpty
          ? Center(
              child: Text("no logs are available"),
            )
          : ListView.builder(
              padding: EdgeInsets.all(AppDimension.screenPadding),
              itemCount: logState.length,
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: EdgeInsets.all(AppDimension.elementPadding),
                  child: Text(logState[index]),
                ),
              ),
            ),
    );
  }
}
