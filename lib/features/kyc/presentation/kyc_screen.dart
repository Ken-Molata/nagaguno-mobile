// lib/features/kyc/presentation/kyc_screen.dart
//
// Single entry point for the /kyc route: shows the submission form for
// a first-time or rejected submitter, or a plain-language status
// display (reusing the real backend's STATUS_MESSAGES verbatim) for
// someone already pending or approved — rather than routing these to
// separate screens the user has to know to navigate between.
//
// REAL GAP FOUND AND FIXED: Route A's (Didit) result only ever updated
// here when the user manually tapped "Check Again" -- confirmed this
// session that nothing in the mobile app ever calls GET /kyc/me on its
// own while sitting on this screen, so a real-time approval (or
// rejection) sat unreflected until the user noticed and tapped it
// themselves. This screen now polls automatically every 8 seconds
// while a Route A submission is still pending, so approval/rejection
// surface on their own: approved flips straight to the verified view
// (and refreshes the cached session user so every requireVerified-
// gated action elsewhere in the app unlocks immediately, not just this
// screen), rejected or resubmission_required already routes to
// KycSubmissionScreen automatically (unchanged -- see the status
// check below), prompting the user to resubmit without any extra tap.
// The manual "Check Again" button stays as a backup for the rare case
// a poll tick is missed (e.g. the app was backgrounded).
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
// status.displayMessage reuses the real backend's STATUS_MESSAGES
// verbatim -- server-generated content, not UI chrome, so it stays
// untranslated here the same way notification text does.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../application/kyc_status_provider.dart';
import '../domain/kyc_models.dart';
import 'kyc_submission_screen.dart';

const _pollInterval = Duration(seconds: 8);

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});
  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  Timer? _pollTimer;
  bool _wasApproved = false;

  void _ensurePolling(bool shouldPoll) {
    if (shouldPoll == (_pollTimer != null)) return;
    _pollTimer?.cancel();
    _pollTimer = shouldPoll
        ? Timer.periodic(_pollInterval, (_) => ref.invalidate(kycStatusProvider))
        : null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(kycStatusProvider);
    final s = ref.watch(appStringsProvider);

    final liveStatus = statusAsync.valueOrNull;
    _ensurePolling(
        liveStatus?.route == 'A' && liveStatus?.status == KycStatus.pending);
    if (liveStatus?.status == KycStatus.approved && !_wasApproved) {
      // Only the mobile app's own cached session user needs a nudge --
      // GET /kyc/me and account_status both already reflect this
      // server-side the moment it happened. Scheduled after this frame
      // since it's not safe to trigger another provider update from
      // inside build() itself.
      _wasApproved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          ref.read(authControllerProvider.notifier).refreshUser());
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.verificationTitle)),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            Center(child: Text(s.couldntLoadVerificationStatus)),
        data: (kycStatus) {
          // UW 10.4/10.5: resubmissionRequired must also reach the
          // submission form -- previously only none/rejected did,
          // which left a resubmission_required user stuck on a
          // read-only status screen with no way to act at all. Same
          // reasoning covers a plain rejected status: both already
          // land here automatically, with no extra tap needed, the
          // moment this screen's own poll (or a manual recheck) picks
          // up the decision.
          if (kycStatus.status == KycStatus.none ||
              kycStatus.status == KycStatus.rejected ||
              kycStatus.status == KycStatus.resubmissionRequired) {
            return KycSubmissionScreen(
                rejectionReason: kycStatus.rejectionReason,
                resubmissionFields: kycStatus.resubmissionFields,
                priorDateOfBirth: kycStatus.priorDateOfBirth,
                priorCompleteAddress: kycStatus.priorCompleteAddress,
                priorContactNumber: kycStatus.priorContactNumber,
                priorIdType: kycStatus.priorIdType);
          }
          return _buildStatusView(ref, kycStatus);
        },
      ),
    );
  }

  Widget _buildStatusView(WidgetRef ref, KycSubmissionStatus status) {
    final isApproved = status.status == KycStatus.approved;
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApproved ? Icons.verified : Icons.hourglass_top,
              size: 64,
              color:
                  isApproved ? AppColors.statusSuccessFg : AppColors.accentDark,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(status.displayMessage,
                textAlign: TextAlign.center, style: AppTypography.body),
            // Backup only now -- this screen already polls on its own
            // (see _ensurePolling above) while Route A is pending, so
            // this button is just a manual nudge for the rare missed
            // tick (e.g. the app was backgrounded through one), not
            // the only way to ever see a decision land.
            if (status.route == 'A' && status.status == KycStatus.pending) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                  onPressed: () => ref.invalidate(kycStatusProvider),
                  child: Text(s.checkAgainLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
