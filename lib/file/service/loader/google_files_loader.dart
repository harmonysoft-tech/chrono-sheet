import 'package:chrono_sheet/google/drive/model/google_file.dart';
import 'package:chrono_sheet/google/account/service/google_http_client_provider.dart';
import 'package:chrono_sheet/google/sheet/model/google_sheet_model.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_files_loader.g.dart';

final _logger = getNamedLogger();

class PaginatedFilesState {
  final List<GoogleFile> files;
  final bool loading;
  final String? nextPageToken;
  final String? error;

  PaginatedFilesState({required this.files, required this.loading, this.nextPageToken, this.error});

  PaginatedFilesState copyWith({List<GoogleFile>? files, bool? loading, String? nextPageToken, String? error}) {
    return PaginatedFilesState(
      files: files ?? this.files,
      loading: loading ?? this.loading,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      error: error ?? this.error,
    );
  }
}

@riverpod
class GoogleFilesLoader extends _$GoogleFilesLoader {
  @override
  PaginatedFilesState build() {
    return PaginatedFilesState(files: [], loading: false);
  }

  Future<void> loadFiles({bool initialLoad = false}) async {
    if (state.loading) {
      return;
    }
    if (!initialLoad && state.nextPageToken == null) {
      return;
    }
    state = state.copyWith(loading: true);
    final errors = <String>[];
    final files = <GoogleFile>[];
    _logger.info("fetching gsheet documents, next page token: ${state.nextPageToken}");
    try {
      final fileList = await _fetchSheets(initialLoad ? null : state.nextPageToken);
      _logger.info("got google response for ${fileList.files?.length ?? 0} gsheet file(s)");

      fileList.files?.forEach((file) {
        final id = file.id;
        if (id == null) {
          final error = "can not get id of google file ${file.toJson()}";
          _logger.severe(error);
          errors.add(error);
          return;
        }
        final name = file.name;
        if (name == null) {
          final error = "can not get name of google file ${file.toJson()}";
          _logger.severe(error);
          errors.add(error);
          return;
        }
        files.add(GoogleFile(id, name));
      });
    } catch (e, stackTrace) {
      _logger.warning("got an exception on attempt to fetch gsheets", e, stackTrace);
      errors.add("$e\n$stackTrace");
    }

    _logger.info("got ${files.length} gsheet file(s) and ${errors.length} error(s)");
    state = state.copyWith(
      files: files,
      loading: false,
      nextPageToken: null,
      error: errors.isEmpty ? null : errors.join(",\n"),
    );
  }

  Future<FileList> _fetchSheets(String? pageToken) async {
    final http = await ref.read(googleHttpClientProvider.future);
    if (http == null) {
      return drive.FileList();
    } else {
      final driveApi = drive.DriveApi(http);
      return driveApi.files.list(
        q: "mimeType='$sheetMimeType' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
        pageToken: pageToken,
      );
    }
  }
}
