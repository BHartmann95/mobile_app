import 'dart:math' as math;

class MenuLayoutSpec {
  final double titleFont;
  final double subtitleFont;
  final double itemFont;
  final double priceFont;
  final double footerFont;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final int itemMaxLines;
  final int footerMaxLines;
  final double itemGap;
  final double sectionGap;
  final double footerTopGap;
  final double rowGap;

  const MenuLayoutSpec({
    required this.titleFont,
    required this.subtitleFont,
    required this.itemFont,
    required this.priceFont,
    required this.footerFont,
    required this.titleMaxLines,
    required this.subtitleMaxLines,
    required this.itemMaxLines,
    required this.footerMaxLines,
    required this.itemGap,
    required this.sectionGap,
    required this.footerTopGap,
    required this.rowGap,
  });
}

class HeadlineLayoutSpec {
  final double titleFont;
  final double subtitleFont;
  final double heroTitleFont;
  final double heroPriceFont;
  final double footerFont;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final int heroTitleMaxLines;
  final int footerMaxLines;
  final double topGap;
  final double sectionGap;
  final double heroGap;

  const HeadlineLayoutSpec({
    required this.titleFont,
    required this.subtitleFont,
    required this.heroTitleFont,
    required this.heroPriceFont,
    required this.footerFont,
    required this.titleMaxLines,
    required this.subtitleMaxLines,
    required this.heroTitleMaxLines,
    required this.footerMaxLines,
    required this.topGap,
    required this.sectionGap,
    required this.heroGap,
  });
}

class PhotoLayoutSpec {
  final double titleFont;
  final int titleMaxLines;
  final double topGap;
  final double titleBottomGap;
  final double widthFactor;
  final double heightFactor;

  const PhotoLayoutSpec({
    required this.titleFont,
    required this.titleMaxLines,
    required this.topGap,
    required this.titleBottomGap,
    required this.widthFactor,
    required this.heightFactor,
  });
}

class SlideLayoutEngine {
  const SlideLayoutEngine._();

  static MenuLayoutSpec menu({
    required bool isPortrait,
    required String title,
    required String subtitle,
    required String footer,
    required List<Map<String, dynamic>> items,
  }) {
    final itemCount = items.length;
    final longestItem = items.fold<int>(
      0,
      (maxLen, item) => math.max(
        maxLen,
        (item['name']?.toString().trim().length ?? 0),
      ),
    );

    final hasLongTitle = title.trim().length > (isPortrait ? 18 : 16);
    final hasLongSubtitle = subtitle.trim().length > (isPortrait ? 24 : 20);
    final hasLongFooter = footer.trim().length > (isPortrait ? 28 : 24);
    final denseByCount = itemCount >= (isPortrait ? 8 : 5);
    final veryDenseByCount = itemCount >= (isPortrait ? 10 : 6);
    final denseByText = longestItem >= (isPortrait ? 22 : 18);

    if (isPortrait) {
      double titleFont = 54;
      double subtitleFont = 26;
      double itemFont = 31;
      double priceFont = 31;
      double footerFont = 22;
      double itemGap = 12;
      double sectionGap = 18;
      double footerTopGap = 16;
      double rowGap = 10;

      if (denseByCount) {
        titleFont = 50;
        subtitleFont = 24;
        itemFont = 28;
        priceFont = 28;
        footerFont = 20;
        itemGap = 10;
        sectionGap = 16;
        footerTopGap = 14;
        rowGap = 8;
      }

      if (veryDenseByCount || denseByText || hasLongTitle || hasLongSubtitle) {
        titleFont = 46;
        subtitleFont = 22;
        itemFont = 26;
        priceFont = 26;
        footerFont = 19;
        itemGap = 8;
        sectionGap = 14;
        footerTopGap = 12;
        rowGap = 6;
      }

      return MenuLayoutSpec(
        titleFont: titleFont,
        subtitleFont: subtitleFont,
        itemFont: itemFont,
        priceFont: priceFont,
        footerFont: footerFont,
        titleMaxLines: 2,
        subtitleMaxLines: 1,
        itemMaxLines: 2,
        footerMaxLines: hasLongFooter ? 2 : 1,
        itemGap: itemGap,
        sectionGap: sectionGap,
        footerTopGap: footerTopGap,
        rowGap: rowGap,
      );
    }

    double titleFont = 40;
    double subtitleFont = 20;
    double itemFont = 24;
    double priceFont = 24;
    double footerFont = 17;
    double itemGap = 10;
    double sectionGap = 14;
    double footerTopGap = 12;
    double rowGap = 8;

    if (denseByCount) {
      titleFont = 36;
      subtitleFont = 18;
      itemFont = 21;
      priceFont = 21;
      footerFont = 16;
      itemGap = 8;
      sectionGap = 12;
      footerTopGap = 10;
      rowGap = 6;
    }

    if (veryDenseByCount || denseByText || hasLongTitle || hasLongSubtitle) {
      titleFont = 33;
      subtitleFont = 17;
      itemFont = 19;
      priceFont = 19;
      footerFont = 15;
      itemGap = 7;
      sectionGap = 10;
      footerTopGap = 8;
      rowGap = 5;
    }

    return MenuLayoutSpec(
      titleFont: titleFont,
      subtitleFont: subtitleFont,
      itemFont: itemFont,
      priceFont: priceFont,
      footerFont: footerFont,
      titleMaxLines: 2,
      subtitleMaxLines: 1,
      itemMaxLines: 2,
      footerMaxLines: hasLongFooter ? 2 : 1,
      itemGap: itemGap,
      sectionGap: sectionGap,
      footerTopGap: footerTopGap,
      rowGap: rowGap,
    );
  }

