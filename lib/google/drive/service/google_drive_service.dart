import 'dart:convert';
import 'dart:io';

import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';

final _logger = getNamedLogger();

class GoogleDriveService {
  Future<String> getOrCreateDirectory(String path) async {
    final api = await _getApi();
    final pathEntries = path.split("/");
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
        final metaData = drive.File()
          ..name = entry
          ..mimeType = "application/vnd.google-apps.folder"
          ..parents = [result];
        final directory = await api.files.create(metaData);
        result = directory.id!;
      } else {
        result = id;
      }
    }
    return result;
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

  Future<String> getOrCreateTextFile(String directoryId, String fileName) async {
    return await getOrCreateFile(directoryId, fileName, "text/plain", true);
  }

  Future<String> getOrCreateFile(String directoryId, String fileName, String mimeType,
      bool retryOnCreationFailure,) async {
    final api = await _getApi();
    final searchResult = await api.files.list(
      q: "name = '$fileName' and '$directoryId' in parents and mimeType = $mimeType",
      spaces: "drive",
      $fields: "files(id, name)",
    );
    final existing = searchResult.files?.first.id;
    if (existing != null) {
      return existing;
    }

    final metaData = drive.File()
      ..name = fileName
      ..parents = [directoryId];

    final media = drive.Media(
      Stream.empty(),
      0,
      contentType: mimeType,
    );

    try {
      final createdFile = await api.files.create(metaData, uploadMedia: media);
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
    final metaData = drive.File()
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
          await deleteFile(conflicting.first.id);
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
    final googleFile = drive.File()
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
            e, stack
        );
      }
    }
  }

  Future<void> deleteFile(String fileId) async {
    _logger.info("deleting google file $fileId");
    final api = await _getApi();
    api.files.delete(fileId);
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
