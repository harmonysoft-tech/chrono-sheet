import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logging.dart';

part 'files_state.g.dart';

final _logger = getNamedLogger();

enum FileOperation { none, creation }

class FilesInfo {
  final GoogleFile? selected;
  final List<GoogleFile> recent;
  final FileOperation operationInProgress;

  const FilesInfo({
    this.selected,
    this.recent = const [],
    this.operationInProgress = FileOperation.none,
  });

  FilesInfo copyWith({
    GoogleFile? selected,
    List<GoogleFile>? recent,
    FileOperation? operationInProgress,
  }) {
    return FilesInfo(
      selected: selected ?? this.selected,
      recent: recent ?? this.recent,
      operationInProgress: operationInProgress ?? this.operationInProgress,
    );
  }
}

class _Key {
  static const selected = "file.selected";
  static const recentCount = "file.recent.count";
  static const recentN = "file.recent";
}

@riverpod
class FilesInfoHolder extends _$FilesInfoHolder {
  static const _separator = "___";
  static const _maxRecentItems = 5;

  final _prefs = SharedPreferencesAsync();

  @override
  Future<FilesInfo> build() async {
    var selected = _deserialize(await _prefs.getString(_Key.selected));
    if (selected == null) {
      return FilesInfo();
    }

    var recentCount = await _prefs.getInt(_Key.recentCount);
    if (recentCount == null || recentCount <= 0) {
      return FilesInfo(selected: selected);
    }

    List<GoogleFile> recent = [];
    for (int i = 0; i < recentCount; i++) {
      final file = _deserialize(await _prefs.getString("${_Key.recentN}[$i]"));
      if (file == null) {
        break;
      } else {
        recent.add(file);
      }
    }
    return FilesInfo(selected: selected, recent: recent);
  }

  Future<void> select(GoogleFile file) async {
    _logger.info("file '${file.name}' is now active");
    final previousState = await future;
    List<GoogleFile> recent = List.from(previousState.recent);
    final previousSelected = previousState.selected;
    if (previousSelected != null) {
      recent.insert(0, previousSelected);
    }
    recent.removeWhere((recentFile) => recentFile.id == file.id);
    if (recent.length > _maxRecentItems) {
      recent.removeRange(_maxRecentItems, recent.length);
    }
    state = AsyncValue.data(FilesInfo(selected: file, recent: recent));
    await _prefs.setString(_Key.selected, _serialize(file));
    await _prefs.setInt(_Key.recentCount, recent.length);
    for (int i = 0; i < recent.length; i++) {
      final file = recent[i];
      await _prefs.setString("${_Key.recentN}[$i]", _serialize(file));
    }
  }

  Future<T> execute<T>(FileOperation operation, Future<T> Function() action) async {
    _logger.info("start executing '$operation' file operation");
    final stateBeforeOperation = await future;
    state = AsyncValue.data(stateBeforeOperation.copyWith(operationInProgress: operation));
    try {
      final result = await action();
      _logger.fine("file operation '$operation' is finished with result $result");
      return result;
    } finally {
      final stateAfterOperation = await future;
      _logger.info("finished '$operation' file operation");
      state = AsyncValue.data(stateAfterOperation.copyWith(operationInProgress: FileOperation.none));
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
