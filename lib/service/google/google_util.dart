import 'package:googleapis/drive/v3.dart';

class GoogleUtil {
  static String getId(File file) {
    final result = file.id ?? file.driveId ?? file.name;
    if (result == null) {
      throw ArgumentError("can not get id for google file $file");
    }
    return result;
  }
}