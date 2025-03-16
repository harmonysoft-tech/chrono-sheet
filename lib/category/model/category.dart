import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Key {
  static String getName(String keyPrefix) {
    return "$keyPrefix.name";
  }
}

@immutable
final class Category implements Comparable<Category> {
  final String name;
  final CategoryRepresentation representation;

   Category({
    required this.name,
    required this.representation,
  }) {
    if (name.trim().isEmpty)  {
      throw ArgumentError.notNull("category name must be provided, representation: $representation");
    }
  }

  Category copyWith({
    String? name,
    CategoryRepresentation? representation,
  }) {
    return Category(
      name: name ?? this.name,
      representation: representation ?? this.representation,
    );
  }

  Future<void> serialize(SharedPreferencesAsync prefs, String keyPrefix) async {
    await prefs.setString(_Key.getName(keyPrefix), name);
    await representation.serialize(prefs, keyPrefix);
  }

  static Future<Category?> deserialiseIfPossible(SharedPreferencesAsync prefs, String keyPrefix) async {
    final name = await prefs.getString(_Key.getName(keyPrefix));
    if (name == null) {
      return null;
    }
    final representation = await CategoryRepresentation.deserialiseIfPossible(prefs, keyPrefix);
    if (representation == null) {
      return null;
    }
    return Category(name: name, representation: representation);
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
    return 'Category{name: $name, representation: $representation}';
  }
}
