import 'package:flutter/foundation.dart';

@immutable
final class Category implements Comparable<Category> {
  final String name;

  const Category(this.name);

  @override
  int compareTo(Category other) {
    return name.compareTo(other.name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return name;
  }
}