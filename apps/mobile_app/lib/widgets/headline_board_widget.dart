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

  Widget _textBlock(
    String text, {
    required TextStyle style,
    required int maxLines,
    TextAlign textAlign = TextAlign.center,
  }) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Welcome needs a safer title size in portrait so it does not wrap
        // while promo should keep its large hero layout.
        final titleFont = isWelcome
            ? (isPortrait ? h * 0.082 : h * 0.145)
            : (isPortrait ? h * 0.055 : h * 0.085);

        final heroTitleFont = isPortrait ? h * 0.090 : h * 0.145;
        final heroPriceFont = isPortrait ? h * 0.082 : h * 0.130;
        final subtitleFont = isWelcome
            ? (isPortrait ? h * 0.040 : h * 0.068)
            : (isPortrait ? h * 0.045 : h * 0.060);
        final footerFont = isPortrait ? h * 0.022 : h * 0.034;

        final horizontalPadding = isPortrait ? w * 0.07 : w * 0.08;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              Spacer(flex: isWelcome ? 16 : 10),

              Flexible(
                flex: isWelcome ? 14 : 12,
                child: Center(
                  child: _textBlock(
                    title,
                    style: titleStyleBuilder(titleFont),
                    maxLines: isWelcome ? 1 : (isPortrait ? 2 : 1),
                  ),
                ),
              ),

              SizedBox(height: isPortrait ? h * 0.020 : h * 0.020),

              if (!isWelcome) ...[
                Flexible(
                  flex: 22,
                  child: Center(
                    child: _textBlock(
                      highlightTitle,
                      style: titleStyleBuilder(heroTitleFont),
                      maxLines: isPortrait ? 3 : 2,
                    ),
                  ),
                ),
                SizedBox(height: isPortrait ? h * 0.015 : h * 0.012),
                Flexible(
                  flex: 18,
                  child: Center(
                    child: _textBlock(
                      highlightPrice,
                      style: priceStyleBuilder(heroPriceFont),
                      maxLines: 2,
                    ),
                  ),
                ),
                SizedBox(height: isPortrait ? h * 0.030 : h * 0.026),
              ],

              Flexible(
                flex: isWelcome ? 10 : 12,
                child: Center(
                  child: _textBlock(
                    subtitle,
                    style: bodyStyleBuilder(subtitleFont),
                    maxLines: isPortrait ? 2 : 2,
                  ),
                ),
              ),

              SizedBox(height: isPortrait ? h * 0.018 : h * 0.018),

              Flexible(
                flex: isWelcome ? 6 : 8,
                child: Center(
                  child: _textBlock(
                    footer,
                    style: bodyStyleBuilder(footerFont),
                    maxLines: 1,
                  ),
                ),
              ),

              Spacer(flex: isWelcome ? 22 : 10),
            ],
          ),
        );
      },
    );
  }
}
