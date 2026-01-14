import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  /// Square size of the logo container.
  final double size;

  /// Whether to show the title/subtitle text.
  final bool showText;

  /// Optional override for the brand title (default: "Taste of African Cuisine").
  final String? title;

  /// Optional override for the brand subtitle (default: "Driver").
  final String? subtitle;



  /// If true, makes the logo fully circular instead of rounded rectangle.
  final bool circular;

  /// Optional Hero tag to enable hero transitions (e.g., between Splash and Auth).
  final Object? heroTag;

  /// Accessibility: if false, marks the logo as decorative only (no semantics).
  final bool semanticEnabled;

  const AppLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.title,
    this.subtitle,

    this.circular = false,
    this.heroTag,
    this.semanticEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTitle = title ?? 'Taste of African Cuisine';
    final brandSubtitle = subtitle ?? 'Driver';
    final radius = circular
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(size * 0.2);

    final logoWithBg = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );

    Widget core = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap with Semantics for screen readers
        Semantics(
          image: true,
          label: semanticEnabled ? '$brandTitle $brandSubtitle logo' : null,
          excludeSemantics: !semanticEnabled,
          child: heroTag != null
              ? Hero(tag: heroTag!, child: logoWithBg)
              : logoWithBg,
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            brandTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE65100),
            ),
          ),
          Text(
            brandSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey.shade300
                  : Colors.grey,
            ),
          ),
        ],
      ],
    );

    return core;
  }
}
