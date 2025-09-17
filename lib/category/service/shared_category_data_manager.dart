import 'dart:convert';
import 'dart:io';

import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/category.dart';
import '../../google/drive/service/google_drive_service.dart';
import '../../log/util/log_util.dart';
import '../../network/network.dart';
import '../../ui/path.dart';
import '../../util/date_util.dart';
import '../model/icon_info.dart';

part "category_manager.g.dart";

final _logger = getNamedLogger();

typedef _CategoriesToInfo = Map<String, IconInfo>;

@Riverpod(keepAlive: true)
SharedCategoryDataManager categoryManager(Ref ref) {
  return SharedCategoryDataManager();
}

class _Key {
  static const categoryPrefix = "category.common";

  static String getCategory(String categoryName) {
    return "$categoryPrefix.$categoryName";
  }

  static const directoryPrefix = "category.icon.google.directory";

  static String getDirectory(String path) {
    return "$directoryPrefix.$path";
  }
}

String _rootDirPath = ".chrono-sheet/picture/category";
String? _rootDirPathOverride = null;

setCategoryGoogleRootDirPathOverride(String rootPathToUse) {
  _rootDirPathOverride = rootPathToUse;
}

resetCategoryRootDirPathOverride() {
  _rootDirPathOverride = null;
}

class CategoryGooglePaths {
  static String get rootDirPathToUse => _rootDirPathOverride ?? _rootDirPath;

  static String get mappingDirPath => "$rootDirPathToUse/mapping";

  static String get picturesDirPath => "$rootDirPathToUse/pictures";
}

class SharedCategoryDataManager {
  final _prefs = SharedPreferencesAsync();
  final driveService = GoogleDriveService();
  DateTime? _startTime;

  Future<Category?> getCategory(String categoryName) async {
    return await Category.deserialiseIfPossible(_prefs, _Key.getCategory(categoryName));
  }

  Future<void> tick([bool force = false]) async {
    final start = _startTime;
    final now = clockProvider.now();
    if (!force && start != null) {
      final diff = now.difference(start);
      if (diff.inMinutes < 10) {
        _logger.info(
          "skipped category manager tick because only ${diff.inMinutes} minutes elapsed since the last check",
        );
        return;
      }
    }

    var online = await isOnline();
    if (!online) {
      _logger.info("skipped picture manager tick because the application is offline");
      return;
    }

    _logger.info("checking if we need to sync local and remote categories info");
    _startTime = now;
    try {
      await _handlePendingCategoryRenames();
      final remote = await _getRemoteInfo();
      final local = await _getLocalInfo();
      await Future.wait([_uploadLocalIcons(local, remote), _processRemoteIcons(local, remote)]);
    } catch (e, stack) {
      online = await isOnline();
      if (online) {
        _logger.severe("unexpected exception on processing picture manager tick", e, stack);
        final allKeys = await _prefs.getKeys();
        final keysToDrop = allKeys.where((key) => key.startsWith(_Key.directoryPrefix));
        for (final key in keysToDrop) {
          await _prefs.remove(key);
        }
      }
    }
  }

  Future<_CategoriesToInfo> _getRemoteInfo() async {
    _logger.info("start fetching remote categories infos");
    final directoryId = await _getGoogleDirectoryId(CategoryGooglePaths.mappingDirPath);
    final driveFiles = await driveService.listFiles(directoryId);
    final result = <String, IconInfo>{};
    for (final file in driveFiles) {
      final raw = await driveService.getFileContent(file.id);
      final text = utf8.decode(raw).trim();
      final parseResult = IconInfo.parse(text);
      parseResult.fold(
        (error) async {
          _logger.info(
            "detected that google category icon mapping file $file has incorrect content format, deleting it - $error",
          );
          await driveService.delete(file.id);
        },
        (info) {
          final categoryName = p.basenameWithoutExtension(file.name);
          result[categoryName] = info;
        },
      );
    }
    return result;
  }

  Future<String> _getGoogleDirectoryId(String path) async {
    final cached = await _prefs.getString(_Key.getDirectory(path));
    if (cached != null) {
      return cached;
    }
    final result = await driveService.getOrCreateDirectory(path);
    await _prefs.setString(_Key.getDirectory(path), result);
    return result;
  }

  Future<_CategoriesToInfo> _getLocalInfo() async {
    final rootDir = _getLocalDataDir();
    if (!rootDir.existsSync()) {
      _logger.fine("local category data directory ${rootDir.path} doesn't exist");
      return {};
    }

    final files = rootDir.listSync();
    final Map<String, IconInfo> result = {};
    _logger.fine("found ${files.length} category mapping file(s) in directory ${rootDir.path}");
    for (final file in files) {
      if (file is File) {
        final categoryName = p.basename(file.path);
        final info = _tryParseLocalInfoFile(categoryName, file);
        if (info != null) {
          result[categoryName] = info;
        }
      }
    }
    return result;
  }

  Directory _getLocalDataDir() {
    return Directory("${AppPaths.categoryIconRootDir}/mapping");
  }

