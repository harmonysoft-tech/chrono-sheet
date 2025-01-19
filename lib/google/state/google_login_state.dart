import 'package:chrono_sheet/google/google_helper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../log/util/log_util.dart';

part "google_login_state.g.dart";

final _logger = getNamedLogger();

@riverpod
class LoginStateManager extends _$LoginStateManager {

  final _pref = SharedPreferencesAsync();

  @override
  Future<GoogleIdentity?> build() async {
    final cached = await _getCached();
    if (cached == null) {
      _logger.fine("no cached record is found checking if we are logged in now silently");
      final account = await signIn.signInSilently();
      _logger.fine("observing the following google account: $account");
      if (account != null) {
        await _cache(account);
      }
      return account;
    }

    _logger.fine("cached record is found but checking in background if we are logged in");
    signIn.signInSilently().then((account) async {
      if (account == null) {
        _resetCached();
        state = AsyncValue.data(null);
      } else if (account.id == cached.id && account.email == cached.email) {
        _logger.fine("detected that cached google login record ($cached) is still active");
      } else {
        final newState = await _cache(account);
        state = AsyncValue.data(newState);
      }
    });
    return cached;
  }

  Future<GoogleIdentity?> _getCached() async {
    final id = await _pref.getString(_Key.id);
    if (id == null || id.isEmpty) {
      return null;
    }
    final email = await _pref.getString(_Key.email);
    if (email == null || email.isEmpty) {
      return null;
    }

    return CachedGoogleIdentity(id: id, email: email);
  }

  Future<GoogleIdentity> _cache(GoogleIdentity identity) async {
    await _pref.setString(_Key.id, identity.id);
    await _pref.setString(_Key.email, identity.email);
    final result = CachedGoogleIdentity(id: identity.id, email: identity.email);
    _logger.info("cached google account state $result");
    return result;
  }

  Future<void> _resetCached() async {
    await _pref.remove(_Key.id);
  }

  Future<void> login() async {
    _logger.fine("got a request to login");
    state = AsyncValue.loading();
    try {
      await _resetCached();
      final data = await getGoogleClientData();
      await _cache(data.identity);
      state = AsyncValue.data(data.identity);
    } catch (e) {
      state = AsyncValue.data(null);
    }
  }

  Future<void> logout() async {
    _logger.fine("got a request to logout");
    state = AsyncValue.loading();
    await signIn.disconnect();
    await _resetCached();
    state = AsyncValue.data(null);
  }
}

class _Key {
  static const prefix = "logged.in";
  static const id = "$prefix.id";
  static const email = "$prefix.email";
}

class CachedGoogleIdentity implements GoogleIdentity {
  @override
  final String id;
  @override
  final String email;
  @override
  final String? displayName = null;
  @override
  final String? photoUrl = null;
  @override
  final String? serverAuthCode = null;

  CachedGoogleIdentity({
    required this.id,
    required this.email,
  });

  @override
  String toString() {
    return '_CachedGoogleIdentity{id: $id, email: $email, displayName: $displayName, photoUrl: $photoUrl, '
        'serverAuthCode: $serverAuthCode}';
  }
}
