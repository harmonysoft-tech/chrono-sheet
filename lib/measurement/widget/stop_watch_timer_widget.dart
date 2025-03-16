import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../util/date_util.dart';
import '../service/stop_watch_service.dart';

class StopWatchTimerWidget extends ConsumerWidget {

  const StopWatchTimerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopWatchServiceProvider);
    final service = ref.read(stopWatchServiceProvider.notifier);
    final theme = Theme.of(context);
    final double opacity;
    if (!state.running && state.measuredDuration > Duration.zero) {
      opacity = clockProvider.now().millisecond % 1000 < 500 ? 0.0: 1.0;
    } else {
      opacity = 1.0;
    }
    return Center(
      child: GestureDetector(
        onTap: service.toggle,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: Duration(milliseconds: 200),
          child: Text(
            service.format(state.measuredDuration),
            style: TextStyle(
              fontSize: theme.textTheme.displayLarge?.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}