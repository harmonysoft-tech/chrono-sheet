import 'package:fpdart/fpdart.dart';

class VerificationUtil {
  static Future<T> getDataWithWaiting<T>(
    String description,
    Future<Either<String, T>> Function() action, [
    Duration ttl = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
  ]) async {
    final endTime = DateTime.now().add(ttl);
    while (DateTime.now().isBefore(endTime)) {
      final result = await action();
      if (result.isRight()) {
        return result.fold((l) => throw AssertionError("can not $description: $l"), (r) => r);
      }
      await Future.delayed(pollInterval);
    }
    final result = await action();
    return result.fold((l) => throw AssertionError("can not $description: $l"), (r) => r);
  }
}
