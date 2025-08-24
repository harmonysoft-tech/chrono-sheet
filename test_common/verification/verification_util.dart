import 'package:fpdart/fpdart.dart';

class VerificationUtil {
  static Future<T> getDataWithWaiting<T>(
    String description,
    Future<Either<String, T>> Function() action, [
    int ttlMs = 3000,
    int checkFrequencyMs = 100,
  ]) async {
    final end = DateTime.now().millisecondsSinceEpoch;
    while (DateTime.now().millisecondsSinceEpoch <= end) {
      final result = await action();
      if (result.isRight()) {
        return result.fold((l) => throw AssertionError("can not $description: $l"), (r) => r);
      }
    }
    final result = await action();
    return result.fold((l) => throw AssertionError("can not $description: $l"), (r) => r);
  }
}
