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

  double _getItemScaleFactor(int itemCount) {
    if (isPortrait) {
      if (itemCount <= 3) return 1.24;
      if (itemCount <= 5) return 1.14;
      if (itemCount <= 7) return 1.04;
      return 0.96;
    }

    if (itemCount <= 3) return 1.22;
    if (itemCount <= 5) return 1.10;
    return 0.98;
  }

  double _getTitleScaleFactor(int itemCount) {
    if (isPortrait) {
      if (itemCount <= 3) return 1.00;
      if (itemCount <= 5) return 1.02;
      if (itemCount <= 7) return 1.01;
      return 0.96;
    }

    if (itemCount <= 3) return 1.04;
    if (itemCount <= 5) return 1.02;
    return 0.98;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final itemCount = items.length;
        final itemScale = _getItemScaleFactor(itemCount);
        final titleScale = _getTitleScaleFactor(itemCount);

        final titleFont = (isPortrait ? h * 0.070 : h * 0.095) * titleScale;
        final subtitleFont = (isPortrait ? h * 0.026 : h * 0.036) * itemScale;
        final itemFont = (isPortrait ? h * 0.045 : h * 0.052) * itemScale;
        final priceFont = (isPortrait ? h * 0.043 : h * 0.050) * itemScale;
        final footerFont = (isPortrait ? h * 0.018 : h * 0.022) * itemScale;
        final topSpace = (isPortrait ? h * 0.018 : h * 0.010) * (isPortrait ? 0.90 : 1.0);
        final betweenHeader = (isPortrait ? h * 0.010 : h * 0.014) * itemScale;
        final betweenListAndFooter = (isPortrait ? h * 0.010 : h * 0.012) * itemScale;
        final rowGap = (isPortrait ? h * 0.008 : h * 0.010) * (isPortrait ? 0.85 : 1.0);
        final columnGap = (isPortrait ? h * 0.020 : h * 0.018) * (isPortrait ? 0.90 : 1.0);

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
              SizedBox(height: h * 0.006),
              Text(
                pageLabel!,
                textAlign: TextAlign.center,
                style: bodyStyleBuilder(h * 0.014),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  (items[i]['name'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: bodyStyleBuilder(itemFont).copyWith(
                                    decoration: items[i]['soldOut'] == true
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationThickness:
                                        items[i]['soldOut'] == true ? 2 : null,
                                  ),
                                ),
                              ),
                              SizedBox(width: isPortrait ? h * 0.012 : h * 0.018),
                              Text(
                                (items[i]['price'] ?? '').toString(),
                                textAlign: TextAlign.right,
                                style: priceStyleBuilder(priceFont).copyWith(
                                  decoration: items[i]['soldOut'] == true
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationThickness:
                                      items[i]['soldOut'] == true ? 2 : null,
                                ),
                              ),
                            ],
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
            SizedBox(height: isPortrait ? h * 0.010 : h * 0.008),
          ],
        );
      },
    );
  }
}
