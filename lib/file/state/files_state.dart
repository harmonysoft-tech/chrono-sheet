import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logging.dart';

part 'files_state.g.dart';

final _logger = getNamedLogger();

class _Key {
  static const selected = "file.selected";
  static const recentCount = "file.recent.count";
  static const recentN = "file.recent";
}

class FilesInfo {

  final GoogleFile? selected;
  final List<GoogleFile> recent;

  const FilesInfo(this.selected, [this.recent = const []]);
}

@riverpod
class FilesInfoHolder extends _$FilesInfoHolder {

  static const _separator = "___";

  final _prefs = SharedPreferencesAsync();

  @override
  Future<FilesInfo> build() async {
    var selected = _deserialize(
        await _prefs.getString(_Key.selected)
    );
    if (selected == null) {
      return FilesInfo(null);
    }

    var recentCount = await _prefs.getInt(_Key.recentCount);
    if (recentCount == null || recentCount <= 0) {
      return FilesInfo(selected);
    }

    List<GoogleFile> recent = [];
    for (int i = 0; i < recentCount; i++) {
      final file = _deserialize(
          await _prefs.getString("${_Key.recentN}[$i]")
      );
      if (file == null) {
        break;
      } else {
        recent.add(file);
      }
    }
    return FilesInfo(selected, recent);
  }

  void select(GoogleFile file) async {
    _logger.info("file '${file.name}' is now active");
    List<GoogleFile> recent = List.from((await future).recent);
    recent.removeWhere((recentFile) => recentFile.id == file.id);
    state = AsyncValue.data(FilesInfo(file, recent));
    await _prefs.setString(_Key.selected, _serialize(file));
    await _prefs.setInt(_Key.recentCount, recent.length);
    for (int i = 0; i < recent.length; i++) {
      final file = recent[i];
      await _prefs.setString("${_Key.recentN}[$i]", _serialize(file));
    }
  }

  String _serialize(GoogleFile file) {
    return "${file.id}$_separator${file.name}";
  }

  GoogleFile? _deserialize(String? s) {
    if (s == null) {
      return null;
    }
    final i = s.indexOf(_separator);
    if (i <= 0) {
      return null;
    }
    return GoogleFile(s.substring(0, i), s.substring(i + _separator.length));
  }
}