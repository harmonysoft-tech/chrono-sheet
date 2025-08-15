import 'package:flutter/foundation.dart';

@immutable
class CategoryIconInfo {
  final String fileName;
  final DateTime activationTime;

  const CategoryIconInfo({required this.fileName, required this.activationTime});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CategoryIconInfo &&
              runtimeType == other.runtimeType &&
              fileName == other.fileName &&
              activationTime == other.activationTime;

  @override
  int get hashCode => fileName.hashCode ^ activationTime.hashCode;

  @override
  String toString() {
    return 'IconInfo{fileName: $fileName, activationTime: $activationTime}';
  }
}
