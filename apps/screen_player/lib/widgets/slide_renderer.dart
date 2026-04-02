import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

class SlideRenderer extends StatelessWidget {
  final SlideModel slide;

  const SlideRenderer({
    super.key,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) {
    switch (slide.templateId) {
      case 'daily_specials':
        return _DailySpecialsSlide(slide: slide);
      case 'promo':
        return _PromoSlide(slide: slide);
      case 'welcome':
        return _WelcomeSlide(slide: slide);
      default:
        return _FallbackSlide(slide: slide);
    }
  }
}

class _DailySpecialsSlide extends StatelessWidget {
  final SlideModel slide;

  const _DailySpecialsSlide({required this.slide});

  Color _parseColor(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 7) {
      buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
    } else {
      buffer.write(hexColor.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _parseColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slide.title,
            style: const TextStyle(
              fontFamily: 'ConteScript',
              color: Color(0xFFF2E9DC),
              fontSize: 46,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            style: const TextStyle(
              fontFamily: 'ConteScript',
              color: Color(0xFFF2E9DC),
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: slide.items.isEmpty
                ? const SizedBox()
                : ListView.builder(
                    itemCount: slide.items.length,
                    itemBuilder: (context, index) {
                      final item = slide.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontFamily: 'ConteScript',
                                  color: Color(0xFFF2E9DC),
                                  fontSize: 34,
                                ),
                              ),
                            ),
                            Text(
                              item.price,
                              style: const TextStyle(
                                fontFamily: 'ConteScript',
                                color: Color(0xFFF2E9DC),
                                fontSize: 34,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            slide.footer,
            style: const TextStyle(
              fontFamily: 'ConteScript',
              color: Color(0xFFF2E9DC),
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoSlide extends StatelessWidget {
  final SlideModel slide;

  const _PromoSlide({required this.slide});

  Color _parseColor(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 7) {
      buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
    } else {
      buffer.write(hexColor.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = slide.items.isNotEmpty ? slide.items.first : null;

    return Container(
      color: _parseColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ConteScript',
                color: Color(0xFFF2E9DC),
                fontSize: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ConteScript',
                color: Color(0xFFF2E9DC),
                fontSize: 36,
              ),
            ),
            const SizedBox(height: 50),
            if (firstItem != null) ...[
              Text(
                firstItem.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ConteScript',
                  color: Color(0xFFF2E9DC),
                  fontSize: 42,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                firstItem.price,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ConteScript',
                  color: Color(0xFFF2E9DC),
                  fontSize: 54,
                ),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              slide.footer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ConteScript',
                color: Color(0xFFF2E9DC),
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  final SlideModel slide;

  const _WelcomeSlide({required this.slide});

  Color _parseColor(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 7) {
      buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
    } else {
      buffer.write(hexColor.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _parseColor(slide.backgroundValue),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ConteScript',
                  color: Color(0xFFF2E9DC),
                  fontSize: 72,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ConteScript',
                  color: Color(0xFFF2E9DC),
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                slide.footer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ConteScript',
                  color: Color(0xFFF2E9DC),
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackSlide extends StatelessWidget {
  final SlideModel slide;

  const _FallbackSlide({required this.slide});

  @override
  Widget build(BuildContext context) {
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
}