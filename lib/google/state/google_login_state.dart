import 'package:chrono_sheet/google/google_helper.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part "google_login_state.g.dart";

final _logger = getNamedLogger();

@riverpod
class LoginStateManager extends _$LoginStateManager {

  static const _key = "logged.in";

  final _pref = SharedPreferencesAsync();

  @override
  Future<bool> build() async {
    final cached = await _pref.getBool(_key);
    if (cached == null) {
      _logger.fine("checking if we are logged in now");
      final account = await signIn.signInSilently();
      _logger.fine("observing the following google account: $account");
      await _pref.setBool(_key, account != null);
      return account != null;
    } else {
      _logger.fine("checking if we are logged in now");
      signIn.signInSilently().then((loggedIn) {
        _logger.fine("observing the 'logged in' state: $loggedIn");
        _pref.setBool(_key, loggedIn != null);
        state = AsyncValue.data(loggedIn != null);
      });
      return cached;
    }
  }

  Future<void> login() async {
    _logger.fine("got a request to login");
    state = AsyncValue.loading();
    try {
      await _pref.setBool(_key, true);
      await getAuthenticatedGoogleApiHttpClient();
      state = AsyncValue.data(true);
    } catch (e) {
      await _pref.setBool(_key, false);
      state = AsyncValue.data(false);
    }
  }

  Future<void> logout() async {
    _logger.fine("got a request to logout");
    state = AsyncValue.loading();
    await signIn.disconnect();
    await _pref.setBool(_key, false);
    state = AsyncValue.data(false);
  }
}