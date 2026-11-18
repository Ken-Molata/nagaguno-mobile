// lib/features/reports/presentation/report_menu_button.dart
//
// UW 9.1: "A three-dot menu on a user's profile... pre-linked to that
// user directly" AND, as its own separate bullet, "A profile picture
// specifically, from the three-dot menu above." These were previously
// collapsed into a single bare Report flag icon on every profile
// screen (farmer/vendor/buyer detail) -- no profile-picture-specific
// entry point existed anywhere, so a reported avatar could never carry
// its own auto-captured image evidence (routes/reports.js's
// captureOriginalContent avatarUserId branch). Shared here rather than
// tripled across those three screens.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_strings.dart';
import 'report_user_screen.dart';

class ReportMenuButton extends ConsumerWidget {
  const ReportMenuButton({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.fixedGroup,
  });

  final String reportedUserId;
  final String reportedUserName;
  final String fixedGroup;

  void _open(BuildContext context, {bool reportProfilePicture = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportUserScreen(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        fixedGroup: fixedGroup,
        reportProfilePicture: reportProfilePicture,
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.flag_outlined),
      tooltip: s.reportTooltip,
      onSelected: (value) =>
          _open(context, reportProfilePicture: value == 'avatar'),
      itemBuilder: (context) => [
        PopupMenuItem(
            value: 'user', child: Text(s.reportUserLabel(reportedUserName))),
        PopupMenuItem(
            value: 'avatar', child: Text(s.reportProfilePictureLabel)),
      ],
    );
  }
}
