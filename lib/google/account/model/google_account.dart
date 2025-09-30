import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppGoogleIdentity implements GoogleIdentity {
  @override
  final String id;
  @override
  final String email;
  @override
  final String? displayName = null;
  @override
  final String? photoUrl = null;

  final String accessToken;
  final int accessTokenExpirationInSeconds;

  int get ttlInSeconds {
    final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return accessTokenExpirationInSeconds - nowInSeconds;
  }

  AppGoogleIdentity({
    required this.id,
    required this.email,
    required this.accessToken,
    required this.accessTokenExpirationInSeconds,
  });

  static Future<void> reset(SharedPreferencesAsync prefs, String keyPrefix) async {
    await prefs.remove(_getAccessTokenExpirationInSecondsKey(keyPrefix));
  }

  static Future<AppGoogleIdentity?> deserializeIfPossible(SharedPreferencesAsync prefs, String keyPrefix) async {
    final accessTokenExpirationInSeconds = await prefs.getInt(_getAccessTokenExpirationInSecondsKey(keyPrefix));
    if (accessTokenExpirationInSeconds == null) {
      return null;
    }
    final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (accessTokenExpirationInSeconds < nowInSeconds) {
      await reset(prefs, keyPrefix);
      return null;
    }

    final id = await prefs.getString(_getIdKey(keyPrefix));
    if (id == null || id.isEmpty) {
      await reset(prefs, keyPrefix);
      return null;
    }
    final email = await prefs.getString(_getEmailKey(keyPrefix));
    if (email == null || email.isEmpty) {
      await reset(prefs, keyPrefix);
      return null;
    }
    final accessToken = await prefs.getString(_getAccessTokenKey(keyPrefix));
    if (accessToken == null) {
      await reset(prefs, keyPrefix);
      return null;
    }

    return AppGoogleIdentity(
      id: id,
      email: email,
      accessToken: accessToken,
      accessTokenExpirationInSeconds: accessTokenExpirationInSeconds,
    );
  }

  Future<void> serialize(SharedPreferencesAsync prefs, String keyPrefix) async {
    await prefs.setString(_getIdKey(keyPrefix), id);
    await prefs.setString(_getEmailKey(keyPrefix), email);
    await prefs.setString(_getAccessTokenKey(keyPrefix), accessToken);
    await prefs.setInt(_getAccessTokenExpirationInSecondsKey(keyPrefix), accessTokenExpirationInSeconds);
  }

  static String _getIdKey(String prefix) {
    return "$prefix.id";
  }

  static String _getEmailKey(String prefix) {
    return "$prefix.email";
  }

  static String _getAccessTokenKey(String prefix) {
    return "$prefix.accessToken";
  }

  static String _getAccessTokenExpirationInSecondsKey(String prefix) {
    return "$prefix.accessTokenExpirationInSeconds";
  }

  @override
  String toString() {
    return '_CachedGoogleIdentity{id: $id, email: $email, displayName: $displayName, photoUrl: $photoUrl}';
  }
}
