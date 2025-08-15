import 'package:flutter/foundation.dart';

@immutable
class IconInfo {
  final String fileName;
  final DateTime activationTime;

  const IconInfo({required this.fileName, required this.activationTime});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconInfo &&
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