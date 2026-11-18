// lib/features/kyc/application/kyc_status_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../data/kyc_repository.dart';
import '../domain/kyc_models.dart';
import '../../authentication/application/auth_controller.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(ref.watch(apiClientProvider));
});

/// The single source of truth every gated-action check in the app reads
/// from. Re-fetches automatically whenever auth state changes (login,
/// logout, or a fresh session restore), so a stale verification status
/// from a previous session/account can never leak into the current one.
final kycStatusProvider =
    FutureProvider.autoDispose<KycSubmissionStatus>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.status != AuthStatus.authenticated) {
    return const KycSubmissionStatus(status: KycStatus.none);
  }
  final repo = ref.watch(kycRepositoryProvider);
  return repo.getMyStatus();
});

/// The single source of truth every gated-action check in the app reads
/// from. Deliberately reads the AUTHENTICATED USER's account_status
/// (via authControllerProvider), not the KYC submission's own status —
/// these are two different fields (verified directly against the real
/// requireVerified middleware this session: it checks
/// req.user.account_status, never the kyc_submissions table directly).
/// An 'approved' KYC submission is what CAUSES account_status to flip
/// to 'active' server-side, but this provider checks the effect, not
/// the cause, matching exactly what the backend actually gates on.
final isVerifiedProvider = Provider.autoDispose<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user?.isVerified ?? false;
});
