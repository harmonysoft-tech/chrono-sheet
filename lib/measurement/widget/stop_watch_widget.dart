import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/measurement/widget/stop_watch_timer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/stop_watch_controls_ui_state.dart';

class StopWatchWidget extends ConsumerWidget {
  const StopWatchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopWatchControlUiStateManagerProvider);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StopWatchTimerWidget(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            state.playPause.running
                ? ElevatedButton.icon(
                    onPressed: state.playPause.onPressed,
                    icon: Icon(Icons.pause),
                    label: Text(l10n.actionPause),
                  )
                : ElevatedButton.icon(
                    onPressed: state.playPause.onPressed,
                    icon: Icon(Icons.play_arrow),
                    label: Text(state.playPause.running ? l10n.actionResume : l10n.actionStart),
                  ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: state.reset.onPressed,
              icon: Icon(Icons.refresh),
              label: Text(l10n.actionReset),
            ),
            SizedBox(width: 18),
            ElevatedButton.icon(
              onPressed: state.record.onPressed,
              icon: Icon(Icons.save),
              label: Text(l10n.actionSave),
            ),
          ],
        )
      ],
    );
  }
}
