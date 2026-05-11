import 'package:flutter/material.dart';

const Color chalkInk = Color(0xFF101416);
const Color chalkInkSoft = Color(0xFF18201D);
const Color chalkCream = Color(0xFFE9DCC7);
const Color chalkCreamSoft = Color(0xFFF7F2EA);
const Color chalkMint = Color(0xFFBFDCCB);
const Color chalkText = Color(0xFF1E2426);
const Color chalkMutedText = Color(0xFF6F766F);
const Color chalkCardSurface = Color(0xFFF7F2EA);

class ChalkBackground extends StatelessWidget {
  final Widget child;
  final double textureOpacity;

  const ChalkBackground({
    super.key,
    required this.child,
    this.textureOpacity = 0.34,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: chalkInk),
        Opacity(
          opacity: textureOpacity,
          child: Image.asset(
            'assets/images/app_chalkboard_dark.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x331C2A25), Color(0xCC050606)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class ChalkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double opacity;

  const ChalkCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.opacity = 0.96,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    return card;
  }
}

class ChalkPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const ChalkPill({
    super.key,
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

PreferredSizeWidget chalkAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  return brandedChalkAppBar(
    title: 'TafelFix Studio',
    subtitle: subtitle ?? title,
    actions: actions,
  );
}

PreferredSizeWidget brandedChalkAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: chalkInk,
    elevation: 0,
    foregroundColor: chalkCream,
    centerTitle: false,
    titleSpacing: 0,
    title: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/icon_studio.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: chalkCream,
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD8D2C6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    actions: actions,
  );
}

ThemeData chalkAppTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: chalkCream,
      secondary: chalkMint,
      surface: chalkCreamSoft,
      onPrimary: chalkText,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: chalkCream,
      inactiveTrackColor: chalkCream.withOpacity(0.25),
      thumbColor: chalkCream,
      overlayColor: chalkCream.withOpacity(0.16),
      valueIndicatorColor: chalkInkSoft,
      valueIndicatorTextStyle: const TextStyle(color: chalkCream),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return chalkText;
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(chalkCreamSoft),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: chalkCream),
  );
}
