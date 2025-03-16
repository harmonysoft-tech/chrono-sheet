import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/measurement/state/stop_watch_controls_ui_state.dart';
import 'package:chrono_sheet/measurement/widget/stop_watch_timer_widget.dart';
import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/util/snackbar_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/color.dart';

final _logger = getNamedLogger();

class StopWatchButtonsWidget extends ConsumerWidget {
  const StopWatchButtonsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopWatchControlUiStateManagerProvider);
    final primaryIconOuterSize = 96.0;
    final primaryIconInnerSize = 56.0;
    final secondaryIconOuterSize = 56.0;
    final secondaryIconInnerSize = 32.0;
    return Column(
      children: [
        StopWatchTimerWidget(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: state.reset.onPressed,
              icon: Container(
                width: secondaryIconOuterSize,
                height: secondaryIconOuterSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (state.reset.active) ? AppColor.activeIconBackground : AppColor.inactiveIconBackground,
                ),
                child: Icon(
                  Icons.refresh,
                  size: secondaryIconInnerSize,
                  color: (state.reset.active) ? AppColor.activeIconForeground : AppColor.inactiveIconForeground,
                ),
              ),
            ),
            IconButton(
              onPressed: state.playPause.onPressed,
              icon: Container(
                width: primaryIconOuterSize,
                height: primaryIconOuterSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.activeIconBackground,
                ),
                child: Icon(
                  state.playPause.running ? Icons.pause : Icons.play_arrow,
                  size: primaryIconInnerSize,
                  color: AppColor.activeIconForeground,
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                final saveMeasurementState = await state.record.onPressed?.call();
                if (saveMeasurementState is GenericError) {
                  SnackBarUtil.showMessage(context, saveMeasurementState.error, _logger);
                }
              },
              icon: Container(
                width: secondaryIconOuterSize,
                height: secondaryIconOuterSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.record.active ? AppColor.activeIconBackground : AppColor.inactiveIconBackground,
                ),
                child: Icon(
                  Icons.stop,
                  size: secondaryIconInnerSize,
                  color: state.record.active ? AppColor.activeIconForeground : AppColor.inactiveIconForeground,
                ),
              ),
            )
          ],
        )
      ],
    );
  }
}
