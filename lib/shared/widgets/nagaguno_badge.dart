// lib/shared/widgets/nagaguno_badge.dart
//
// Purely decorative circular brand mark -- not a button, not tappable,
// carries no state. Reuses the app's own existing circular logo
// artwork (assets/icons/app_icon.png, already registered as a Flutter
// asset for icon generation) rather than inventing a new mark, cropped
// to a circle since the source PNG's canvas is square with a solid
// fill behind the circular design.
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NagaGunoBadge extends StatelessWidget {
  const NagaGunoBadge({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icons/app_icon.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
