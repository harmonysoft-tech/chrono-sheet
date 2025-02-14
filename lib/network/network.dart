import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final _logger = getNamedLogger();

Future<bool> isOnline() async {
  try {
    final result = await Connectivity().checkConnectivity();
    _logger.info("detected connectivity status '$result'");
    return result.any((status) => status != ConnectivityResult.none);
  } catch (e) {
    _logger.info("detected that the application is currently offline");
    return false;
  }
}