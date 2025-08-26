import 'dart:convert';
import 'dart:io';

import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

final _logger = getNamedLogger();

class GoogleDriveService {
  Future<List<GoogleFile>> list() async {
    final api = await _getApi();
    final searchResult = await api.files.list();
    return searchResult.files?.map((f) => GoogleFile(f.id!, f.name!)).toList() ?? [];
  }

  Future<String?> getDirectoryId(String path) async {
    final api = await _getApi();
    final pathEntries = path.split("/");
    String currentPath = "";
    String result = "root";
    for (final entry in pathEntries) {
      final searchResult = await api.files.list(
        q:
            "name = '$entry' "
            "and '$result' in parents "
            "and mimeType = 'application/vnd.google-apps.folder' "
            "and trashed = false",
        spaces: "drive",
        $fields: "files(id, name)",
      );
      final id = searchResult.files?.firstOrNull?.id;
      if (id == null) {
        _logger.info("failed to find directory '$currentPath' on google drive");
        return null;
      } else {
        _logger.fine("found existing google directory at path '$currentPath', id: '$id'");
        result = id;
        if (currentPath.isNotEmpty) {
          currentPath += "/";
        }
        currentPath += entry;
      }
    }
    return result;
  }

  Future<String> getOrCreateDirectory(String path) async {
    final api = await _getApi();
    final pathEntries = path.split("/");
    String result = "root";
    String currentPath = "";
    for (final entry in pathEntries) {
      if (currentPath.isNotEmpty) {
        currentPath += "/";
      }
      currentPath += entry;
      final query =
          "name = '$entry'"
          " and '$result' in parents"
          " and mimeType = 'application/vnd.google-apps.folder'"
          " and trashed = false";
      final searchResult = await api.files.list(q: query, spaces: "drive", $fields: "files(id, name)");
      final id = searchResult.files?.firstOrNull?.id;
      if (id == null) {
        final metaData =
            drive.File()
              ..name = entry
              ..mimeType = "application/vnd.google-apps.folder"
              ..parents = [result];
        final directory = await api.files.create(metaData);
        _logger.info("created google directory at path '$currentPath', id: '${directory.id}'");
        result = await _ensureUniqueness(api, query);
      } else {
        _logger.info("found existing google directory at path '$currentPath', id: '$result'");
        result = id;
      }
    }
    return result;
  }

  Future<String> _ensureUniqueness(drive.DriveApi api, String query) async {
    // we encountered situations when getOrCreateDirectory() was called for the same path at the same time.
    // Unfortunately, google drive allows to have multiple directories with the same name at the same parent
    // directory, so, we ended up with that situation. That's why we double check the contents and keep
    // only a directory which is created first
    final searchResult = await api.files.list(q: query, spaces: "drive", $fields: "files(id, createdTime)");
    drive.File? result = null;
    final remoteFiles = searchResult.files;
    if (remoteFiles != null) {
      for (final file in remoteFiles) {
        if (result == null) {
          result = file;
        } else if (result.createdTime!.isBefore(file.createdTime!)) {
          _logger.info(
              "detected a race condition for google drive objects matching the query below, detected that the one "
                  "with id '${file.id}' is created after the one with id '${result.id}', so, removing the former. "
                  "Query: $query"
          );
          try {
            await api.files.delete(file.id!);
            _logger.info("deleted google drive entry with id '${file.id}'");
          } catch (ignore) {}
        } else {
          _logger.info(
              "detected a race condition for google drive objects matching the query below, detected that the one "
                  "with id '${result.id}' is created after the one with id '${file.id}', so, removing the former. "
                  "Query: $query"
          );
          try {
            await api.files.delete(result.id!);
            _logger.info("deleted google drive entry with id '${result.id}'");
          } catch (e) {
            // we assume that is might have already be deleted by the concurrent process
          }
          result = file;
        }
      }
    }
    if (result == null) {
      throw StateError("can not find google drive entry for query '$query'");
    } else {
      _logger.info("returning this google id from the uniqueness check: ${result.id}");
      return result.id!;
    }
  }

  Future<List<GoogleFile>> listFiles(String directoryId) async {
    final api = await _getApi();
    final searchResult = await api.files.list(
      q: "'$directoryId' in parents",
      spaces: "drive",
      $fields: "files(id, name)",
    );
    return searchResult.files?.map((f) => GoogleFile(f.id!, f.name!)).toList() ?? [];
  }

