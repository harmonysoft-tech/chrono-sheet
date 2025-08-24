import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

@immutable
class IconInfo {
  final String fileName;
  final DateTime activationTime;

  const IconInfo({required this.fileName, required this.activationTime});

  static Either<String, IconInfo> parse(String content) {
    final i = content.indexOf(",");
    if (i <= 0 || i >= content.length) {
      return Either.left("can not parse icon info, it doesn't have ',' symbol:\n$content");
    }
    final fileName = content.substring(0, i);
    var rawTime = content.substring(i + 1);
    final time = DateTime.tryParse(rawTime);
    if (time == null) {
      return Either.left("can not parse icon info, date format is incorrect - $rawTime, full content: \n$content");
    }
    return Either.right(IconInfo(fileName: fileName, activationTime: time));
  }

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