  static HeadlineLayoutSpec headline({
    required bool isPortrait,
    required bool isWelcome,
    required String title,
    required String subtitle,
    required String footer,
    required String highlightTitle,
    required String highlightPrice,
  }) {
    final longTitle = title.trim().length > (isPortrait ? 20 : 16);
    final longSubtitle = subtitle.trim().length > (isPortrait ? 26 : 22);
    final longHeroTitle = highlightTitle.trim().length > (isPortrait ? 18 : 16);
    final hasFooter = footer.trim().isNotEmpty;

    if (isWelcome) {
      if (isPortrait) {
        return HeadlineLayoutSpec(
          titleFont: longTitle ? 60 : 68,
          subtitleFont: longSubtitle ? 26 : 30,
          heroTitleFont: 0,
          heroPriceFont: 0,
          footerFont: hasFooter ? 22 : 0,
          titleMaxLines: 2,
          subtitleMaxLines: 2,
          heroTitleMaxLines: 0,
          footerMaxLines: hasFooter ? 2 : 0,
          topGap: 36,
          sectionGap: 18,
          heroGap: 0,
        );
      }

      return HeadlineLayoutSpec(
        titleFont: longTitle ? 42 : 48,
        subtitleFont: longSubtitle ? 20 : 24,
        heroTitleFont: 0,
        heroPriceFont: 0,
        footerFont: hasFooter ? 16 : 0,
        titleMaxLines: 2,
        subtitleMaxLines: 2,
        heroTitleMaxLines: 0,
        footerMaxLines: hasFooter ? 2 : 0,
        topGap: 22,
        sectionGap: 12,
        heroGap: 0,
      );
    }

    if (isPortrait) {
      return HeadlineLayoutSpec(
        titleFont: longTitle ? 52 : 58,
        subtitleFont: longSubtitle ? 24 : 28,
        heroTitleFont: longHeroTitle ? 44 : 50,
        heroPriceFont: 54,
        footerFont: hasFooter ? 20 : 0,
        titleMaxLines: 2,
        subtitleMaxLines: 2,
        heroTitleMaxLines: 2,
        footerMaxLines: hasFooter ? 2 : 0,
        topGap: 24,
        sectionGap: 16,
        heroGap: 14,
      );
    }

    return HeadlineLayoutSpec(
      titleFont: longTitle ? 34 : 38,
      subtitleFont: longSubtitle ? 18 : 20,
      heroTitleFont: longHeroTitle ? 28 : 32,
      heroPriceFont: 36,
      footerFont: hasFooter ? 15 : 0,
      titleMaxLines: 2,
      subtitleMaxLines: 2,
      heroTitleMaxLines: 2,
      footerMaxLines: hasFooter ? 2 : 0,
      topGap: 12,
      sectionGap: 10,
      heroGap: 10,
    );
  }

  static PhotoLayoutSpec photo({
    required bool isPortrait,
    required String title,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    final longTitle = title.trim().length > (isPortrait ? 22 : 18);

    if (isPortrait) {
      return PhotoLayoutSpec(
        titleFont: longTitle ? 48 : 56,
        titleMaxLines: 2,
        topGap: hasTitle ? 48 : 0,
        titleBottomGap: hasTitle ? 18 : 0,
        widthFactor: 0.90,
        heightFactor: hasTitle ? (longTitle ? 0.72 : 0.76) : 0.86,
      );
    }

    return PhotoLayoutSpec(
      titleFont: longTitle ? 38 : 44,
      titleMaxLines: 2,
      topGap: hasTitle ? 28 : 0,
      titleBottomGap: hasTitle ? 14 : 0,
      widthFactor: 0.92,
      heightFactor: hasTitle ? (longTitle ? 0.76 : 0.80) : 0.88,
    );
  }
}
