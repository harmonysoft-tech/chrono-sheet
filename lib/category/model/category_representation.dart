import 'dart:io';

import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = getNamedLogger();

class _Key {
  static String getRepresentationType(String keyPrefix) {
    return "$keyPrefix.ui.type";
  }

  static String getRepresentationData(String keyPrefix) {
    return "$keyPrefix.ui.data";
  }
}

class _Value {
  static const text = "text";
  static const image = "image";
}

sealed class CategoryRepresentation<T extends CategoryRepresentation<T>> implements Comparable<CategoryRepresentation> {

  Future<void> serialize(SharedPreferencesAsync prefs, String keyPrefix) async {
    switch (this) {
      case TextCategoryRepresentation(text: final data):
        await prefs.setString(_Key.getRepresentationType(keyPrefix), _Value.text);
        await prefs.setString(_Key.getRepresentationData(keyPrefix), data);
      case ImageCategoryRepresentation(file: final file):
        await prefs.setString(_Key.getRepresentationType(keyPrefix), _Value.image);
        await prefs.setString(_Key.getRepresentationData(keyPrefix), file.path);
    }
  }

  static Future<CategoryRepresentation?> deserialiseIfPossible(SharedPreferencesAsync prefs, String keyPrefix) async {
    var typeKey = _Key.getRepresentationType(keyPrefix);
    final type = await prefs.getString(typeKey);
    if (type == null) {
      _logger.info("cannot deserialise category representation for the prefix '$keyPrefix' - its type is not stored "
          "under key '$typeKey'");
      return null;
    }
    final dataKey = _Key.getRepresentationData(keyPrefix);
    final data = await prefs.getString(dataKey);
    if (data == null) {
      _logger.info("cannot deserialise category representation for the prefix '$keyPrefix' - its data is not stored "
          "under key '$dataKey'");
      return null;
    }
    switch (type) {
      case _Value.text:
        return TextCategoryRepresentation(data);
      case _Value.image:
        final file = File(data);
        if (file.existsSync()) {
          return ImageCategoryRepresentation(file);
        } else {
          _logger.info("cannot deserialise image category representation for the prefix '$keyPrefix' - "
              "it points to file ${file.path} but the file doesn't exist");
          return null;
        }
      default:
        _logger.info("cannot deserialise image category representation for the prefix '$keyPrefix' - "
            "it uses non-existing type '$type'");
        return null;
    }
  }


  @override
  int compareTo(CategoryRepresentation other) {
    int typeComparison = runtimeType.toString().compareTo(other.runtimeType.toString());
    if (typeComparison == 0) {
      return _doCompareTo(other as T);
    } else {
      return typeComparison;
    }
  }

  int _doCompareTo(T other);
}

class TextCategoryRepresentation extends CategoryRepresentation<TextCategoryRepresentation> {
  final String text;

  TextCategoryRepresentation(this.text);

  @override
  int _doCompareTo(TextCategoryRepresentation other) {
    return text.compareTo(other.text);
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextCategoryRepresentation && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() {
    return 'TextRepresentation{text: $text}';
  }
}

class ImageCategoryRepresentation extends CategoryRepresentation<ImageCategoryRepresentation> {
  final File file;

  ImageCategoryRepresentation(this.file);

  @override
  int _doCompareTo(ImageCategoryRepresentation other) {
    return file.path.compareTo(other.file.path);
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageCategoryRepresentation && runtimeType == other.runtimeType && file.path == other.file.path;

  @override
  int get hashCode => file.path.hashCode;

  @override
  String toString() {
    return 'ImageCategoryRepresentation{data: ${file.path}';
  }
}
