import 'package:chrono_sheet/measurement/model/measurement.dart';
import 'package:chrono_sheet/measurement/model/measurements_state.dart';
import 'package:chrono_sheet/network/network.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../category/model/category.dart';
import '../../category/state/category_state.dart';
import '../../file/model/google_file.dart';
import '../../file/state/file_state.dart';
import '../../log/util/log_util.dart';

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

@Riverpod(keepAlive: true)
class SheetUpdater extends _$SheetUpdater {
  @override
  SaveMeasurementState build() {
    return SaveMeasurementState.idle;
  }

  Future<FileAndCategory> prepareToStore(Duration measurement) async {
    final fileState = await ref.read(fileStateManagerProvider.future);
    final GoogleFile? file = fileState.selected;
    if (file == null) {
      _logger.fine("skipped a request to store measurement $measurement because no "
          "google sheet file is selected");
      state = Error(SaveMeasurementsError.noFileIsSelected);
      return FileAndCategory();
    }
    final categoryInfo = await ref.read(categoryStateManagerProvider.future);
    final category = categoryInfo.selected;
    if (category == null) {
      _logger.fine("skipped a request to store measurement $measurement in file "
          "'${file.name}' because no category selected");
      state = Error(SaveMeasurementsError.noCategoryIsSelected);
      return FileAndCategory(file: file);
    }

    return FileAndCategory(file: file, category: category);
  }

  Future<void> store(Duration measurement) async {
    if (measurement.inMinutes <= 0) {
      _logger.fine("skipped a request to store non-positive measurement $measurement");
      return;
    }

    final fileAndCategory = await prepareToStore(measurement);
    final file = fileAndCategory.file;
    if (file == null) {
      return;
    }

    final category = fileAndCategory.category;
    if (category == null) {
      return;
    }

    await ref.read(measurementsProvider.notifier).save(
          Measurement(
            file: file,
            category: category,
            durationSeconds: measurement.inMinutes,
          ),
        );
    await storeUnsavedMeasurements();
  }

  Future<void> storeUnsavedMeasurements() async {
    final online = await isOnline();
    if (!online) {
      _logger.info("skipping attempt to store unsaved measurements because the application is currently offline");
      return;
    }

    final measurementsAsync =  ref.read(measurementsProvider);
    List<Measurement> measurements;
    if (measurementsAsync is AsyncData<List<Measurement>>) {
      measurements = measurementsAsync.value;
    } else {
      return;
    }

    final updateService = ref.read(updateServiceProvider);
    final measurementsNotifier = ref.read(measurementsProvider.notifier);
    for (final measurement in measurements) {
      if (measurement.saved) {
        continue;
      }
      try {
        await updateService.saveMeasurement(measurement.durationSeconds, measurement.category, measurement.file);
        measurementsNotifier.onSaved(measurement);
        state = SaveMeasurementState.success;
      } catch (e, stack) {
        _logger.warning(
          "can not save measurement $measurement for category '${measurement.category}' "
          "in file ${measurement.file.name}",
          e,
          stack,
        );
        state = Error(SaveMeasurementsError.generic);
        break;
      }
    }
  }

  void reset() {
    state = SaveMeasurementState.idle;
  }
}

class FileAndCategory {
  final GoogleFile? file;
  final Category? category;

  FileAndCategory({
    this.file,
    this.category,
  });

  bool get ready => file != null && category != null;

  @override
  String toString() {
    return 'FileAndCategory{file: $file, category: $category}';
  }
}
