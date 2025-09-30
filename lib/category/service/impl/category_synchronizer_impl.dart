import 'dart:convert';
import 'dart:io';

import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/category/model/icon_info.dart';
import 'package:chrono_sheet/category/service/category_synchronizer.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/network/network.dart';
import 'package:chrono_sheet/ui/path.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

final _logger = getNamedLogger();

typedef _CategoriesToInfo = Map<String, IconInfo>;

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
String? _rootDirPathOverride;

void setCategoryGoogleRootDirPathOverride(String rootPathToUse) {
  _rootDirPathOverride = rootPathToUse;
}

void resetCategoryRootDirPathOverride() {
  _rootDirPathOverride = null;
}

class CategoryGooglePaths {
  static String get rootDirPathToUse => _rootDirPathOverride ?? _rootDirPath;

  static String get metaInfoDirPath => "$rootDirPathToUse/meta-info";

  static String get picturesDirPath => "$rootDirPathToUse/pictures";
}

class CategorySynchronizerImpl implements CategorySynchronizer {
  final _prefs = SharedPreferencesAsync();
  final GoogleDriveService driveService;
  DateTime? _startTime;

  CategorySynchronizerImpl(this.driveService);

  @override
  Future<Category?> getCategory(String categoryName) async {
    return await Category.deserializeIfPossible(_prefs, _Key.getCategory(categoryName));
  }

  @override
  Future<void> synchronizeIfNecessary([bool force = false]) async {
    final start = _startTime;
    final now = clockProvider.now();
    if (!force && start != null) {
      final diff = now.difference(start);
      final minutesUntilNextCheck = 10 - diff.inMinutes;
      if (diff.inMinutes > 0) {
        _logger.info(
          "skipped category manager tick because only ${diff.inMinutes} minutes elapsed since the last check, "
              "need to wait at least $minutesUntilNextCheck minutes more",
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
    final directoryId = await _getGoogleDirectoryId(CategoryGooglePaths.metaInfoDirPath);
    final driveFiles = await driveService.listFiles(directoryId);
    final result = <String, IconInfo>{};
    for (final file in driveFiles) {
      final raw = await driveService.getFileContent(file.id);
      final text = utf8.decode(raw).trim();
      final parseResult = IconInfo.parse(text);
      parseResult.match(
            (error) async {
          _logger.info(
            "detected that google category icon meta-info file $file has incorrect content format, deleting it - $error",
          );
          await driveService.delete(file.id);
        },
            (info) {
          final categoryName = p.basenameWithoutExtension(file.name);
          result[categoryName] = info;
        },
      );
    }
    _logger.info("fetched the following remote categories info: $result");
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
      _logger.info("local category data directory ${rootDir.path} doesn't exist");
      return {};
    }

    final files = rootDir.listSync();
    final Map<String, IconInfo> result = {};
    _logger.info("found ${files.length} category meta-info file(s) in directory ${rootDir.path}");
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
    return Directory("${AppPaths.categoryIconRootDir}/meta-info");
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
    final metaInfoDirectoryId = await _getGoogleDirectoryId(CategoryGooglePaths.metaInfoDirPath);
    toUpload.forEach((categoryName, iconFilePath) async {
      await driveService.uploadImageFile(picturesDirectoryId, File(iconFilePath));
      final fileName = p.basename(iconFilePath);
      final content = "$fileName,${clockProvider.now().toIso8601String()}";
      await driveService.createOrUpdateTextFile(metaInfoDirectoryId, "$categoryName.csv", content);
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

  File _getCategoryMetaInfoFile(String categoryName) {
    return File("${_getLocalDataDir().path}/$categoryName");
  }

  Future<void> _storeCategoryWithIconLocally(Category category, ImageCategoryRepresentation representation) async {
    final iconFile = representation.file;
    final metaInfoFile = _getCategoryMetaInfoFile(category.name);
    final parentDir = metaInfoFile.parent;
    if (metaInfoFile.existsSync()) {
      metaInfoFile.deleteSync();
      _logger.fine("deleted previous local category meta-info file for category '${category.name}': ${metaInfoFile.path}");
    } else if (!parentDir.existsSync()) {
      await parentDir.create(recursive: true);
      _logger.info("created a local directory for storing categories meta info: ${parentDir.path}");
    }
    final content = "${iconFile.path},${clockProvider.now().toIso8601String()}";
    metaInfoFile.writeAsStringSync(content);
    _logger.info(
      "wrote category meta info for category '${category.name}' into local file ${metaInfoFile.path}: $content",
    );
  }

  @override
  Future<void> onNewCategory(Category category) async {
    _logger.fine("got information about new category '$category'");
    await category.serialize(_prefs, _Key.getCategory(category.name));
    final representation = category.representation;
    if (representation is! ImageCategoryRepresentation) {
      _logger.fine("skip new category processing as it doesn't have image representations: $category");
      return;
    }
    await _storeCategoryWithIconLocally(category, representation);
    await synchronizeIfNecessary(true);
  }

  @override
  Future<void> onReplaceCategory(Category from, Category to) async {
    await to.serialize(_prefs, _Key.getCategory(to.name));
    final newRepresentation = to.representation;
    if (newRepresentation is ImageCategoryRepresentation && newRepresentation != from.representation) {
      await _storeCategoryWithIconLocally(to, newRepresentation);
    }
    await synchronizeIfNecessary(true);
  }
}
