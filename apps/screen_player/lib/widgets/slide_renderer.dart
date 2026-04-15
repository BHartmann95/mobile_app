import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../widgets/headline_board_widget.dart';
import '../widgets/menu_board_widget.dart';

class SlideRenderer extends StatelessWidget {
  final SlideModel slide;

  const SlideRenderer({
    super.key,
    required this.slide,
  });

  Color _parseBoardColor(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'green') {
      return const Color(0xFF1B5E20);
    }

    if (normalized.startsWith('#')) {
      final hex = normalized.replaceFirst('#', '');
      final buffer = StringBuffer();
      if (hex.length == 6) {
        buffer.write('ff');
      }
      buffer.write(hex);
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    }

    return const Color(0xFF111111);
  }

  String _fontMode() {
    return 'chalk';
  }

  TextStyle _titleStyle(double baseFontSize) {
    switch (_fontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  TextStyle _bodyStyle(double baseFontSize) {
    switch (_fontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.12,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.18,
          fontWeight: FontWeight.w500,
        );
    }
  }

  TextStyle _priceStyle(double baseFontSize) {
    switch (_fontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: baseFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  bool _isPortrait(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height >= size.width;
  }

  List<Map<String, dynamic>> _normalizedItems() {
    return slide.items.map((item) {
      bool soldOut = false;
      try {
        final dynamic dynamicItem = item;
        final dynamic value = dynamicItem.soldOut;
        if (value is bool) {
          soldOut = value;
        }
      } catch (_) {}

      return {
        'name': item.name,
        'price': item.price,
        'soldOut': soldOut,
      };
    }).toList();
  }

  Widget _buildMenuLike(BuildContext context) {
    final isPortrait = _isPortrait(context);

    return Container(
      color: _parseBoardColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPortrait ? 80 : 120,
          vertical: isPortrait ? 60 : 70,
        ),
        child: Center(
          child: MenuBoardWidget(
            title: slide.title,
            subtitle: slide.subtitle,
            footer: slide.footer,
            items: _normalizedItems(),
            isPortrait: isPortrait,
            pageLabel: null,
            titleStyleBuilder: _titleStyle,
            bodyStyleBuilder: _bodyStyle,
            priceStyleBuilder: _priceStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildPromo(BuildContext context) {
    final isPortrait = _isPortrait(context);
    final firstItem = slide.items.isNotEmpty ? slide.items.first : null;

    return Container(
      color: _parseBoardColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPortrait ? 80 : 120,
          vertical: isPortrait ? 60 : 70,
        ),
        child: HeadlineBoardWidget(
          title: slide.title,
          subtitle: slide.subtitle,
          footer: slide.footer,
          highlightTitle: firstItem?.name ?? '',
          highlightPrice: firstItem?.price ?? '',
          isPortrait: isPortrait,
          isWelcome: false,
          titleStyleBuilder: _titleStyle,
          bodyStyleBuilder: _bodyStyle,
          priceStyleBuilder: _priceStyle,
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final isPortrait = _isPortrait(context);

    return Container(
      color: _parseBoardColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPortrait ? 80 : 120,
          vertical: isPortrait ? 60 : 70,
        ),
        child: HeadlineBoardWidget(
          title: slide.title,
          subtitle: slide.subtitle,
          footer: slide.footer,
          highlightTitle: '',
          highlightPrice: '',
          isPortrait: isPortrait,
          isWelcome: true,
          titleStyleBuilder: _titleStyle,
          bodyStyleBuilder: _bodyStyle,
          priceStyleBuilder: _priceStyle,
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      color: Colors.red.shade900,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Text(
          'Unbekanntes Template: ${slide.templateId}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (slide.templateId) {
      case 'daily_specials':
      case 'menu':
      case 'drinks':
        return _buildMenuLike(context);
      case 'promo':
        return _buildPromo(context);
      case 'welcome':
        return _buildWelcome(context);
      default:
        return _buildFallback(context);
    }
  }
}
