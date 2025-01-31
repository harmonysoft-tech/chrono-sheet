import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:uuid/uuid.dart';

import '../../category/model/category.dart';

class Measurement {
  final String id;
  final DateTime time;
  final GoogleFile file;
  final Category category;
  final int durationSeconds;
  final bool saved;

  Measurement({
    required this.file,
    required this.category,
    required this.durationSeconds,
    this.saved = false,
    String? id,
    DateTime? time,
  })  : id = id ?? Uuid().v4(),
        time = time ?? DateTime.now();

  Measurement copyWith({
    String? id,
    DateTime? time,
    GoogleFile? file,
    Category? category,
    int? durationSeconds,
    bool? saved,
  }) {
    return Measurement(
      id: id ?? this.id,
      time: time ?? this.time,
      file: file ?? this.file,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      saved: saved ?? this.saved,
    );
  }

  @override
  String toString() {
    return 'Measurement{id: $id, time: file: $file, $time, category: $category, '
        'durationSeconds: $durationSeconds, saved: $saved}';
  }
}
