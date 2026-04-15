import 'package:flutter/material.dart';

typedef MenuTextStyleBuilder = TextStyle Function(double baseFontSize);

class MenuBoardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footer;
  final List<Map<String, dynamic>> items;
  final bool isPortrait;
  final String? pageLabel;
  final MenuTextStyleBuilder titleStyleBuilder;
  final MenuTextStyleBuilder bodyStyleBuilder;
  final MenuTextStyleBuilder priceStyleBuilder;

  const MenuBoardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.items,
    required this.isPortrait,
    this.pageLabel,
    required this.titleStyleBuilder,
    required this.bodyStyleBuilder,
    required this.priceStyleBuilder,
  });

  double _itemScaleFactor(int itemCount) {
    if (isPortrait) {
      if (itemCount <= 3) return 1.20;
      if (itemCount <= 5) return 1.10;
      if (itemCount <= 7) return 1.02;
      return 0.95;
    }
    if (itemCount <= 3) return 1.18;
    if (itemCount <= 5) return 1.08;
    return 0.98;
  }

  int _longestWordLength(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 0;
    return words.map((e) => e.length).reduce((a, b) => a > b ? a : b);
  }

  double _singleWordAdjustment(List<Map<String, dynamic>> items) {
    final longestWord = items
        .map((item) => _longestWordLength((item['name'] ?? '').toString()))
        .fold<int>(0, (a, b) => a > b ? a : b);

    if (isPortrait) {
      if (longestWord >= 16) return 0.95;
      if (longestWord >= 14) return 0.98;
      return 1.0;
    }

    if (longestWord >= 18) return 0.95;
    if (longestWord >= 15) return 0.98;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth = isPortrait ? 1080.0 : 1920.0;
        final baseHeight = isPortrait ? 1920.0 : 1080.0;
        final scaleX = constraints.maxWidth / baseWidth;
        final scaleY = constraints.maxHeight / baseHeight;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final itemCount = items.length;
        final itemScale = _itemScaleFactor(itemCount);
        final singleWordAdjustment = _singleWordAdjustment(items);
        final hasSoldOutItems = items.any((item) => item['soldOut'] == true);
        final hasVeryLongItem = items.any((item) {
          final name = (item['name'] ?? '').toString().trim();
          return name.length >= (isPortrait ? 24 : 20);
        });

        final titleFont = (isPortrait ? 134.0 : 104.0) * scale;
        final subtitleFont = (isPortrait ? 50.0 : 38.0) * scale;
        final itemFont =
            (isPortrait ? 86.0 : 56.0) *
            scale *
            itemScale *
            (hasVeryLongItem ? 0.96 : 1.0) *
            singleWordAdjustment;
        final priceFont = (isPortrait ? 82.0 : 54.0) * scale * itemScale;
        final soldOutFont = priceFont * (isPortrait ? 0.58 : 0.62);
        final footerFont = (isPortrait ? 34.0 : 24.0) * scale;

        final topSpace = (isPortrait ? 34.0 : 18.0) * scale;
        final betweenHeader = (isPortrait ? 18.0 : 12.0) * scale;
        final columnGap = (isPortrait ? 38.0 : 20.0) * scale;
        final rowGap = (isPortrait ? 16.0 : 12.0) * scale;
        final betweenListAndFooter = (isPortrait ? 18.0 : 12.0) * scale;
        final sideGap = (isPortrait ? 18.0 : 20.0) * scale;

        final priceColumnWidth =
            (isPortrait
                    ? (hasSoldOutItems ? 320.0 : 200.0)
                    : (hasSoldOutItems ? 300.0 : 220.0)) *
            scale;

        final nameLines = isPortrait ? (hasSoldOutItems ? 3 : 2) : 2;

        return Column(
          children: [
            SizedBox(height: topSpace),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: titleStyleBuilder(titleFont),
              ),
            ),
            SizedBox(height: betweenHeader),
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bodyStyleBuilder(subtitleFont),
              ),
            if (pageLabel != null && pageLabel!.trim().isNotEmpty) ...[
              SizedBox(height: 10 * scale),
              Text(
                pageLabel!,
                textAlign: TextAlign.center,
                style: bodyStyleBuilder(26 * scale),
              ),
            ],
            SizedBox(height: columnGap),
            Expanded(
              child: items.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          Builder(
                            builder: (context) {
                              final item = items[i];
                              final isSoldOut = item['soldOut'] == true;
                              final name = (item['name'] ?? '').toString();
                              final price = (item['price'] ?? '').toString();

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: nameLines,
                                      softWrap: true,
                                      overflow: TextOverflow.fade,
                                      style: bodyStyleBuilder(itemFont).copyWith(
                                        color: isSoldOut
                                            ? const Color(0xCCF2E9DC)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: sideGap),
                                  SizedBox(
                                    width: priceColumnWidth,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          isSoldOut ? 'AUSVERKAUFT' : price,
                                          textAlign: TextAlign.right,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.visible,
                                          style: priceStyleBuilder(
                                            isSoldOut ? soldOutFont : priceFont,
                                          ).copyWith(
                                            color: isSoldOut
                                                ? const Color(0xCCF2E9DC)
                                                : null,
                                            fontWeight: isSoldOut
                                                ? FontWeight.w700
                                                : null,
                                            letterSpacing: isSoldOut
                                                ? (isPortrait ? 0.4 : 0.6)
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (i != items.length - 1) SizedBox(height: rowGap),
                        ],
                      ],
                    ),
            ),
            if (footer.trim().isNotEmpty) ...[
              SizedBox(height: betweenListAndFooter),
              Text(
                footer,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bodyStyleBuilder(footerFont),
              ),
            ],
            SizedBox(height: (isPortrait ? 16.0 : 10.0) * scale),
          ],
        );
      },
    );
  }
}
