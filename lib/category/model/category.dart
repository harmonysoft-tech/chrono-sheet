import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = getNamedLogger();

class _Key {
  static String getName(String keyPrefix) {
    return "$keyPrefix.name";
  }

  static String getPersistedInGoogle(String keyPrefix) {
    return "$keyPrefix.persistedInGoogle";
  }
}

@immutable
final class Category implements Comparable<Category> {
  final String name;
  final CategoryRepresentation representation;
  final bool persistedInGoogle;

   Category({
    required this.name,
    required this.representation,
    required this.persistedInGoogle,
  }) {
    if (name.trim().isEmpty)  {
      throw ArgumentError.notNull("category name must be provided, representation: $representation");
    }
  }

  Category copyWith({
    String? name,
    CategoryRepresentation? representation,
    bool? persistedInGoogle,
  }) {
    return Category(
      name: name ?? this.name,
      representation: representation ?? this.representation,
      persistedInGoogle: persistedInGoogle ?? this.persistedInGoogle,
    );
  }

  Future<void> serialize(SharedPreferencesAsync prefs, String keyPrefix) async {
    await prefs.setString(_Key.getName(keyPrefix), name);
    await prefs.setBool(_Key.getPersistedInGoogle(keyPrefix), persistedInGoogle);
    await representation.serialize(prefs, keyPrefix);
    _logger.fine("stored category $this in the local storage using key prefix '$keyPrefix'");
  }

  static Future<Category?> deserialiseIfPossible(SharedPreferencesAsync prefs, String keyPrefix) async {
    final name = await prefs.getString(_Key.getName(keyPrefix));
    if (name == null) {
      return null;
    }
    final persistedInGoogle = await prefs.getBool(_Key.getPersistedInGoogle(keyPrefix)) ?? false;
    final representation = await CategoryRepresentation.deserialiseIfPossible(prefs, keyPrefix);
    if (representation == null) {
      return null;
    }
    return Category(name: name, representation: representation, persistedInGoogle: persistedInGoogle);
  }

  @override
  int compareTo(Category other) {
    final nameCmp = name.compareTo(other.name);
    if (nameCmp != 0) {
      return nameCmp;
    } else {
      return representation.compareTo(other.representation);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          representation == other.representation;

  @override
  int get hashCode => name.hashCode ^ representation.hashCode;

  @override
  String toString() {
    return 'Category{name: $name, persistedInGoogle: $persistedInGoogle, representation: $representation}';
  }
}
