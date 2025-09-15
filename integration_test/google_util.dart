import 'dart:io';

import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:collection/collection.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

late drive.DriveApi driveApi;

main() async {
  driveApi = await init();
  await list();
  // await create();
  // await createImage();
}

Future<drive.DriveApi> init() async {
  final file = File("/Users/denis/project/my/chrono-sheet/test_common/auto-test-service-account1.json");
  final json = await file.readAsString();
  final credentials = ServiceAccountCredentials.fromJson(json);
  final scopes = [
    SheetsApi.spreadsheetsScope,
    SheetsApi.driveFileScope,
    drive.DriveApi.driveScope,
    drive.DriveApi.driveMetadataReadonlyScope,
  ];
  final client = await clientViaServiceAccount(credentials, scopes);
  return drive.DriveApi(client);
}

String getPath(Map<String, String> name2id, Map<String, String> id2parentId, String id, String name) {
  String? parentId = id2parentId[id];
  if (parentId == null) {
    return name;
  }
  String? parentName = name2id.entries.firstWhereOrNull((e) => e.value == parentId)?.key;
  if (parentName == null) {
    return name;
  } else {
    final parentPath = getPath(name2id, id2parentId, parentId, parentName);
    if (parentPath == "/") {
      return "/$name";
    } else {
      return "$parentPath/$name";
    }
  }
}

list() async {
  // final mime = "mimeType = 'application/vnd.google-apps.folder' and trashed = false";
  final mime = "trashed = false";
  // final mime = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '1YXCc5emqtUYc-bL9VMR62tv2CuEGsRM7' in parents";
  // "name = '$fileName' and '$directoryId' in parents and mimeType = $mimeType"
  // final mime = "name = 'fe17c817-71b0-43bc-a3cb-4f6eda8e3258' and mimeType = '$sheetMimeType' and trashed = false and '1VKamhq5_X64Md_ehg9-Ppc5AOzm4K6Hs' in parents";
  // final mime = "name = 'fe17c817-71b0-43bc-a3cb-4f6eda8e3258' and '1WvvNvewcVS8wA3ro367aTElu9sO2bH-J' in parents and mimeType = application/vnd.google-apps.spreadsheet";
  final rootResult = await driveApi.files.get("root", $fields: "id") as drive.File;
  final rootId = rootResult.id!;
  final name2id = <String, String>{};
  final id2parentId = <String, String>{};
  name2id["/"] = rootId;
  final fileList = await driveApi.files.list(q: mime, spaces: 'drive', $fields: "files(id, name, parents, mimeType)");
  print("found ${fileList.files?.length ?? 0} entries");
  for (var file in fileList.files ?? []) {
    name2id[file.name] = file.id;
    final parentId = file.parents?.first;
    if (parentId != null) {
      id2parentId[file.id!] = parentId;
    }
  }
  for (drive.File file in fileList.files ?? []) {
    print('${getPath(name2id, id2parentId, file.id!, file.name!)}: ${file.id} ${file.mimeType}');
    // await driveApi.files.delete(file.id!);
    // print("deleted entry '${file.name}'");
  }
}

createSheet() async {
  final dirId = "1YXCc5emqtUYc-bL9VMR62tv2CuEGsRM7";
  final metaData =
      drive.File()
        ..name = dirId
        ..mimeType = sheetMimeType
        ..parents = [dirId];

  final createdFile = await driveApi.files.create(metaData);
  print('created file with id $createdFile');
}

createImage() async {
  final dirId = "1V7_LgPizSVNuYLks6HrCCcp0sFFFxaYM";
  final remoteFile = drive.File()
    ..name = "image1.png"
    ..parents = [dirId]
    ..mimeType = "image/png";

  final file = File("/Users/denis/project/my/chrono-sheet/integration_test/icon/icon1.png");
  final media = drive.Media(file.openRead(), file.lengthSync());
  await driveApi.files.create(remoteFile, uploadMedia: media);
  print('uploaded image file from ${file.path}');
}
