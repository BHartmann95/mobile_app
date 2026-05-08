import 'package:flutter/material.dart';

const Color chalkInk = Color(0xFF101416);
const Color chalkInkSoft = Color(0xFF18201D);
const Color chalkCream = Color(0xFFE9DCC7);
const Color chalkCreamSoft = Color(0xFFF7F2EA);
const Color chalkMint = Color(0xFFBFDCCB);
const Color chalkText = Color(0xFF1E2426);
const Color chalkMutedText = Color(0xFF6F766F);

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

    if (onTap == null) {
      return IgnorePointer(ignoring: true, child: card);
    }
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
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Colors.white,
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    actions: actions,
  );
}
