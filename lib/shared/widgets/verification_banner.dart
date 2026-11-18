// lib/shared/widgets/verification_banner.dart
//
// The reusable pattern the original spec's Section 5 explicitly calls
// for. Two pieces: a persistent banner (for screens with a gated
// action) and a LockedAction wrapper (for the individual buttons/cards
// themselves) — matching the real web app's own two-part pattern
// (persistent top banner + per-card lock treatment) rather than
// inventing a different one for mobile.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/kyc/application/kyc_status_provider.dart';
import '../../features/kyc/domain/kyc_models.dart';

/// Persistent banner shown at the top of any screen containing a
/// gated action. Distinguishes "pending review" from "not yet
/// started" — matching the real web app's own distinction, not a
/// generic single "verify your account" message for both cases.
class VerificationBanner extends ConsumerWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVerified = ref.watch(isVerifiedProvider);
    if (isVerified) return const SizedBox.shrink();

    final kycStatusAsync = ref.watch(kycStatusProvider);

    return kycStatusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (kycStatus) {
        final isRejected = kycStatus.status == KycStatus.rejected ||
            kycStatus.status == KycStatus.resubmissionRequired;
        // Rejected gets the error/cancelled color treatment, matching
        // how rejection is styled everywhere else in this app —
        // previously this banner only distinguished "pending" from
        // everything else, so a rejected user saw the same generic
        // accent-colored "verify now" prompt as someone who'd never
        // submitted at all, with no indication their specific
        // submission had actually been rejected.
        final bgColor = isRejected
            ? AppColors.statusCancelledBg
            : AppColors.verificationPendingBg;
        final borderColor =
            isRejected ? AppColors.statusCancelledFg : AppColors.accent;
        final iconColor =
            isRejected ? AppColors.statusCancelledFg : AppColors.accentDark;
        // Uses the model's own displayMessage (the real backend's
        // resolved message, now covering Route A's "complete the
        // steps Didit just opened" case too) instead of a client-side
        // copy that had no such case and could drift from the
        // backend's actual wording.
        final message = switch (kycStatus.status) {
          KycStatus.pending ||
          KycStatus.rejected ||
          KycStatus.resubmissionRequired =>
            kycStatus.displayMessage,
          _ => "Verify your account to place orders.",
        };
        final buttonLabel = switch (kycStatus.status) {
          KycStatus.pending => 'Check Status',
          KycStatus.rejected => 'Resubmit',
          KycStatus.resubmissionRequired => 'Resubmit',
          _ => 'Verify Now',
        };
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Icon(isRejected ? Icons.error_outline : Icons.info_outline,
                  color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  // Real backend copy, reused verbatim per this
                  // session's established pattern — not reworded.
                  message,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => context.push('/kyc'),
                child: Text(buttonLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Wraps any gated action (a button, a card's onTap) so an unverified
/// user is blocked BEFORE the underlying action's form/flow ever
/// opens — matching the real web app's pre-emptive check, not a
/// server-side-only rejection after the user has already filled out
/// a form. Shows the exact real backend error message when tapped.
///
/// For non-interactive children (cards, images) this wraps with a
/// GestureDetector, which is correct. For an already-interactive
/// child (a Button widget with its own gesture handling), wrapping it
/// in an outer GestureDetector creates ambiguous double-handling when
/// verified — use LockedButton below instead for that case.
class LockedAction extends ConsumerWidget {
  const LockedAction(
      {super.key, required this.child, required this.onUnlockedTap});

  final Widget child;
  final VoidCallback onUnlockedTap;

  static const _realBackendMessage =
      'This action requires a verified account. Submit your identity verification and wait for admin approval to unlock buying, selling, and agreements.';

  static void showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verification Required'),
        content: const Text(_realBackendMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not Now')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              dialogContext.push('/kyc');
            },
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVerified = ref.watch(isVerifiedProvider);

    if (isVerified) {
      return GestureDetector(onTap: onUnlockedTap, child: child);
    }

    return GestureDetector(
      onTap: () => showLockedDialog(context),
      child: Opacity(
        opacity: 0.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            const Icon(Icons.lock_outline,
                color: Colors.white,
                size: 20,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
          ],
        ),
      ),
    );
  }
}

/// UW 12.3/12.4: "Verification badge, if identity-verified" on a
/// Farmer/Vendor or Buyer's full profile -- distinct from
/// [VerificationBanner] above, which is always about the CURRENT
/// (logged-in) user's own unverified status, never the profile SUBJECT
/// being viewed. farmer_detail_screen.dart and vendor_detail_screen.dart
/// previously showed [VerificationBanner] on another user's profile
/// page, which renders the viewer's own status, not the profile
/// subject's -- a real bug, not a stylistic choice, fixed by swapping
/// in this widget wherever a profile subject's verification needs to
/// be shown.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.verificationApprovedBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified,
              size: 14, color: AppColors.verificationApprovedFg),
          const SizedBox(width: 4),
          Text('Verified',
              style: AppTypography.label
                  .copyWith(color: AppColors.verificationApprovedFg)),
        ],
      ),
    );
  }
}

/// The correct pattern for a full-width CTA ElevatedButton specifically
/// — unlike LockedAction, this sets the button's OWN onPressed directly
/// (real callback when verified, null+locked-styled when not) rather
/// than wrapping an already-interactive button in an outer
/// GestureDetector, which would double-handle taps when verified.
class LockedButton extends ConsumerWidget {
  const LockedButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false});

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVerified = ref.watch(isVerifiedProvider);

    if (!isVerified) {
      return ElevatedButton.icon(
        onPressed: () => LockedAction.showLockedDialog(context),
        icon: const Icon(Icons.lock_outline, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textMuted,
            foregroundColor: Colors.white),
      );
    }

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent))
          : Text(label),
    );
  }
}
