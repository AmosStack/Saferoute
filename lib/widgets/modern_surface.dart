import 'package:flutter/material.dart';

class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.backgroundColor = Colors.white,
    this.gradient,
    this.borderColor,
    this.shadowColor,
    this.hoverLift = 6,
    this.hoverScale = 1.01,
    this.duration = const Duration(milliseconds: 180),
    this.alignment,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? shadowColor;
  final double hoverLift;
  final double hoverScale;
  final Duration duration;
  final AlignmentGeometry? alignment;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(widget.borderRadius);
    final shadowColor = widget.shadowColor ?? Colors.black.withValues(alpha: 0.08);
    final backgroundColor = widget.gradient == null
      ? (isDark ? scheme.surfaceContainerHighest : widget.backgroundColor)
      : widget.backgroundColor;

    final surface = AnimatedScale(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      scale: _hovered ? widget.hoverScale : 1.0,
      child: Transform.translate(
        offset: Offset(0, _hovered ? -widget.hoverLift : 0),
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          padding: widget.padding,
          alignment: widget.alignment,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? backgroundColor : null,
            borderRadius: radius,
            border: Border.all(
              color: widget.borderColor ?? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: _hovered ? 0.18 : 0.08),
                blurRadius: _hovered ? 26 : 18,
                offset: Offset(0, _hovered ? 14 : 8),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? surface
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: radius,
                child: surface,
              ),
            ),
    );
  }
}

class GreenSectionHeader extends StatelessWidget {
  const GreenSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7C7B), Color(0xFF0A5F5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}