import 'package:chrono_sheet/google/google_helper.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part "google_login_state.g.dart";

final _logger = getNamedLogger();

@riverpod
class LoginState extends _$LoginState {

  @override
  Future<bool> build() async {
    _logger.fine("checking if we are logged in now");
    final account = await signIn.signInSilently();
    _logger.fine("observing the following google account: $account");
    return account != null;
  }

  Future<void> login() async {
    _logger.fine("got a request to login");
    state = AsyncValue.loading();
    try {
      await getAuthenticatedGoogleApiHttpClient();
      state = AsyncValue.data(true);
    } catch (e) {
      state = AsyncValue.data(false);
    }
  }

  Future<void> logout() async {
    _logger.fine("got a request to logout");
    state = AsyncValue.loading();
    await signIn.disconnect();
    state = AsyncValue.data(false);
  }
}