  Future<String?> getFileId(String path) async {
    final i = path.lastIndexOf("/");
    List<GoogleFile> files;
    String fileName;
    if (i > 0) {
      final directoryPath = path.substring(0, i);
      final directoryId = await getDirectoryId(directoryPath);
      if (directoryId == null) {
        return null;
      }

      fileName = path.substring(i + 1);
      files = await listFiles(directoryId);
    } else {
      fileName = path;
      files = await list();
    }

    for (final file in files) {
      if (file.name == fileName) {
        return file.id;
      }
    }
    _logger.info("can not get id of the  google file at path '$path', the file does not exist");
    return null;
  }

  Future<String> getOrCreateTextFile(String directoryId, String fileName) async {
    return await getOrCreateFile(directoryId, fileName, "text/plain", true);
  }

  Future<String> getOrCreateFile(
    String directoryId,
    String fileName,
    String mimeType,
    bool retryOnCreationFailure,
  ) async {
    final api = await _getApi();
    final searchResult = await api.files.list(
      q: "name = '$fileName' and '$directoryId' in parents and mimeType = '$mimeType'",
      spaces: "drive",
      $fields: "files(id, name)",
    );
    final existing = searchResult.files?.firstOrNull?.id;
    if (existing != null) {
      return existing;
    }

    final metaData =
        drive.File()
          ..name = fileName
          ..mimeType = mimeType
          ..parents = [directoryId];

    try {
      final createdFile = await api.files.create(metaData);
      return createdFile.id!;
    } catch (e) {
      // if there is a race condition, and the file is created in parallel, we want to retry the search
      if (retryOnCreationFailure) {
        return getOrCreateFile(directoryId, fileName, mimeType, false);
      } else {
        rethrow;
      }
    }
  }

  Future<drive.DriveApi> _getApi() async {
    final data = await getGoogleClientData();
    return drive.DriveApi(data.authenticatedClient);
  }

  Future<List<int>> getFileContent(String fileId) async {
    final api = await _getApi();
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final data = await media.stream.toList();
    return data.expand(identity).toList();
  }

  Future<void> uploadImageFile(String parentId, File file) async {
    await _uploadImageFile(parentId, file, true);
  }

  Future<void> _uploadImageFile(String directoryId, File file, bool deleteOnError) async {
    final api = await _getApi();
    final fileName = p.basename(file.path);
    final metaData =
        drive.File()
          ..name = fileName
          ..parents = [directoryId]
          ..mimeType = "image/jpg";
    final media = drive.Media(file.openRead(), file.lengthSync());
    try {
      await api.files.create(metaData, uploadMedia: media);
    } catch (e, stack) {
      if (deleteOnError) {
        final existingFiles = await listFiles(directoryId);
        final conflicting = existingFiles.where((file) => file.name == fileName);
        if (conflicting.isNotEmpty) {
          await delete(conflicting.first.id);
          _uploadImageFile(directoryId, file, false);
        } else {
          _logger.info("cannot upload file $fileName to google drive and no file with such name is there", e, stack);
        }
      } else {
        _logger.info("cannot upload file $fileName to google drive", e, stack);
      }
    }
  }

  Future<void> createOrUpdateTextFile(String directoryId, String fileName, String fileContent) async {
    _logger.info("got a request to create or update text file with name $fileName in directory with id $directoryId");
    final api = await _getApi();
    final googleFile =
        drive.File()
          ..name = fileName
          ..parents = [directoryId];
    final encodedContent = utf8.encode(fileContent);
    final media = drive.Media(Stream.value(encodedContent), encodedContent.length);
    try {
      await api.files.create(googleFile, uploadMedia: media);
    } catch (e, stack) {
      final existingFiles = await listFiles(directoryId);
      final matching = existingFiles.where((file) => file.name == fileName);
      if (matching.isNotEmpty) {
        final existingFileId = matching.first.id;
        await api.files.update(drive.File(), existingFileId, uploadMedia: media);
      } else {
        _logger.severe(
          "cannot create a google file '$fileName' and no existing file with such name is found on the google drive",
          e,
          stack,
        );
      }
    }
  }

  Future<void> delete(String entryId) async {
    _logger.info("deleting google drive entry $entryId");
    final api = await _getApi();
    api.files.delete(entryId);
  }

  Future<void> downloadFile(String fileId, File outputFile) async {
    _logger.info("downloading file with id $fileId from google drive");
    final api = await _getApi();
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final outputSink = outputFile.openWrite();
    try {
      await media.stream.pipe(outputSink);
    } finally {
      await outputSink.close();
    }
  }
}
