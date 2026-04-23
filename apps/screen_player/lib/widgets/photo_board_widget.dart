import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../layout/slide_layout_engine.dart';

typedef PhotoTitleStyleBuilder = TextStyle Function(double baseFontSize);

class PhotoBoardWidget extends StatelessWidget {
  final String title;
  final bool isPortrait;
  final Widget imageChild;
  final PhotoTitleStyleBuilder titleStyleBuilder;
  final double photoScale;

  const PhotoBoardWidget({
    super.key,
    required this.title,
    required this.isPortrait,
    required this.imageChild,
    required this.titleStyleBuilder,
    this.photoScale = 1.0,
  });

  double _layoutScale(BoxConstraints c) {
  final shortestSide = math.min(c.maxWidth, c.maxHeight);
  final isPreview = shortestSide < 700;

  final base = isPreview ? 700.0 : 400.0;
  final scale = shortestSide / base;

  return math.max(0.82, math.min(1.65, scale));
}

  @override
  Widget build(BuildContext context) {
    final spec = SlideLayoutEngine.photo(
      isPortrait: isPortrait,
      title: title,
    );

    final hasTitle = title.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _layoutScale(constraints);
        final titleFont = spec.titleFont * scale;
        final topGap = spec.topGap * scale;
        final titleBottomGap = spec.titleBottomGap * scale;
        final radius = math.max(14.0, 18.0 * scale);

        return Column(
          children: [
            if (hasTitle) ...[
              SizedBox(height: topGap),
              Padding(
                padding: EdgeInsets.only(
                  left: (isPortrait ? 24 : 40) * scale,
                  right: (isPortrait ? 24 : 40) * scale,
                  bottom: titleBottomGap,
                ),
                child: Builder(
              builder: (context) {
                final titleText = title.trim();
                final titleLength = titleText.length;
                final veryLongTitle = titleLength > 34;
                final longTitle = titleLength > 28;

                final resolvedFont = veryLongTitle
                    ? titleFont * 0.78
                    : (longTitle ? titleFont * 0.88 : titleFont);

                return Text(
                  titleText,
                  textAlign: TextAlign.center,
                  maxLines: veryLongTitle ? 3 : 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: titleStyleBuilder(resolvedFont),
                );
              },
            ),
              ),
            ],
            Expanded(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: spec.widthFactor,
                  heightFactor: spec.heightFactor,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: const Color(0x55F2E9DC),
                        width: math.max(1.0, 1.2 * scale),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: imageChild,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
