import 'package:flutter/foundation.dart';

@immutable
class Category implements Comparable<Category> {
  final String name;

  const Category(this.name);

  @override
  int compareTo(Category other) {
    return name.compareTo(other.name);
  }
}