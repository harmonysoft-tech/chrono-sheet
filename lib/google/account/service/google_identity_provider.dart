import 'dart:async';
import 'dart:convert';

import 'package:chrono_sheet/google/account/model/google_account.dart';
import 'package:chrono_sheet/google/account/widget/google_account_rationale_widget.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'google_identity_provider.g.dart';

final _logger = getNamedLogger();

final _signIn = GoogleSignIn.instance;
bool signInInitialised = false;
final _scopes = [sheets.SheetsApi.spreadsheetsScope, drive.DriveApi.driveScope];

AppGoogleIdentity? _overriddenData;

final _prefKeyPrefix = "account.google.";
final _pref = SharedPreferencesAsync();
Timer? _resetTimer;

@Riverpod(keepAlive: true)
class GoogleIdentity extends _$GoogleIdentity {
  @override
  Future<AppGoogleIdentity?> build() async {
    final overridden = _overriddenData;
    if (overridden != null) {
      if (state is !AsyncData || state.value == null) {
        state = AsyncValue.data(overridden);
      }
      return overridden;
    }

    final cached = await AppGoogleIdentity.deserializeIfPossible(_pref, _prefKeyPrefix);
    if (cached != null) {
      _resetTimer = Timer(Duration(seconds: cached.ttlInSeconds), () {
        state = AsyncValue.data(null);
      });
      return cached;
    }

    return null;
  }

  Future<Either<String, AppGoogleIdentity>> getAccount(bool allowLogin) async {
    final cachedState = state;
    if (cachedState is AsyncData) {
      final cachedIdentity = cachedState.value;
      if (cachedIdentity != null && cachedIdentity.ttlInSeconds > 0) {
        return Either.right(cachedIdentity);
      }
    }

    final signIn = await _getGoogleSignIn();
    _logger.fine("trying to sign in silently");
    GoogleSignInAccount? googleAccount = await signIn.attemptLightweightAuthentication();
    if (googleAccount == null) {
      _logger.info("failed to sign in silently, signing in normally");
      await GoogleAccountRationaleWidget.show();
      try {
        googleAccount = await signIn.authenticate(scopeHint: _scopes);
      } catch (e, stack) {
        _logger.info("failed to authenticate in google", e, stack);
        return Either.left("failed to authenticate in google");
      }
    }

    GoogleSignInClientAuthorization? auth = await googleAccount.authorizationClient.authorizationForScopes(_scopes);
    if (auth == null) {
      _logger.info("detected that the user didn't provide the following scopes during google login");
      await GoogleAccountRationaleWidget.show();
      try {
        auth = await googleAccount.authorizationClient.authorizeScopes(_scopes);
      } catch (e, stack) {
        _logger.info("failed to get permission for all necessary google scopes", e, stack);
        return Either.left("failed to get permission for all necessary google scopes");
      }
    }

    final expirationInSeconds = await _parseExpirationInSeconds(googleAccount.authentication.idToken!);
    final identity = AppGoogleIdentity(
      id: googleAccount.id,
      email: googleAccount.email,
      accessToken: auth.accessToken,
      accessTokenExpirationInSeconds: expirationInSeconds,
    );
    await identity.serialize(_pref, _prefKeyPrefix);
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(seconds: identity.ttlInSeconds), () {
      state = AsyncValue.data(null);
    });

    state = AsyncValue.data(identity);

    return Either.right(identity);
  }

  Future<GoogleSignIn> _getGoogleSignIn() async {
    if (signInInitialised) {
      return _signIn;
    }
    await _signIn.initialize();
    signInInitialised = true;
    return _signIn;
  }

  Future<int> _parseExpirationInSeconds(String token) async {
    final parts = token.split(".");
    final minPartsNumber = 2;
    if (parts.length < minPartsNumber) {
      throw StateError(
        "can not parse expiration from the given token - expected it to have at least $minPartsNumber, "
        "but it has only ${parts.length}. Token: $token",
      );
    }

    final payload = utf8.fuse(base64).decode(base64.normalize(parts[minPartsNumber - 1]));
    final jwtData = jsonDecode(payload) as Map<String, dynamic>;
    final expirationKey = "exp";
    final result = jwtData[expirationKey];
    if (result is int) {
      return result;
    } else {
      throw StateError(
        "can not parse expiration from the given token - its data is expected to keep the expiration info in the "
        "key '$expirationKey', but the value of that property is '$result'. JWT data: $jwtData",
      );
    }
  }

  Future<void> login() async {
    await getAccount(true);
  }

  Future<void> logout() async {
    final signIn = await _getGoogleSignIn();
    await signIn.disconnect();
    await AppGoogleIdentity.reset(_pref, _prefKeyPrefix);
    state = AsyncValue.data(null);
  }

  static void setDataOverride(AppGoogleIdentity identity) {
    _overriddenData = identity;
  }

  static void resetOverride() {
    _overriddenData = null;
  }
}
