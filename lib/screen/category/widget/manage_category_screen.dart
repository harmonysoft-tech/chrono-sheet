import 'dart:io';

import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/category/state/category_state.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../category/model/category.dart';
import '../../../generated/app_localizations.dart';
import '../../../ui/dimension.dart';
import '../../../ui/path.dart';

final _logger = getNamedLogger();

class ManageCategoryScreen extends ConsumerStatefulWidget {
  final Category? category;

  const ManageCategoryScreen({super.key, this.category});

  @override
  ConsumerState createState() => ManageCategoryScreenState();
}

class ManageCategoryScreenState extends ConsumerState<ManageCategoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textRepresentationController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  File? _iconFile;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      switch (category.representation) {
        case TextCategoryRepresentation(text: final t):
          _textRepresentationController.text = t;
        case ImageCategoryRepresentation(file: final f):
          _iconFile = f;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textRepresentationController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectIcon(BuildContext context, double edgeSize) async {
    final l10n = AppLocalizations.of(context);
    final haveNecessaryPermissions = await _ensureFileSelectionPermissions(context);
    if (!haveNecessaryPermissions) {
      return;
    }

    final path = await _selectFile(l10n);
    if (path == null) {
      return;
    }
    // TODO refactor
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10n.titleCropImage,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
        // TODO implement for iOS
      ],
    );
    if (croppedFile == null) {
      _logger.info("cannot get cropped file");
      return;
    }

    final fileToStore = File("${AppPaths.categoryIconDir}/${Uuid().v4()}.jpg");
    fileToStore.createSync(recursive: true);
    await File(croppedFile.path).copy(fileToStore.path);
    if (context.mounted) {
      setState(() {
        _iconFile = fileToStore;
      });
    } else {
      _logger.info("skipped icon selection for category '${_nameController.text}' - the build context is not mounted");
    }
  }

  Future<bool> _ensureFileSelectionPermissions(BuildContext context) async {
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
          _logger.info(
              "skipped icon selection for category '${_nameController.text}' - permission is not granted "
                  "and the build context is not mounted"
          );
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

  Future<void> _saveCategoryIfPossible(BuildContext context, CategoryStateManager stateManager) async {
    final l10n = AppLocalizations.of(context);
    final categoryName = _nameController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.errorCategoryNameMustBeProvided),
      ));
      return;
    }

    final CategoryRepresentation representation;
    final file = _iconFile;
    if (file == null) {
      representation = TextCategoryRepresentation(categoryName);
    } else {
      representation = ImageCategoryRepresentation(file);
    }

    final Category newCategory = Category(
      name: categoryName,
      representation: representation,
    );
    final originalCategory = widget.category;
    final SaveCategoryResult saveResult;
    if (originalCategory == null) {
      saveResult = await stateManager.addNewCategory(newCategory);
    } else {
      saveResult = await stateManager.replaceCategory(originalCategory, newCategory);
    }
    if (context.mounted) {
      if (saveResult == SaveCategoryResult.success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.errorCategoryNameMustBeUnique),
        ));
      }
    } else {
      _logger.info("cannot handle category save attempt for category '$categoryName' "
          "($saveResult) - the build context is not mounted");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labelTheme = theme.textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? l10n.titleCreateCategory : l10n.titleEditCategory),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimension.screenPadding),
        child: Column(
          children: [
            Row(
              children: [
                Text(l10n.labelName, style: labelTheme),
                SizedBox(
                  width: AppDimension.elementPadding,
                ),
                Expanded(
                  child: TextField(
                    focusNode: _nameFocusNode,
                    controller: _nameController,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: AppDimension.elementPadding,
            ),
            Row(
              children: [
                Text(l10n.labelNameToShow, style: labelTheme),
                SizedBox(
                  width: AppDimension.elementPadding,
                ),
                Expanded(
                  child: TextField(
                    controller: _textRepresentationController,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: AppDimension.elementPadding,
            ),
            Row(
              children: [
                Text(l10n.labelIcon, style: labelTheme),
                SizedBox(
                  width: AppDimension.elementPadding,
                ),
                IconButton(
                  onPressed: () {
                    _selectIcon(context, AppDimension.getCategoryWidgetEdgeLength(context));
                  },
                  icon: Container(
                    width: AppDimension.getCategoryWidgetEdgeLength(context),
                    height: AppDimension.getCategoryWidgetEdgeLength(context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimension.borderCornerRadius),
                      border: Border.all(
                        color: theme.disabledColor,
                        width: 1,
                      ),
                    ),
                    child: Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _saveCategoryIfPossible(context, ref.read(categoryStateManagerProvider.notifier));
        },
        child: Icon(Icons.save),
      ),
    );
  }
}
