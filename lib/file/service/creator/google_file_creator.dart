import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../google/login/state/google_helper.dart';
import '../../../log/util/log_util.dart';
import '../../../sheet/model/sheet_model.dart';

part "google_file_creator.g.dart";

final _logger = getNamedLogger();

@riverpod
FileCreateService createService(Ref ref) {
  return FileCreateService(ref.read(fileStateManagerProvider.notifier));
}

sealed class FileCreationResult {}

class Created extends FileCreationResult {
  final GoogleFile file;

  Created(this.file);
}

class AlreadyExists extends FileCreationResult {
  final GoogleFile file;

  AlreadyExists(this.file);
}

class Error extends FileCreationResult {
  final String error;

  Error(this.error);
}

class FileCreateService {
  final FileStateManager _filesInfoHolder;

  FileCreateService(this._filesInfoHolder);

  Future<FileCreationResult> create(String name) async {
    return await _filesInfoHolder.execute(FileOperation.creation, () async {
      try {
        final data = await getGoogleClientData();
        final api = DriveApi(data.authenticatedClient);

        final existingFile = await _tryToFindExistingFile(name, api);
        if (existingFile != null) {
          return AlreadyExists(existingFile);
        }

        final fileMetaData = File()
          ..name = name
          ..mimeType = sheetMimeType;
        final gFile = await api.files.create(fileMetaData);
        return Created(GoogleFile(gFile.id!, name));
      } catch (e, stack) {
        _logger.severe("failed to create new google sheet file with name '$name'", e, stack);
        return Error(e.toString());
      }
    });
  }

  Future<GoogleFile?> _tryToFindExistingFile(String name, DriveApi api) async {
    final query = "name = '$name' and trashed = false";
    final fileList = await api.files.list(q: query);
    final files = fileList.files;
    if (files != null && files.isNotEmpty) {
      return GoogleFile(files.first.id!, name);
    } else {
      return null;
    }
  }
}
