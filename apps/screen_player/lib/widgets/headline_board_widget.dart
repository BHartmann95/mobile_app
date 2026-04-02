import 'package:flutter/material.dart';

typedef HeadlineTextStyleBuilder = TextStyle Function(double baseFontSize);

class HeadlineBoardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footer;
  final String highlightTitle;
  final String highlightPrice;
  final bool isPortrait;
  final bool isWelcome;
  final HeadlineTextStyleBuilder titleStyleBuilder;
  final HeadlineTextStyleBuilder bodyStyleBuilder;
  final HeadlineTextStyleBuilder priceStyleBuilder;

  const HeadlineBoardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.highlightTitle,
    required this.highlightPrice,
    required this.isPortrait,
    required this.isWelcome,
    required this.titleStyleBuilder,
    required this.bodyStyleBuilder,
    required this.priceStyleBuilder,
  });

  Widget _fitText(
    String text, {
    required TextStyle style,
    int maxLines = 2,
    double widthFactor = 1.0,
  }) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: maxLines,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: style,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = isPortrait
        ? (isWelcome ? 124.0 : 48.0)
        : (isWelcome ? 148.0 : 64.0);
    final heroTitleSize = isPortrait ? 142.0 : 172.0;
    final heroPriceSize = isPortrait ? 112.0 : 138.0;
    final subtitleSize = isPortrait
        ? (isWelcome ? 54.0 : 50.0)
        : (isWelcome ? 64.0 : 58.0);
    final footerSize = isPortrait ? 28.0 : 34.0;

    final titleWidth = isPortrait ? 0.94 : 0.90;
    final heroWidth = isPortrait ? 0.96 : 0.92;
    final textWidth = isPortrait ? 0.94 : 0.90;

    return Center(
      child: FractionallySizedBox(
        widthFactor: isPortrait ? 0.96 : 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _fitText(
              title,
              style: titleStyleBuilder(titleSize),
              maxLines: isPortrait ? 2 : 1,
              widthFactor: titleWidth,
            ),
            SizedBox(height: isPortrait ? 42 : 34),
            if (!isWelcome) ...[
              _fitText(
                highlightTitle,
                style: titleStyleBuilder(heroTitleSize),
                maxLines: isPortrait ? 3 : 2,
                widthFactor: heroWidth,
              ),
              SizedBox(height: isPortrait ? 26 : 22),
              _fitText(
                highlightPrice,
                style: priceStyleBuilder(heroPriceSize),
                maxLines: 2,
                widthFactor: heroWidth,
              ),
              SizedBox(height: isPortrait ? 42 : 34),
            ],
            if (subtitle.trim().isNotEmpty)
              _fitText(
                subtitle,
                style: bodyStyleBuilder(subtitleSize),
                maxLines: isPortrait ? 3 : 2,
                widthFactor: textWidth,
              ),
            if (footer.trim().isNotEmpty) ...[
              SizedBox(height: isPortrait ? 28 : 26),
              _fitText(
                footer,
                style: bodyStyleBuilder(footerSize),
                maxLines: 2,
                widthFactor: textWidth,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
