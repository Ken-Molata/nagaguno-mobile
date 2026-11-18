// lib/core/theme/app_theme.dart
//
// Design tokens verified directly against the real, live NagaGuno web
// codebase (src/styles/ng.js, src/App.css) during this session's design
// token audit — not invented. Where the web app itself has an
// unresolved inconsistency (documented in that audit — e.g. two
// different card background colors, two different primary-button text
// colors), this file picks the ng.js-aligned value, since that's the
// dominant pattern across the majority of the web app's authenticated
// pages, and notes the alternative in a comment for visibility.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand — verified: 117 occurrences across the web codebase, the
  // single dominant, unambiguous brand color.
  static const primary = Color(0xFF123D26); // C.dark / --green-primary
  static const secondary = Color(0xFF4F6F52); // C.green / --green-mid
  static const lightGreen = Color(0xFF6BA872); // C.lgreen
  static const accent = Color(0xFFD89A1B); // C.gold / --yellow-primary
  static const accentDark = Color(0xFFC07A12); // C.amber / --yellow-dark

  // Backgrounds — the two-stop gradient already in wide use across the
  // web app's page headers.
  static const backgroundStart = Color(0xFFEDF7E8); // C.cream
  static const backgroundEnd = Color(0xFFFCF8D5); // C.cream2

  // Surface — using the ng.js-aligned cream value (#FFFDF4), the more
  // common of the two card-background values found during the audit.
  // The audit's Inconsistency #3 also found #FFFFFF in use elsewhere;
  // if the web app resolves that inconsistency later, update here too.
  static const surface = Color(0xFFFFFDF4);

  // Text
  static const textPrimary =
      Color(0xFF123D26); // matches ng.js pages' usage of brand color as text
  static const textMuted = Color(0xFF4A5D50); // C.muted

  // Borders
  static const border = Color(0xFFD6E2DE); // C.border

  // Status/error
  static const error = Color(0xFFC1443A); // C.err

  // Status badges — background/foreground pairs, verified against the
  // real BADGE object in ng.js. Kept as pairs since the web app always
  // uses them together (light background, darker matching text).
  static const statusPendingBg = Color(0xFFFEF9C3);
  static const statusPendingFg = Color(0xFF92400E);
  static const statusSuccessBg =
      Color(0xFFD1FAE5); // confirmed/delivered/active
  static const statusSuccessFg = Color(0xFF065F46);
  static const statusPreparingBg = Color(0xFFDBEAFE);
  static const statusPreparingFg = Color(0xFF1E40AF);
  static const statusDispatchedBg = Color(0xFFEDE9FE);
  static const statusDispatchedFg = Color(0xFF5B21B6);
  static const statusCancelledBg = Color(0xFFFEE2E2);
  static const statusCancelledFg = Color(0xFF991B1B);

  // Verification-specific — kept as its own semantic group, separate
  // from generic Status/*, mirroring how account_status and order/
  // agreement status are distinct concepts in the real data model.
  static const verificationPendingBg = statusPendingBg;
  static const verificationPendingFg = statusPendingFg;
  static const verificationApprovedBg = statusSuccessBg;
  static const verificationApprovedFg = statusSuccessFg;
  static const verificationRejectedBg = statusCancelledBg;
  static const verificationRejectedFg = statusCancelledFg;

  // Spoilage stage — NOT verified against a web equivalent (the web
  // app expresses these as text/icons in places I reviewed, not a
  // fixed badge-color pair) — these four are a reasonable proposal,
  // not an extracted fact. Flagging that distinction explicitly here
  // since the rest of this file is extracted, not proposed.
  static const spoilageFresh = Color(0xFF166534);
  static const spoilageNear = Color(0xFFC07A12);
  static const spoilageCritical = Color(0xFFC1443A);
  static const spoilageExpired = Color(0xFF6B7280);
}

class AppRadius {
  AppRadius._();
  // The web app's own radius system was found to be inconsistent
  // (Inconsistency #2 in the design audit — 12/14/20px all used for
  // "card" in different files). Picking a single, deliberate mobile
  // scale rather than porting the inconsistency forward.
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class AppTypography {
  AppTypography._();
  static const _heading = 'Fraunces';
  static const _body = 'DMSans';

  static const display = TextStyle(
      fontFamily: _heading,
      fontSize: 40,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.02,
      color: AppColors.textPrimary);
  static const h1 = TextStyle(
      fontFamily: _heading,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const h2 = TextStyle(
      fontFamily: _heading,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const h3 = TextStyle(
      fontFamily: _heading,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const body = TextStyle(
      fontFamily: _body,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary);
  static const bodySmall = TextStyle(
      fontFamily: _body,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted);
  static const label = TextStyle(
      fontFamily: _body,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 0.06);
  static const button =
      TextStyle(fontFamily: _body, fontSize: 14, fontWeight: FontWeight.w600);
}

final ThemeData nagagunoTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.backgroundStart,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.error,
  ),
  fontFamily: 'DMSans',
  textTheme: const TextTheme(
    displayLarge: AppTypography.display,
    headlineLarge: AppTypography.h1,
    headlineMedium: AppTypography.h2,
    headlineSmall: AppTypography.h3,
    bodyLarge: AppTypography.body,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.label,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors
          .accent, // matches ng.js btnPrimary's gold-on-dark-green pairing
      minimumSize: const Size.fromHeight(
          48), // 44-48px minimum touch target, per the mobile UX plan's accessibility requirement
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      textStyle: AppTypography.button,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondary,
      side: const BorderSide(color: AppColors.secondary, width: 1.5),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      textStyle: AppTypography.button,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 2,
    shadowColor: AppColors.primary.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11), // matches ng.js inputSt's real, non-8px-multiple value
  ),
);
