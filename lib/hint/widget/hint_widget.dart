import 'package:chrono_sheet/ui/color.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/ui/theme.dart';
import 'package:flutter/material.dart';

import '../model/hint_model.dart';

class HintWidget extends StatelessWidget {
  final String text;
  final HintBounds hintBounds;

  const HintWidget({
    required this.text,
    required this.hintBounds,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: hintBounds.rect.top,
      left: hintBounds.rect.left,
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.hintBackground,
          borderRadius: BorderRadius.circular(AppDimension.hintBorderRadius),
        ),
        child: CustomPaint(
          painter: _HintArrowPainter(hintBounds),
          child: Padding(
            padding: EdgeInsets.all(AppDimension.hintInsets),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: hintBounds.maxTextWidth,
              ),
              child: Text(
                text,
                style: AppTheme.labelTextStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintArrowPainter extends CustomPainter {
  final HintBounds _hintBounds;

  const _HintArrowPainter(this._hintBounds);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColor.hintBackground
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(_hintBounds.pointerLeft.x, _hintBounds.pointerLeft.y)
      ..lineTo(_hintBounds.pointerArrow.x, _hintBounds.pointerArrow.y)
      ..lineTo(_hintBounds.pointerRight.x, _hintBounds.pointerRight.y)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
