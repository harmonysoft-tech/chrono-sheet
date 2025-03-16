import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/measurement/service/stop_watch_service.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StopWatchWidget extends ConsumerWidget {
  const StopWatchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final stopWatchState = ref.watch(stopWatchServiceProvider);
    final service = ref.read(stopWatchServiceProvider.notifier);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: service.toggle,
            child: AnimatedOpacity(
              opacity: (!stopWatchState.running && stopWatchState.measuredDuration > Duration.zero)
                  ? (clockProvider.now().millisecond % 1000 < 500)
                  ? 0.0
                  : 1.0
                  : 1.0,
              duration: Duration(milliseconds: 200),
              child: Text(
                service.format(stopWatchState.measuredDuration),
                style: TextStyle(
                  fontSize: theme.textTheme.displayLarge?.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            stopWatchState.running
                ? ElevatedButton.icon(
              onPressed: service.toggle,
              icon: Icon(Icons.pause),
              label: Text(l10n.actionPause),
            )
                : ElevatedButton.icon(
              onPressed: service.toggle,
              icon: Icon(Icons.play_arrow),
              label: Text(service.hasMeasurement() ? l10n.actionResume : l10n.actionStart),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: service.hasMeasurement() ? service.reset : null,
              icon: Icon(Icons.refresh),
              label: Text(l10n.actionReset),
            ),
            SizedBox(width: 18),
            ElevatedButton.icon(
              onPressed: service.hasMeasurement() ? service.saveMeasurement : null,
              icon: Icon(Icons.save),
              label: Text(l10n.actionSave),
            ),
          ],
        )
      ],
    );
  }
}
