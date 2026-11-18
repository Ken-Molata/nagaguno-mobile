// lib/features/kyc/presentation/kyc_resume_refresher.dart
//
// REAL GAP FOUND AND FIXED: Didit's hosted verification page opens in
// the device's EXTERNAL browser (kyc_submission_screen.dart's own
// launchUrl(..., mode: LaunchMode.externalApplication)), not an
// in-app webview -- no custom URL scheme/deep link is configured to
// bring the user straight back into this app when they finish there,
// so this app backgrounds and simply waits. Before this fix, coming
// back only refreshed KYC status LAZILY, whenever the user happened to
// revisit the KYC screen specifically (GET /kyc/me's own
// poll-Didit-if-no-webhook-arrived-yet fallback) -- everywhere else in
// the app (home screen banners, feature gating) could keep showing a
// stale "pending" status in the meantime. The actual approve/reject
// decision is already applied automatically server-side the moment
// Didit's webhook lands (routes/kyc.js's applyDiditDecision, confirmed
// this session) in the overwhelming majority of cases -- this fix is
// purely about the APP noticing that immediately on return, instead of
// only when the user happens to look at the one screen that checks.
//
// Wraps the whole app (same "sibling of the routed child" placement as
// InactivityListener in main.dart's MaterialApp.router builder) so it
// applies no matter which screen is on top when the user switches back.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/kyc_status_provider.dart';

class KycResumeRefresher extends ConsumerStatefulWidget {
  const KycResumeRefresher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<KycResumeRefresher> createState() => _KycResumeRefresherState();
}

class _KycResumeRefresherState extends ConsumerState<KycResumeRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(kycStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
