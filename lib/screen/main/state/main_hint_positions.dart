import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../hint/model/hint_model.dart';
import '../../../hint/util/hint_util.dart';

part "main_hint_positions.g.dart";

class HintPositionsState {
  final HintBounds? createFile;
  final HintBounds? selectFile;
  final HintBounds? createCategory;
  final HintBounds? selectCategory;

  HintPositionsState({
    this.createFile,
    this.selectFile,
    this.createCategory,
    this.selectCategory,
  });
}

@riverpod
class HintPositions extends _$HintPositions {
  @override
  HintPositionsState build() {
    final state = ref.watch(sheetUpdaterProvider);
    if (state is! AppError) {
      return HintPositionsState();
    }
    if (state.error == SaveMeasurementsError.noFileIsSelected) {
      return HintPositionsState(
        createFile: calculateHintBounds(
          anchorKey: AppWidgetKey.createFile,
          canvasKey: AppWidgetKey.mainScreenCanvas,
          location: HintLocation.above,
        ),
        selectFile: calculateHintBounds(
          anchorKey: AppWidgetKey.selectFile,
          canvasKey: AppWidgetKey.mainScreenCanvas,
          location: HintLocation.below,
        ),
      );
    } else if (state.error == SaveMeasurementsError.noCategoryIsSelected) {
      return HintPositionsState(
        createCategory: calculateHintBounds(
          anchorKey: AppWidgetKey.createCategory,
          canvasKey: AppWidgetKey.mainScreenCanvas,
          location: HintLocation.above,
        ),
        selectCategory: calculateHintBounds(
          anchorKey: AppWidgetKey.selectCategory,
          canvasKey: AppWidgetKey.mainScreenCanvas,
          location: HintLocation.below,
        ),
      );
    } else {
      return HintPositionsState();
    }
  }
}
