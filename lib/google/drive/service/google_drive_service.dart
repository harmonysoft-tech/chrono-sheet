import 'dart:io';

import 'package:chrono_sheet/google/drive/model/google_file.dart';
import 'package:chrono_sheet/google/account/service/google_http_client_provider.dart';
import 'package:chrono_sheet/google/drive/service/impl/google_drive_service_impl.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_drive_service.g.dart';

@riverpod
GoogleDriveService googleDriveService(Ref ref) {
  http.Client? client = ref.watch(googleHttpClientProvider).value;
  if (client == null) {
    return GoogleDriveServiceImpl(null);
  } else {
    return GoogleDriveServiceImpl(drive.DriveApi(client));
  }
}

abstract interface class GoogleDriveService {

  Future<List<GoogleFile>> list();

  Future<String?> getDirectoryId(String path);

  Future<String> getOrCreateDirectory(String path);

  Future<List<GoogleFile>> listFiles(String directoryId);

  Future<String?> getFileId(String path);

  Future<String> getOrCreateSheetFile(String directoryId, String fileName);

  Future<String> getOrCreateTextFile(String directoryId, String fileName);

  Future<String> getOrCreateFile(
    String directoryId,
    String fileName,
    String mimeType,
    bool retryOnCreationFailure,
  );

  Future<List<int>> getFileContent(String fileId);

  Future<void> uploadImageFile(String parentId, File file);

  Future<void> createOrUpdateTextFile(String directoryId, String fileName, String fileContent);

  Future<void> delete(String entryId);

  Future<void> downloadFile(String fileId, File outputFile);
}
