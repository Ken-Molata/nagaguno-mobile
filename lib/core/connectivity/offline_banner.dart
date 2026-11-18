// lib/core/connectivity/offline_banner.dart
//
// Matches the plain-language pattern already established for this
// project ("You appear to be offline" style messaging, not a
// technical error) -- shown app-wide via main.dart's MaterialApp
// builder, not per-screen, so it doesn't need to be individually
// wired into every feature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'connectivity_provider.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);

    // Only render something when we positively know the device is
    // offline -- loading/error states stay invisible rather than
    // showing a flickering banner on every app launch before the
    // first connectivity check resolves.
    final isOffline = isOnlineAsync.maybeWhen(
        data: (isOnline) => !isOnline, orElse: () => false);
    if (!isOffline) return const SizedBox.shrink();

    // No SafeArea of its own -- this now sits inside main.dart's single
    // shared top-strip SafeArea alongside QuickTextSizeControl, so two
    // independent SafeAreas don't stack their top insets when both are
    // visible at once.
    return Material(
      color: AppColors.statusCancelledBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off,
                size: 16, color: AppColors.statusCancelledFg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'You appear to be offline.',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.statusCancelledFg,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
