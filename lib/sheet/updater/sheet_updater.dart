import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../category/state/categories_state.dart';
import '../../file/model/google_file.dart';
import '../../file/state/files_state.dart';

part 'sheet_updater.g.dart';

final _logger = getNamedLogger();

sealed class SaveMeasurementState {
  static SaveMeasurementState success = Success();
  static SaveMeasurementState idle = Idle();
}

class Idle extends SaveMeasurementState {}

class InProgress extends SaveMeasurementState {}

class Success extends SaveMeasurementState {}

class Error extends SaveMeasurementState {
  SaveMeasurementsError error;

  Error(this.error);
}

enum SaveMeasurementsError {
  noFileIsSelected,
  noCategoryIsSelected,
  generic,
}

@riverpod
class SheetUpdater extends _$SheetUpdater {
  @override
  SaveMeasurementState build() {
    return SaveMeasurementState.idle;
  }

  Future<void> store(Duration measurement) async {
    if (measurement.compareTo(Duration.zero) <= 0) {
      _logger.fine(
          "skipped a request to store non-positive measurement $measurement"
      );
      return;
    }

    final fileInfo = await ref.read(filesInfoHolderProvider.future);
    final GoogleFile? file = fileInfo.selected;
    if (file == null) {
      _logger.fine(
          "skipped a request to store measurement $measurement because no "
          "google sheet file is selected"
      );
      state = Error(SaveMeasurementsError.noFileIsSelected);
      return;
    }

    final categoryInfo = await ref.read(fileCategoriesProvider.future);
    final category = categoryInfo.selected;
    if (category == null) {
      _logger.fine("skipped a request to store measurement $measurement in file "
          "'${file.name}' because no category selected");
      state = Error(SaveMeasurementsError.noCategoryIsSelected);
      return;
    }

    final service = ref.read(updateServiceProvider);
    try {
      await service.saveMeasurement(measurement.inMinutes, category, file);
      state = SaveMeasurementState.success;
    } catch (e, stack) {
      _logger.warning("can not save measurement $measurement for category '$category' in file ${file.name}", e, stack);
      state = Error(SaveMeasurementsError.generic);
    }
  }

  void reset() {
    state = SaveMeasurementState.idle;
  }
}
