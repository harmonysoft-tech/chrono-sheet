import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v3.dart';
import '../../../google/google_helper.dart';

final _logger = getNamedLogger();

Future<FileList> fetchSheets(String? pageToken) async {
  final client = await getAuthenticatedGoogleApiHttpClient();
  final driveApi = drive.DriveApi(client);
  return driveApi.files.list(
      q: "mimeType='$sheetMimeType'",
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageToken: pageToken);
}

class PaginatedFilesState {

  final List<GoogleFile> files;
  final bool loading;
  final String? nextPageToken;
  final String? error;

  PaginatedFilesState({
    required this.files,
    required this.loading,
    this.nextPageToken,
    this.error
  });

  PaginatedFilesState copyWith({
    List<GoogleFile>? files,
    bool? loading,
    String? nextPageToken,
    String? error,
  }) {
    return PaginatedFilesState(
      files: files ?? this.files,
      loading: loading ?? this.loading,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      error: error ?? this.error
    );
  }
}

final paginatedFilesProvider = StateNotifierProvider<PaginatedFilesNotifier, PaginatedFilesState>((ref) {
  return PaginatedFilesNotifier();
});

class PaginatedFilesNotifier extends StateNotifier<PaginatedFilesState> {

  PaginatedFilesNotifier() : super(PaginatedFilesState(
      files: [],
      loading: false
  ));

  Future<void> loadFiles({initialLoad = false}) async {
    if (state.loading) {
      return;
    }
    if (!initialLoad && state.nextPageToken == null) {
      return;
    }
    state = state.copyWith(loading: true);
    final errors = <String>[];
    final files = <GoogleFile>[];
    _logger.info(
        "fetching gsheet documents, next page token: ${state.nextPageToken}"
    );
    try {
      final fileList = await fetchSheets(initialLoad ? null : state.nextPageToken);
      _logger.info(
          "got google response for ${fileList.files?.length ?? 0} gsheet files"
      );

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
      _logger.warning(
          "got an exception on attempt to fetch gsheets", e, stackTrace
      );
      errors.add("$e\n$stackTrace");
    }

    _logger.info(
        "got ${files.length} gsheet file(s) and ${errors.length} error(s)"
    );
    state = state.copyWith(
      files: files,
      loading: false,
      nextPageToken: null,
      error: errors.isEmpty ? null : errors.join(",\n")
    );
  }
}