import 'package:chrono_sheet/google/sheet/service/google_sheet_service.dart';
import 'package:chrono_sheet/measurement/model/measurement.dart';
import 'package:chrono_sheet/measurement/model/measurements_state.dart';
import 'package:chrono_sheet/network/network.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../category/model/category.dart';
import '../../../category/state/categories_state.dart';
import '../../../file/state/file_state.dart';
import '../../drive/model/google_file.dart';
import '../../../log/util/log_util.dart';

part 'google_sheet_updater.g.dart';

final _logger = getNamedLogger();

sealed class SaveMeasurementState {
  static SaveMeasurementState success = Success();
  static SaveMeasurementState idle = Idle();
}

class Idle extends SaveMeasurementState {}

class InProgress extends SaveMeasurementState {}

class Success extends SaveMeasurementState {}

class AppError extends SaveMeasurementState {
  SaveMeasurementsError error;

  AppError(this.error);
}

class GenericError extends SaveMeasurementState {
  String error;

  GenericError(this.error);
}

enum SaveMeasurementsError {
  noFileIsSelected,
  noCategoryIsSelected,
  offline,
}

@Riverpod(keepAlive: true)
class SheetUpdater extends _$SheetUpdater {
  @override
  SaveMeasurementState build() {
    return SaveMeasurementState.idle;
  }

  Future<Either<AppError, FileAndCategory>> prepareToStore(Duration measurement) async {
    final GoogleFile? file = await prepareToChange();
    if (file == null) {
      return Either.left(AppError(SaveMeasurementsError.noCategoryIsSelected));
    }
    final categoryInfo = await ref.read(categoriesStateManagerProvider.future);
    final category = categoryInfo.selected;
    if (category == null) {
      _logger.fine("skipped a request to store measurement $measurement in file "
          "'${file.name}' because no category selected");
      state = AppError(SaveMeasurementsError.noCategoryIsSelected);
      return Either.left(AppError(SaveMeasurementsError.noCategoryIsSelected));
    }

    return Either.right(FileAndCategory(file: file, category: category));
  }

  Future<GoogleFile?> prepareToChange() async {
    final fileState = await ref.read(fileStateManagerProvider.future);
    final GoogleFile? file = fileState.selected;
    if (file == null) {
      _logger.fine("skipped a request to to change google sheet because no document selected");
      state = AppError(SaveMeasurementsError.noFileIsSelected);
      return null;
    } else {
      return file;
    }
  }

  Future<SaveMeasurementState> storeUnsavedMeasurements() async {
    final measurementsAsync =  ref.read(measurementsProvider);
    List<Measurement> measurements;
    if (measurementsAsync is AsyncData<List<Measurement>>) {
      measurements = measurementsAsync.value;
    } else {
      return SaveMeasurementState.success;
    }

    if (measurements.isEmpty) {
      return SaveMeasurementState.success;
    }

    final online = await isOnline();
    if (!online) {
      _logger.info("skipping attempt to store unsaved measurements because the application is currently offline");
      return AppError(SaveMeasurementsError.offline);
    }

    final updateService = ref.read(googleSheetServiceProvider);
    final measurementsNotifier = ref.read(measurementsProvider.notifier);
    for (final measurement in measurements) {
      if (measurement.saved) {
        continue;
      }
      try {
        await updateService.saveMeasurement(measurement.durationSeconds, measurement.category.name, measurement.file);
        measurementsNotifier.onSaved(measurement);
        state = SaveMeasurementState.success;
      } catch (e, stack) {
        _logger.warning(
          "can not save measurement $measurement for category '${measurement.category}' "
          "in file ${measurement.file.name}",
          e,
          stack,
        );
        final error = GenericError(e.toString());
        state = error;
        return error;
      }
    }
    return SaveMeasurementState.success;
  }

  void reset() {
    state = SaveMeasurementState.idle;
  }
}

class FileAndCategory {
  final GoogleFile file;
  final Category category;

  FileAndCategory({
    required this.file,
    required this.category,
  });

  @override
  String toString() {
    return 'FileAndCategory{file: $file, category: $category}';
  }
}
