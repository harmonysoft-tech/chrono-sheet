import 'package:shared_preferences/shared_preferences.dart';

class _Key {

  static String getId(String prefix) {
    return "$prefix.id";
  }

  static String getName(String prefix) {
    return "$prefix.name";
  }
}

class GoogleFile {

  final String id;
  final String name;

  const GoogleFile(this.id, this.name);

  Future<void> storeInPrefs(String keyPrefix, SharedPreferencesAsync prefs) async {
    await prefs.setString(_Key.getId(keyPrefix), id);
    await prefs.setString(_Key.getName(keyPrefix), name);
  }

  static Future<GoogleFile?> readFromPrefs(String keyPrefix, SharedPreferencesAsync prefs) async {
    String? id = await prefs.getString(_Key.getId(keyPrefix));
    if (id == null) {
      return null;
    }

    String? name = await prefs.getString(_Key.getName(keyPrefix));
    if (name == null) {
      return null;
    }

    return GoogleFile(id, name);
  }

  @override
  String toString() {
    return 'GoogleFile{id: $id, name: $name}';
  }
}