import 'dart:io';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

final _logger = getNamedLogger();

Future<File?> Function(BuildContext context, String category) selectCategoryIcon = (
    BuildContext context,
    String category,
) async {
  final l10n = AppLocalizations.of(context);
  final haveNecessaryPermissions = await _ensureFileSelectionPermissions(context, category);
  if (!haveNecessaryPermissions) {
    return null;
  }

  final originalImageFilePath = await _selectFile(l10n);
  if (originalImageFilePath == null) {
    return null;
  }

  final croppedFile = await _cropImage(originalImageFilePath, l10n);
  if (croppedFile == null) {
    _logger.info("cannot get cropped file");
    return null;
  }

  final fileToStore = File("${AppPaths.categoryIconDataDir}/${Uuid().v4()}.jpg");
  fileToStore.createSync(recursive: true);
  await File(croppedFile.path).copy(fileToStore.path);
  return fileToStore;
};

Future<bool> _ensureFileSelectionPermissions(BuildContext context, String category) async {
  final l10n = AppLocalizations.of(context);
  if (Platform.isAndroid) {
    if (await Permission.storage.request().isGranted) {
      // for android < 13
      _logger.info("detected that permission ${Permission.storage} is granted");
      return true;
    } else if (await Permission.mediaLibrary.request().isGranted) {
      // for android >= 13
      _logger.info("detected that permission ${Permission.mediaLibrary} is granted");
      return true;
    } else {
      _logger.info("do not have necessary permissions for icon selection");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.errorNeedPermissionForCategoryIcon),
        ));
      } else {
        _logger.info("skipped icon selection for category '$category' - permission is not granted "
            "and the build context is not mounted");
      }
      return false;
    }
  } else {
    return true;
  }
}

Future<String?> _selectFile(AppLocalizations l10n) async {
  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.titleChooseCategoryImage,
      type: FileType.image,
    );
    if (result == null) {
      _logger.info("no icon file is selected");
      return null;
    }
    final path = result.files.single.path;
    if (path == null) {
      _logger.info("no path is available after image selection, selection result: $result");
      return null;
    } else {
      return path;
    }
  } catch (e, stack) {
    _logger.info("unexpected exception on attempt to select a file", e, stack);
    return null;
  }
}

Future<CroppedFile?> _cropImage(String originalImageFilePath, AppLocalizations l10n) async {
  return await ImageCropper().cropImage(
    sourcePath: originalImageFilePath,
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: l10n.titleCropImage,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.square,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
      ),
      IOSUiSettings(
        title: l10n.titleCropImage,
        aspectRatioLockEnabled: true,
        aspectRatioPickerButtonHidden: true,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
      ),
    ],
  );
}


