import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../layout/slide_layout_engine.dart';

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

  double _layoutScale(BoxConstraints c) {
  final shortestSide = math.min(c.maxWidth, c.maxHeight);
  final isPreview = shortestSide < 700;

  final base = isPreview ? 700.0 : 400.0;
  final scale = shortestSide / base;

  return math.max(0.82, math.min(1.65, scale));
}

  @override
  Widget build(BuildContext context) {
    final spec = SlideLayoutEngine.menu(
      isPortrait: isPortrait,
      title: title,
      subtitle: subtitle,
      footer: footer,
      items: items,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _layoutScale(constraints);
        final titleFont = spec.titleFont * scale;
        final subtitleFont = spec.subtitleFont * scale;
        final itemFont = spec.itemFont * scale;
        final priceFont = spec.priceFont * scale;
        final footerFont = spec.footerFont * scale;

        final sectionGap = spec.sectionGap * scale;
        final itemGap = spec.itemGap * scale;
        final rowGap = spec.rowGap * scale;
        final footerTopGap = spec.footerTopGap * scale;

        final priceColumnWidth = isPortrait
            ? math.max(138.0, constraints.maxWidth * 0.34)
            : math.max(170.0, constraints.maxWidth * 0.26);

        final soldOutFont = isPortrait ? priceFont * 0.68 : priceFont * 0.78;

        return Column(
          children: [
            SizedBox(height: sectionGap),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: spec.titleMaxLines,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: titleStyleBuilder(titleFont),
            ),
            SizedBox(height: sectionGap * 0.7),
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: spec.subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: bodyStyleBuilder(subtitleFont),
              ),
            if (pageLabel != null && pageLabel!.trim().isNotEmpty) ...[
              SizedBox(height: sectionGap * 0.55),
              Text(
                pageLabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyStyleBuilder(footerFont),
              ),
            ],
            SizedBox(height: itemGap),
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
                              final soldOut = item['soldOut'] == true;
                              final name = (item['name'] ?? '').toString();
                              final price = (item['price'] ?? '').toString();

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: spec.itemMaxLines,
                                      softWrap: true,
                                      overflow: TextOverflow.fade,
                                      style: bodyStyleBuilder(itemFont).copyWith(
                                        decoration: soldOut
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationThickness:
                                            soldOut ? math.max(1.2, 2 * scale) : null,
                                        color: soldOut
                                            ? const Color(0xCCF2E9DC)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: itemGap),
                                  SizedBox(
                                    width: priceColumnWidth,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Text(
                                        soldOut ? 'AUSVERKAUFT' : price,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.fade,
                                        style: priceStyleBuilder(
                                          soldOut ? soldOutFont : priceFont,
                                        ).copyWith(
                                          color: soldOut
                                              ? const Color(0xCCF2E9DC)
                                              : null,
                                          fontWeight: soldOut
                                              ? FontWeight.w700
                                              : null,
                                          letterSpacing: soldOut ? 0.2 : null,
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
              SizedBox(height: footerTopGap),
              Text(
                footer,
                textAlign: TextAlign.center,
                maxLines: spec.footerMaxLines,
                overflow: TextOverflow.fade,
                style: bodyStyleBuilder(footerFont),
              ),
            ],
          ],
        );
      },
    );
  }
}
