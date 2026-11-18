// lib/shared/widgets/legal_links.dart
//
// Real UI scaffolding for a real app-store-submission requirement:
// both Apple App Store Review and Google Play policy require a
// privacy policy link for any app collecting personal data -- this
// one collects government ID photos, biometric liveness data,
// addresses, and phone numbers. The actual URLs are deliberately not
// fabricated here (see env_config.dart) -- this widget handles both
// the "configured" and "not yet configured" states honestly, rather
// than pretend a placeholder URL is a real policy.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/configuration/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';

class LegalConsentLine extends ConsumerWidget {
  const LegalConsentLine(
      {super.key, required this.actionVerb, this.actionVerbTl});

  /// e.g. "registering" or "continuing" -- lets the same widget read
  /// naturally in different contexts without hardcoding one phrase.
  final String actionVerb;

  /// The Tagalog equivalent of [actionVerb] (e.g. "pagpaparehistro" for
  /// "registering"). UW 21.5: document titles ("Terms of Service",
  /// "Privacy Policy") stay in English either way -- the linked
  /// documents themselves aren't translated, so translating just their
  /// name here would be misleading about what opens.
  final String? actionVerbTl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrivacyUrl = EnvConfig.privacyPolicyUrl.isNotEmpty;
    final hasTermsUrl = EnvConfig.termsOfServiceUrl.isNotEmpty;
    final isTl = ref.watch(appLanguageProvider) == 'tl';

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTypography.label,
        children: [
          TextSpan(
              text: isTl
                  ? 'Sa pag-${actionVerbTl ?? actionVerb}, sumasang-ayon ka sa aming '
                  : 'By $actionVerb, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: hasTermsUrl ? AppColors.secondary : AppColors.textMuted,
              decoration: hasTermsUrl ? TextDecoration.underline : null,
            ),
            recognizer: hasTermsUrl
                ? (TapGestureRecognizer()
                  ..onTap = () => _open(EnvConfig.termsOfServiceUrl))
                : null,
          ),
          TextSpan(text: isTl ? ' at ' : ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: hasPrivacyUrl ? AppColors.secondary : AppColors.textMuted,
              decoration: hasPrivacyUrl ? TextDecoration.underline : null,
            ),
            recognizer: hasPrivacyUrl
                ? (TapGestureRecognizer()
                  ..onTap = () => _open(EnvConfig.privacyPolicyUrl))
                : null,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Standalone version for a plain tappable link (e.g. a Profile menu
/// item), rather than the inline consent-line phrasing above. Shows a
/// clear, honest message if the URL genuinely hasn't been configured
/// yet, rather than silently doing nothing or trying to launch an
/// empty string.
Future<void> openLegalUrl(
    BuildContext context, String url, String label) async {
  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not yet available.')),
    );
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Couldn\'t open $label.')),
    );
  }
}
