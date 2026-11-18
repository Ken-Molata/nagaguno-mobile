// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/domain/nagaguno_user.dart';
import '../../kyc/application/kyc_status_provider.dart';
import '../../accessibility/presentation/accessibility_settings_screen.dart';
import '../../conversations/application/conversations_unread_provider.dart';
import '../../reports/presentation/my_reports_screen.dart';
import '../../onboarding/presentation/preferences_settings_screen.dart';
import '../../blocks/presentation/blocked_users_screen.dart';
import 'account_settings_screen.dart';
import 'request_correction_screen.dart';
import 'violation_indicator_badge.dart';
import '../../../core/configuration/env_config.dart';
import '../../../shared/widgets/legal_links.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isVerified = ref.watch(isVerifiedProvider);
    final unreadMessages =
        ref.watch(conversationsUnreadCountProvider).valueOrNull;
    final s = ref.watch(appStringsProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // UW 17.3: "the account is marked with a red indicator...
            // visible only to the account holder, on their own
            // profile, and to Admin." Was previously shown only to
            // Admin (admin_users_screen.dart); the account holder's
            // own view had nothing at all.
            const ViolationIndicatorBadge(),
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.backgroundStart,
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: AppTypography.display
                      .copyWith(fontSize: 32, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
                child: Text(user.fullName,
                    style: AppTypography.h1, textAlign: TextAlign.center)),
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.backgroundStart,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(
                    switch (user.role) {
                      'buyer' => s.buyer,
                      'farmer' => s.farmer,
                      'vendor' => s.vendor,
                      _ =>
                        user.role[0].toUpperCase() + user.role.substring(1),
                    },
                    style: AppTypography.label),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // UW 21.1: "Your verified details" -- a locked card, since
            // full name, date of birth, and age are used to verify the
            // account's identity (Section 10) and to confirm ownership
            // for locked-out recovery (Section 2.5), so they can't be
            // freely edited the way the rest of Profile can.
            _VerifiedDetailsCard(user: user, isVerified: isVerified, s: s),
            const SizedBox(height: AppSpacing.lg),

            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(s.editProfile),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _ProfileTile(
              icon: isVerified ? Icons.verified : Icons.error_outline,
              iconColor:
                  isVerified ? AppColors.statusSuccessFg : AppColors.accentDark,
              title: isVerified ? s.verifiedAccount : s.verificationRequired,
              onTap: () => context.push('/kyc'),
            ),
            // UW 21.2: tapping through to change either, which had no
            // screen at all before this (display-only tiles previously).
            // REAL GAP FOUND AND FIXED: the subtitle below is UW 21.2's
            // "Settings shows 'Waiting for verification of [new email]'"
            // persistent pending-change indicator -- previously nothing
            // showed this at all outside the live request/confirm flow;
            // see NagagunoUser.pendingEmail's own doc comment.
            //
            // REAL GAP FOUND AND FIXED: "Verify Email Now" used to be
            // its own separate tile underneath this one, shown any time
            // email existed and wasn't verified -- which fired for the
            // exact same unverified email in two places at once, and
            // read as a second, unrelated settings item rather than a
            // state of this one. Folded in: the unverified state is now
            // this row's own subtitle/icon, and tapping it goes straight
            // to the verify screen instead of the change-email screen
            // while that's still the pending action (pendingEmail,
            // a separate, already-in-progress change, still takes the
            // row to change-email as before so that flow can be viewed
            // or cancelled).
            if (user.email != null)
              _ProfileTile(
                  icon: user.isEmailVerified || user.pendingEmail != null
                      ? Icons.email_outlined
                      : Icons.mark_email_unread_outlined,
                  iconColor: user.isEmailVerified || user.pendingEmail != null
                      ? null
                      : AppColors.accentDark,
                  title: user.email!,
                  subtitle: user.pendingEmail != null
                      ? 'Waiting for verification of ${user.pendingEmail}'
                      : user.isEmailVerified
                          ? null
                          : s.notVerifiedTapToVerify,
                  onTap: () => context.push(
                      user.isEmailVerified || user.pendingEmail != null
                          ? '/profile/change-email'
                          : '/verify-email')),
            // REAL GAP FOUND AND FIXED: this tile used to be hidden
            // entirely when phoneNumber was null, leaving an
            // email-only-registered account no way to ever add one --
            // including no way to act on requestEnableTwoFactor's own
            // "Add a phone number before turning on two-factor
            // authentication" instruction. ContactChangeScreen's
            // request flow already supports adding one from scratch
            // (requestPhoneChange never required an existing
            // phone_number); this tile just needs to always be shown.
            // Same fold-in as the email row above, for the same reason
            // (a phone-registered account's one activation step is
            // this instead of email -- see middleware/auth.js's
            // requireVerified and PhoneVerificationScreen's own header
            // comment).
            _ProfileTile(
                icon: user.phoneNumber == null ||
                        user.isPhoneVerified ||
                        user.pendingPhoneNumber != null
                    ? Icons.phone_outlined
                    : Icons.mark_chat_unread_outlined,
                iconColor: user.phoneNumber == null ||
                        user.isPhoneVerified ||
                        user.pendingPhoneNumber != null
                    ? null
                    : AppColors.accentDark,
                title: user.phoneNumber ?? s.addPhoneNumber,
                subtitle: user.pendingPhoneNumber != null
                    ? 'Waiting for verification of ${user.pendingPhoneNumber}'
                    : (user.phoneNumber != null && !user.isPhoneVerified)
                        ? s.notVerifiedTapToVerify
                        : null,
                onTap: () => context.push(
                    (user.phoneNumber != null &&
                            !user.isPhoneVerified &&
                            user.pendingPhoneNumber == null)
                        ? '/verify-phone'
                        : '/profile/change-phone')),
            // UW 21.2: Password, Two-Factor Authentication, Logged-in
            // Devices -- previously had no screen, and for Password
            // and Devices, no backend endpoint either.
            _ProfileTile(
                icon: Icons.security_outlined,
                title: s.accountAndSecurity,
                onTap: () => context.push('/profile/account-security')),
            _ProfileTile(
                icon: Icons.notifications_outlined,
                title: s.notifications,
                onTap: () => context.push('/notifications')),
            // UW 13. Badge polled every 30s via conversationsUnreadCountProvider
            // (UW 13.1/15.2) while this screen is visible.
            _ProfileTile(
                icon: Icons.chat_bubble_outline,
                title: s.messages,
                badgeCount: unreadMessages,
                onTap: () => context.push('/conversations')),
            // UW 1.2/21.3: the receiving details a buyer sees when
            // paying via Manual Transfer -- only meaningful for a
            // seller, not a buyer (who never receives payments here).
            if (user.role == 'farmer' || user.role == 'vendor')
              _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: s.paymentMethods,
                  onTap: () => context.push('/payment-methods')),
            // UW 17.5: reachable here even with no active penalty, so
            // someone with a COD restriction (which never forces them
            // to this screen the way a ban/suspension does) can still
            // find it and appeal, or just check a past appeal's status.
            _ProfileTile(
                icon: Icons.gavel_outlined,
                title: s.accountStatusAndAppeals,
                onTap: () => context.push('/account-status')),
            // UW 9: status of reports you've filed against other
            // users (not the admin review queue -- that stays
            // web-only, same as the rest of admin decision-making).
            _ProfileTile(
                icon: Icons.flag_outlined,
                title: s.myReports,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MyReportsScreen()))),
            // UW 9.3: review/undo blocks made from a profile's
            // BlockUserButton -- see that widget's own header comment.
            _ProfileTile(
                icon: Icons.block_outlined,
                title: s.blockedUsers,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BlockedUsersScreen()))),
            // UW 14.4.
            _ProfileTile(
                icon: Icons.feedback_outlined,
                title: s.sendFeedback,
                onTap: () => context.push('/feedback')),
            // UW 21.4: "Shown to Buyers and to Vendors in their
            // buying capacity" -- Farmer excluded, matching the spec
            // text exactly. REAL BUG FOUND AND FIXED: this used to
            // route unconditionally, for every role, straight into
            // the first-time registration wizard (OnboardingFlowScreen)
            // which always starts from a blank selection -- see
            // PreferencesSettingsScreen's own header comment for why
            // that's wrong for a "Settings" entry point.
            if (user.isBuyer || user.isVendor)
              _ProfileTile(
                  icon: Icons.tune_outlined,
                  title: s.preferencesAndInterests,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PreferencesSettingsScreen()))),
            // UW 2.3: "may replay it later from account settings or a
            // help menu" -- this app has no separate help menu, so
            // Settings is the one real entry point.
            _ProfileTile(
                icon: Icons.explore_outlined,
                title: s.appWalkthrough,
                onTap: () => context.push('/walkthrough')),
            // UW 1.4/21.5/21.7.
            _ProfileTile(
                icon: Icons.language_outlined,
                title: s.languageAndNotifications,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen()))),
            _ProfileTile(
                icon: Icons.accessibility_new_outlined,
                title: s.accessibility,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AccessibilitySettingsScreen()))),
            _ProfileTile(
                icon: Icons.privacy_tip_outlined,
                title: s.privacyPolicy,
                onTap: () => openLegalUrl(
                    context, EnvConfig.privacyPolicyUrl, s.privacyPolicy)),
            _ProfileTile(
                icon: Icons.description_outlined,
                title: s.termsOfService,
                onTap: () => openLegalUrl(
                    context, EnvConfig.termsOfServiceUrl, s.termsOfService)),
            const SizedBox(height: AppSpacing.lg),

            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(s.logOutQuestion),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(s.cancel)),
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(s.logOut)),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: Text(s.logOut, style: const TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedDetailsCard extends StatelessWidget {
  const _VerifiedDetailsCard(
      {required this.user, required this.isVerified, required this.s});
  final NagagunoUser user;
  final bool isVerified;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final dob = user.dateOfBirth;
    final dobLabel = dob == null ? '—' : '${dob.month}/${dob.day}/${dob.year}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.backgroundStart,
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(s.yourVerifiedDetails, style: AppTypography.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(s.verifiedDetailsCannotBeEdited,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(label: s.detailFullName, value: user.fullName),
          _DetailRow(label: s.detailDateOfBirth, value: dobLabel),
          _DetailRow(
              label: s.detailAge, value: user.age != null ? '${user.age}' : '—'),
          const SizedBox(height: AppSpacing.sm),
          if (isVerified)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RequestCorrectionScreen())),
                child: Text(s.requestACorrection),
              ),
            )
          else
            Text(s.detailWrongWillBeAskedAtReview,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: AppTypography.body)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(
      {required this.icon,
      required this.title,
      this.iconColor,
      this.onTap,
      this.badgeCount,
      this.subtitle});
  final IconData icon;
  final String title;
  final Color? iconColor;
  final VoidCallback? onTap;
  final int? badgeCount;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textMuted),
      title: Text(title, style: AppTypography.body),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.accentDark))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount != null && badgeCount! > 0)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: AppTypography.label.copyWith(color: Colors.white)),
            ),
          if (onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
