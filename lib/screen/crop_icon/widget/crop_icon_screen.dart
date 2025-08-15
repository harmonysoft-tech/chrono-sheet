import 'dart:io';
import 'dart:math';

import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../generated/app_localizations.dart';
import '../../../ui/dimension.dart';

final _logger = getNamedLogger();

class CropIconScreen extends StatefulWidget {
  final File imageFile;

  const CropIconScreen({super.key, required this.imageFile});

  @override
  State createState() => CropIconScreeState();
}

class CropIconScreeState extends State<CropIconScreen> {

  double _x = 0;
  double _y = 0;
  double _edgeLength = 0;
  bool _initial = true;

  Future<void> _saveSelection(BuildContext context) async {
    Uint8List bytes = await widget.imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (!context.mounted) {
      _logger.info("skipped icon file storing because the context is unmounted");
      return;
    }

    double scaleX = image!.width / context.size!.width;
    double scaleY = image.height / context.size!.height;
    int cropX = (_x * scaleX).toInt();
    int cropY = (_y * scaleY).toInt();
    int cropSize = (_edgeLength * scaleX).toInt();

    // Ensure crop area is within bounds
    cropX = cropX.clamp(0, image.width - cropSize);
    cropY = cropY.clamp(0, image.height - cropSize);
    cropSize = cropSize.clamp(0, image.width - cropX).clamp(0, image.height - cropY);

    // Crop the selected area
    img.Image croppedImage = img.copyCrop(image, x: cropX, y: cropY, width: cropSize, height: cropSize);

    // Convert back to bytes and save
    Uint8List croppedBytes = Uint8List.fromList(img.encodeJpg(croppedImage));

    final croppedFile = File("${AppPaths.categoryIconRootDir}/${Uuid().v4()}.jpg");
    await croppedFile.writeAsBytes(croppedBytes);
    if (context.mounted) {
      context.pop(croppedFile);
    } else {
      _logger.info("skipped icon file storing because the context is unmounted");
      await croppedFile.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleChooseCategoryImage),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              _saveSelection(context);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimension.screenPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (mounted && _initial) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final edge = min(constraints.maxWidth, constraints.maxHeight);
                final x = (constraints.maxWidth - edge) / 2;
                final y = (constraints.maxHeight - edge) / 2;
                setState(() {
                  _initial = false;
                  _x = x;
                  _y = y;
                  _edgeLength = edge;
                });
              });
            }
            return AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Stack(
                  children: [
                    Image.file(widget.imageFile),
                    Positioned(
                      left: _x,
                      right: _y,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _x += details.delta.dx.clamp(0, context.size!.width - _edgeLength);
                            _y += details.delta.dy.clamp(0, context.size!.height - _edgeLength);
                          });
                        },
                        child: GestureDetector(
                          onScaleUpdate: (details) {
                            setState(() {
                              _edgeLength = (_edgeLength * details.scale).clamp(50, 300);
                            });
                          },
                          child: Container(
                            width: _edgeLength,
                            height: _edgeLength,
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 2)
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
