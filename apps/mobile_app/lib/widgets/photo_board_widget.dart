import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;

    // Titel bewusst unangetastet lassen.
    // Nur die Bildfläche reagiert stärker auf den Regler.
    final normalizedScale = photoScale.clamp(0.8, 1.25);
    final effectiveScale = 1.0 + ((normalizedScale - 1.0) * 1.8);

    final widthFactor =
        ((isPortrait ? 0.90 : 0.92) * effectiveScale).clamp(0.70, 0.98);

    final heightFactor = ((hasTitle
            ? (isPortrait ? 0.82 : 0.84)
            : (isPortrait ? 0.86 : 0.88)) * effectiveScale)
        .clamp(0.58, hasTitle ? 0.92 : 0.96);

    return Column(
      children: [
        if (hasTitle) ...[
          SizedBox(height: isPortrait ? 72 : 40),
          Padding(
            padding: EdgeInsets.only(bottom: isPortrait ? 18 : 14),
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: titleStyleBuilder(isPortrait ? 56 : 44),
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              heightFactor: heightFactor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0x55F2E9DC),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageChild,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
