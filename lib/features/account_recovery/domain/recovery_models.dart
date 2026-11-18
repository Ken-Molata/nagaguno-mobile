// lib/features/account_recovery/domain/recovery_models.dart
//
// UW 2.5: Locked-Out Account Recovery. Fields verified directly
// against routes/accountRecovery.js's real Step 1/2/3 responses and
// GET /account-recovery/check this session — a feature with a fully
// working, fairly involved backend (enumeration-safe identity check,
// Didit Route A/B id-check, admin review queue) and no mobile screen
// at all before this.

// UW 2.5's predefined reason list (utils/accountRecovery.js's
// REASON_LABELS) -- 'other' pairs with a free-text reasonOther.
const recoveryReasons = {
  'lost_phone': 'I lost my phone',
  'number_changed': 'My phone number changed or is no longer in use',
  'cant_open_email':
      "I can't open my email account (forgot its password or it was closed)",
  'taken_over': 'My email or phone number was taken over by someone else',
  'other': 'Other',
};

/// Step 1 (POST /account-recovery/verify-identity) result. [token]
/// carries state forward to Step 2 -- nothing is persisted server-side
/// yet at this point.
class IdentityCheckResult {
  const IdentityCheckResult({
    required this.accountIdentified,
    required this.token,
    this.accountNeverVerified,
    this.idTypeOnRecord,
  });

  final bool accountIdentified;
  final String token;

  /// Only meaningful when accountIdentified is true -- whether there's
  /// a prior approved KYC submission to compare the new ID check
  /// against at all.
  final bool? accountNeverVerified;
  final String? idTypeOnRecord;

  factory IdentityCheckResult.fromJson(Map<String, dynamic> json) =>
      IdentityCheckResult(
        accountIdentified: json['accountIdentified'] as bool,
        token: json['token'] as String,
        accountNeverVerified: json['accountNeverVerified'] as bool?,
        idTypeOnRecord: json['idTypeOnRecord'] as String?,
      );
}

/// Step 2 (POST /account-recovery/id-check) result. [route] 'A' means
/// [verificationUrl] must be opened (Didit-hosted, no local upload);
/// 'B' means the upload already happened in this same call.
class IdCheckResult {
  const IdCheckResult(
      {required this.token, required this.route, this.verificationUrl});
  final String token;
  final String route;
  final String? verificationUrl;

  factory IdCheckResult.fromJson(Map<String, dynamic> json) => IdCheckResult(
        token: json['token'] as String,
        route: json['route'] as String,
        verificationUrl: json['verification_url'] as String?,
      );
}

/// Step 3 (POST /account-recovery/submit) result -- the only step that
/// actually creates a recovery_requests row.
class RecoverySubmitResult {
  const RecoverySubmitResult(
      {required this.requestNumber, required this.status});
  final String requestNumber;
  final String status;

  factory RecoverySubmitResult.fromJson(Map<String, dynamic> json) =>
      RecoverySubmitResult(
        requestNumber: json['request_number'] as String,
        status: json['status'] as String,
      );
}

enum RecoveryRequestStatus {
  awaitingReview,
  moreInfoNeeded,
  approved,
  rejected,
  cancelled,
  expired,
  unknown
}

/// UW 2.5's predefined "what's needed" checklist
/// (utils/../routes/accountRecovery.js's MORE_INFO_LABELS) -- drives
/// which fields RecoveryRespondScreen shows. 'other' pairs with the
/// Admin's own free-text ask (surfaced via moreInfoRequested) and the
/// user's otherResponse reply.
const recoveryMoreInfoLabels = {
  'retake_id_photo': 'Retake the ID photo',
  'repeat_selfie': 'Repeat the selfie check',
  'contact': 'Enter the email or phone number the account was registered with',
};

/// GET /account-recovery/check result (no login needed -- request
/// number + date of birth is the lookup key).
class RecoveryCheckResult {
  const RecoveryCheckResult({
    required this.requestNumber,
    required this.status,
    this.rejectionReason,
    this.moreInfoRequested,
    this.moreInfoItems = const [],
    this.idType,
    this.backRequired = false,
  });

  final String requestNumber;
  final RecoveryRequestStatus status;

  /// Already resolved to display text server-side (same
  /// resolveReason-before-storage pattern used elsewhere in this
  /// backend) -- not a code needing client-side remapping.
  final String? rejectionReason;
  final String? moreInfoRequested;

  /// Structured keys from recoveryMoreInfoLabels -- only meaningful
  /// when status is moreInfoNeeded. moreInfoRequested is the same ask
  /// as already-joined display text; this is what RecoveryRespondScreen
  /// actually branches on.
  final List<String> moreInfoItems;

  /// Needed to know whether a retake_id_photo ask also needs a back
  /// image -- the live, Admin-editable Route table, same as every
  /// other step in this flow.
  final String? idType;
  final bool backRequired;

  factory RecoveryCheckResult.fromJson(Map<String, dynamic> json) =>
      RecoveryCheckResult(
        requestNumber: json['request_number'] as String,
        status: _statusFrom(json['status'] as String?),
        rejectionReason: json['rejection_reason'] as String?,
        moreInfoRequested: json['more_info_requested'] as String?,
        moreInfoItems: (json['more_info_items'] as List?)?.cast<String>() ??
            const [],
        idType: json['id_type'] as String?,
        backRequired: json['back_required'] as bool? ?? false,
      );

  static RecoveryRequestStatus _statusFrom(String? s) => switch (s) {
        'awaiting_review' => RecoveryRequestStatus.awaitingReview,
        'more_info_needed' => RecoveryRequestStatus.moreInfoNeeded,
        'approved' => RecoveryRequestStatus.approved,
        'rejected' => RecoveryRequestStatus.rejected,
        'cancelled' => RecoveryRequestStatus.cancelled,
        'expired' => RecoveryRequestStatus.expired,
        _ => RecoveryRequestStatus.unknown,
      };
}
