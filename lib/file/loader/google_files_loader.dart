import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../http/AuthenticatedHttpClient.dart';

Future<FileList> fetchSheets(String? pageToken) async {
  final signIn = GoogleSignIn(scopes: [
    sheets.SheetsApi.spreadsheetsScope,
    sheets.SheetsApi.driveReadonlyScope
  ]);
  var googleAccount = await signIn.signIn();
  if (googleAccount == null) {
    throw StateError("can not login into google");
  }
  final headers = await googleAccount.authHeaders;
  final client = AuthenticatedHttpClient(headers);
  final driveApi = drive.DriveApi(client);
  return driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.spreadsheet'",
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
    try {
      final fileList = await fetchSheets(initialLoad ? null : state.nextPageToken);
      fileList.files?.forEach((file) {
        final id = file.id;
        if (id == null) {
          errors.add("can not get id of google file ${file.toJson()}");
          return;
        }
        final name = file.name;
        if (name == null) {
          errors.add("can not get name of google file ${file.toJson()}");
          return;
        }
        files.add(GoogleFile(id, name));
      });
    } catch (e, stackTrace) {
      errors.add("$e\n$stackTrace");
    }

    state = state.copyWith(
      files: files,
      loading: false,
      nextPageToken: null,
      error: errors.isEmpty ? null : errors.join(",\n")
    );
  }
}