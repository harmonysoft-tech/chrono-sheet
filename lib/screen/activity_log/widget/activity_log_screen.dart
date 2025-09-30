import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/measurement/model/measurement.dart';
import 'package:chrono_sheet/measurement/model/measurements_state.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../network/network.dart';
import '../../../google/sheet/service/google_sheet_updater.dart';

final _logger = getNamedLogger();

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  bool _hasUnsaved(List<Measurement> measurements) {
    for (int i = measurements.length - 1; i >= 0; i--) {
      if (!measurements[i].saved) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final measurementsAsync = ref.watch(measurementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleActivity),
        actions: [
          IconButton(
            onPressed: measurementsAsync.maybeWhen(
              data: (measurements) => _hasUnsaved(measurements)
                  ? () async {
                      final online = await isOnline();
                      if (online) {
                        ref.read(sheetUpdaterProvider.notifier).storeUnsavedMeasurements();
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.textCanNotSaveMeasurementsWhileOffline),
                          ));
                        } else {
                          _logger.info(
                            "cannot show 'cannot save measurements' snackbar because the context is not mounted",
                          );
                        }
                      }
                    }
                  : null,
              orElse: () => null,
            ),
            icon: Icon(Icons.save),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimension.screenPadding),
        child: measurementsAsync.maybeWhen(
          data: (measurements) => ActivityLogWidget(),
          orElse: () => CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class ActivityLogWidget extends ConsumerWidget {
  const ActivityLogWidget({super.key});

  List<ListElement> _getElements(List<Measurement> measurements) {
    final format = DateFormat.yMMMMd();
    DateTime? currentDate;
    List<ListElement> result = [];
    for (final measurement in measurements) {
      final date = getBeginningOfTheDay(measurement.time);
      if (currentDate == null) {
        currentDate = date;
        result.add(MeasurementElement(measurement));
        continue;
      }
      if (date == currentDate) {
        result.add(MeasurementElement(measurement));
        continue;
      }

      result.add(TitleElement(format.format(currentDate)));
      currentDate = date;
      result.add(MeasurementElement(measurement));
    }
    if (result.isNotEmpty) {
      final last = result.last;
      if (last is MeasurementElement) {
        result.add(TitleElement(format.format(getBeginningOfTheDay(last.measurement.time))));
      }
    }
    return result.reversed.toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsAsync = ref.watch(measurementsProvider);
    final theme = Theme.of(context);
    final List<Measurement> measurements = measurementsAsync.maybeMap(
      data: (data) => data.value,
      orElse: () => [],
    );
    final elements = _getElements(measurements);
    return ListView.separated(
      separatorBuilder: (context, i) => Divider(
        thickness: 2,
      ),
      itemCount: elements.length,
      itemBuilder: (context, i) {
        final element = elements[i];
        switch (element) {
          case TitleElement(title: final title):
            return Center(
              child: Text(
                title,
                style: theme.textTheme.titleMedium,
              ),
            );
          case MeasurementElement(measurement: final m):
            return Padding(
              padding: EdgeInsets.all(AppDimension.elementPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        "${m.durationSeconds}m ${m.category.name}",
                        style: m.saved
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                      ),
                    ),
                  ),
                  Icon(m.saved ? Icons.bookmark : Icons.bookmark_border),
                ],
              ),
            );
        }
      },
    );
  }
}

sealed class ListElement {}

class MeasurementElement extends ListElement {
  final Measurement measurement;

  MeasurementElement(this.measurement);
}

class TitleElement extends ListElement {
  final String title;

  TitleElement(this.title);
}
