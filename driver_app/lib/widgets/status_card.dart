import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  // Optional niceties
  final String? subtitle;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing; // e.g., a chevron or badge

  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.subtitle,
    this.isLoading = false,
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? const Color(0xFFE65100);
    final radius = BorderRadius.circular(12);

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: cardColor, size: 24),
              ),
              const Spacer(),
              trailing ??
                  (onTap != null
                      ? const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withOpacity(0.9),
              ),
            ),
          ],

          const SizedBox(height: 4),

          // Value (animated / loading)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: isLoading
                ? Container(
                    key: const ValueKey('loading'),
                    width: 64,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(
                    value,
                    key: ValueKey(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
          ),
        ],
      ),
    );

    final card = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias, // ensures ripple is clipped
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );

    // Accessibility: announce as button when tappable
    return Semantics(
      button: onTap != null,
      label: title,
      value: isLoading ? 'Loading' : value,
      child: onTap != null ? Tooltip(message: title, child: card) : card,
    );
  }
}
