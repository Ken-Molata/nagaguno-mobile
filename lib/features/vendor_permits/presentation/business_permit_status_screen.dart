// lib/features/vendor_permits/presentation/business_permit_status_screen.dart
//
// Single entry point for the /business-permit route -- mirrors
// kyc_screen.dart's own pattern exactly: shows the submission form for
// a first-time or rejected vendor, or a plain status display for one
// already pending or approved.
//
// REAL GAP FOUND AND FIXED: before this screen existed,
// BusinessPermitSubmissionScreen was reachable ONLY from onboarding --
// a vendor who tapped "I'll do this later" there had no way back to
// it at all. The 403 a vendor hits at listing time or at a 50kg+
// agreement request (routes/products.js, routes/agreement.js) already
// said "Submit one from your profile (Business Permit)", but no such
// profile entry or route ever existed -- a real dead end, not a
// deliberate simplification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_permits_provider.dart';
import '../domain/vendor_permit_models.dart';
import 'business_permit_submission_screen.dart';

class BusinessPermitStatusScreen extends ConsumerWidget {
  const BusinessPermitStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(myVendorPermitSubmissionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Business Permit Verification')),
      body: submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text("Couldn't load your submission status.")),
        data: (submissions) {
          // Most recent first (GET /vendor-permits/my's own ordering) --
          // a rejected submission can be resubmitted as a new row, so
          // only the latest one determines what this screen shows.
          final latest = submissions.isEmpty ? null : submissions.first;

          if (latest == null || latest.isRejected) {
            return BusinessPermitSubmissionScreen(
              rejectionReason: latest?.rejectionReason,
              onDone: () {
                ref.invalidate(myVendorPermitSubmissionsProvider);
                Navigator.of(context).pop();
              },
            );
          }
          return _buildStatusView(latest);
        },
      ),
    );
  }

  Widget _buildStatusView(VendorPermitSubmission submission) {
    final isApproved = submission.isApproved;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApproved ? Icons.verified : Icons.hourglass_top,
              size: 64,
              color: isApproved
                  ? AppColors.statusSuccessFg
                  : AppColors.accentDark,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isApproved
                  ? 'Your business permit is approved. You can list products and request bulk agreements.'
                  : 'Your submission for "${submission.businessName}" is awaiting admin review.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Submitted ${_fmt(submission.submittedAt)}',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
