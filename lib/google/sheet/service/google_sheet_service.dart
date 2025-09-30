import 'package:chrono_sheet/google/account/service/google_http_client_provider.dart';
import 'package:chrono_sheet/google/drive/model/google_file.dart';
import 'package:chrono_sheet/google/sheet/model/google_sheet_model.dart';
import 'package:chrono_sheet/google/sheet/service/impl/google_sheet_service_impl.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_sheet_service.g.dart';

@riverpod
GoogleSheetService googleSheetService(Ref ref) {
  http.Client? client = ref.watch(googleHttpClientProvider).value;
  if (client == null) {
    return GoogleSheetServiceImpl(null);
  } else {
    return GoogleSheetServiceImpl(SheetsApi(client));
  }
}

abstract interface class GoogleSheetService {

  Future<GoogleSheetInfo> parseSheetDocument(GoogleFile file);

  Map<CellAddress, String> parseSheetValues(List<List<Object?>> values);

  Future<bool> renameCategory({required String from, required String to, required GoogleFile file});

  Future<void> saveMeasurement(int duration, String category, GoogleFile file);

  Future<void> setSheetCellValues({
    required Map<CellAddress, String> values,
    required String sheetTitle,
    required String sheetDocumentId,
    required String sheetFileName,
  });

  CellAddress? parseCellAddress(String s);

  String getCellAddress(int row, int col);
}