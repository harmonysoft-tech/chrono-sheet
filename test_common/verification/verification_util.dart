import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:fpdart/fpdart.dart';

final _logger = getNamedLogger();

class VerificationUtil {
  static Future<void> verify(
    String description,
    Future<Either<String, Unit>> Function() action, [
    Duration ttl = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
  ]) async {
    await getDataWithWaiting("verify that $description", () => action());
  }

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
        _logger.info("success: $description -> $result");
        return result.match((l) => throw AssertionError("can not $description: $l"), (r) => r);
      }
      await Future.delayed(pollInterval);
    }
    final result = await action();
    return result.match((l) => throw AssertionError("can not $description: $l"), (r) => r);
  }
}
