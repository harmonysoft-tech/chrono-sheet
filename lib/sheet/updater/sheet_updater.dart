import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../category/state/categories_state.dart';
import '../../file/model/google_file.dart';
import '../../file/state/files_state.dart';

part 'sheet_updater.g.dart';

final _logger = getNamedLogger();

enum SaveMeasurementStatus {
  idle, inProgress, success, error
}

class SaveMeasurementState {

  static SaveMeasurementState success = SaveMeasurementState(status: SaveMeasurementStatus.success);
  static SaveMeasurementState idle = SaveMeasurementState(status: SaveMeasurementStatus.idle);

  final SaveMeasurementStatus status;
  final String? error;

  const SaveMeasurementState({
    this.status = SaveMeasurementStatus.idle,
    this.error,
  });

  SaveMeasurementState copyWith({
    SaveMeasurementStatus? status,
    String? error,
  }) {
    return SaveMeasurementState(
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

@riverpod
class SheetUpdater extends _$SheetUpdater {
  @override
  SaveMeasurementState build() {
    return SaveMeasurementState.idle;
  }

  Future<void> store(Duration measurement, AppLocalizations l10n) async {
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
      state = state.copyWith(
        status: SaveMeasurementStatus.error,
        error: l10n.errorNoFileIsSelected,
      );
      return;
    }

    final categoryInfo = await ref.read(fileCategoriesProvider.notifier).finaliseEditingIfNecessaryAndGet();
    final category = categoryInfo.selected;
    if (category == null) {
      _logger.fine("skipped a request to store measurement $measurement in file "
          "'${file.name}' because no category selected");
      state = state.copyWith(
        status: SaveMeasurementStatus.error,
        error: l10n.errorNoCategoryIsSelected,
      );
      return;
    }

    final service = ref.read(updateServiceProvider);
    try {
      // TODO change duration to minutes
      await service.saveMeasurement(measurement.inSeconds, category, file);
      state = SaveMeasurementState.success;
    } catch (e, stack) {
      _logger.warning("can not save measurement $measurement for category '$category' in file ${file.name}", e, stack);
      state = state.copyWith(
        status: SaveMeasurementStatus.error,
        error: e.toString()
      );
    }
  }

  void reset() {
    state = SaveMeasurementState.idle;
  }
}