  IconInfo? _tryParseLocalInfoFile(String categoryName, File file) {
    final text = file.readAsStringSync();
    final i = text.indexOf(",");
    if (i <= 0) {
      _logger.info(
        "local category picture file format is incorrect for category $categoryName and file ${file.path}:\n$text",
      );
      file.deleteSync();
      return null;
    }
    final path = text.substring(0, i);
    final iconFile = File(path);
    if (!iconFile.existsSync()) {
      _logger.info(
        "detected that category info for category '$categoryName' points to the file $path "
        "but it doesn't exist, removing it then",
      );
      file.deleteSync();
      return null;
    }
    final time = DateTime.tryParse(text.substring(i + 1));
    if (time == null) {
      _logger.info(
        "detected that category info for category '$categoryName' points to the file $path "
        "but it doesn't have time info, removing it then",
      );
      file.deleteSync();
      return null;
    }
    return IconInfo(fileName: path, activationTime: time);
  }

  Future<void> _handlePendingCategoryRenames() async {
    // TODO implement
  }

  Future<void> _uploadLocalIcons(_CategoriesToInfo local, _CategoriesToInfo remote) async {
    final Map<String, DateTime> remoteFiles = {for (final info in remote.values) info.fileName: info.activationTime};
    final Map<String /* category name */, String /* category icon file name */> toUpload = {};
    local.forEach((categoryName, iconInfo) {
      final filePath = iconInfo.fileName;
      final fileName = p.basename(filePath);
      final remoteUpdateTime = remoteFiles[fileName];
      if (remoteUpdateTime == null || iconInfo.activationTime.isAfter(remoteUpdateTime)) {
        toUpload[categoryName] = filePath;
      }
    });
    _logger.info("found ${toUpload.length} icon file(s) to upload: $toUpload");
    final picturesDirectoryId = await _getGoogleDirectoryId(CategoryGooglePaths.picturesDirPath);
    final mappingDirectoryId = await _getGoogleDirectoryId(CategoryGooglePaths.mappingDirPath);
    toUpload.forEach((categoryName, iconFilePath) async {
      await driveService.uploadImageFile(picturesDirectoryId, File(iconFilePath));
      final fileName = p.basename(iconFilePath);
      final content = "$fileName,${clockProvider.now().toIso8601String()}";
      await driveService.createOrUpdateTextFile(mappingDirectoryId, "$categoryName.csv", content);
    });
  }

  Future<void> _processRemoteIcons(_CategoriesToInfo local, _CategoriesToInfo remote) async {
    final Map<String /* category name */, String /* google file name */> toDownload = {};
    remote.forEach((categoryName, remoteIconInfo) {
      final localIconInfo = local[categoryName];
      if (localIconInfo == null ||
          localIconInfo.fileName != remoteIconInfo.fileName ||
          localIconInfo.activationTime.isBefore(remoteIconInfo.activationTime)) {
        toDownload[categoryName] = remoteIconInfo.fileName;
      }
    });
    _logger.info("found ${toDownload.length} remote category icon(s) to download: ${toDownload.keys.join(", ")}");
    final picturesDirectoryId = await _getGoogleDirectoryId(CategoryGooglePaths.picturesDirPath);
    final remoteFiles = await driveService.listFiles(picturesDirectoryId);
    final remoteFilesByName = {for (final file in remoteFiles) file.name: file};
    final localDataDir = _getLocalDataDir();
    final futures = toDownload.entries.map((entry) async {
      final file = remoteFilesByName[entry.key];
      if (file == null) {
        _logger.severe(
          "cannot download data for category '${entry.key}' - no file with such name is found in google drive",
        );
      } else {
        final dataFile = File("${localDataDir.path}/${entry.value}");
        if (!dataFile.existsSync()) {
          dataFile.createSync(recursive: true);
        }
        return driveService.downloadFile(file.id, dataFile);
      }
    });
    await Future.wait(futures);
  }

  Future<void> onNewCategory(Category category) async {
    _logger.fine("got information about new category '$category'");
    await category.serialize(_prefs, _Key.getCategory(category.name));
    final representation = category.representation;
    if (representation is! ImageCategoryRepresentation) {
      _logger.fine("skip new category processing as it doesn't have image representations: $category");
      return;
    }
    final iconFile = representation.file;
    final mappingFile = File("${_getLocalDataDir().path}/${category.name}");
    final parentDir = mappingFile.parent;
    if (mappingFile.existsSync()) {
      mappingFile.deleteSync();
      _logger.fine("deleted previous local category mapping file for category '${category.name}': ${mappingFile.path}");
    } else if (!parentDir.existsSync()) {
      await parentDir.create(recursive: true);
      _logger.info("created a local directory for storing categories meta info: ${parentDir.path}");
    }
    final content = "${iconFile.path},${clockProvider.now().toIso8601String()}";
    mappingFile.writeAsStringSync(content);
    _logger.info(
      "wrote category meta info for category '${category.name}' into local file ${mappingFile.path}: $content",
    );
    await tick(true);
  }

  Future<void> onReplaceCategory(Category from, Category to) async {
    // TODO implement
    await to.serialize(_prefs, _Key.getCategory(to.name));
  }
}
