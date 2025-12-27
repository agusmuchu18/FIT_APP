import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.minHeight = 140,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double minHeight;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    final decoration = glass
        ? BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          )
        : BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          );

    Widget cardBody = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );

    if (glass) {
      cardBody = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: cardBody,
        ),
      );
    }

    final card = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: cardBody,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
