// lib/features/kyc/domain/kyc_models.dart
//
// Every value here verified directly against routes/kyc.js this
// session — the ID_TYPES set, the phone regex, and the exact
// STATUS_MESSAGES copy (reused verbatim below, not reworded, so the
// mobile and web experiences say the identical thing to a user).

export '../../../core/validation/validators.dart' show phPhoneRegex;

/// UW 10.1's Route table, now Admin-editable server-side (migration
/// 027) -- fetched fresh from GET /kyc/id-types rather than trusted
/// from [KycIdType]'s own compile-time route/requiresBack fields
/// alone, so an Admin's edit actually changes what a submission
/// screen asks the user for, not just a value nothing re-reads.
/// [KycIdType] still supplies the selectable dropdown identity/label
/// (which type exists at all doesn't change at runtime), just not the
/// routing behavior.
class IdTypeConfig {
  const IdTypeConfig(
      {required this.idType, required this.route, required this.backRequired, required this.label});
  final String idType;
  final String route;
  final bool backRequired;
  final String label;

  factory IdTypeConfig.fromJson(Map<String, dynamic> json) => IdTypeConfig(
        idType: json['id_type'] as String,
        route: json['route'] as String,
        backRequired: json['back_required'] as bool,
        label: json['label'] as String,
      );
}

/// Re-verified against config/kycRoutes.js (the ACTUAL current source
/// of truth, not routes/kyc.js's own old ID_TYPES set this was first
/// built against) -- that file only had 5 of UW 10.1's 9+ documented
/// ID types, and two of the five had the wrong requiresBack value
/// (philsys_national_id is actually true, voters_id is actually
/// false). Fixed here; also added [route] since account recovery's
/// ID-check step (unlike KYC's own submit, which uploads files for
/// every type regardless) branches on it directly: Route A opens a
/// Didit-hosted verification page with no local upload at all, Route
/// B uploads id_front/id_back/liveness_photo like KYC always does.
enum KycIdType {
  passport('passport', 'Philippine Passport', route: 'A', requiresBack: false),
  philsysNationalId('philsys_national_id', 'PhilSys National ID',
      route: 'A', requiresBack: true),
  driversLicense('drivers_license', "Driver's License (LTO)",
      route: 'A', requiresBack: true),
  umid('umid', 'UMID', route: 'A', requiresBack: true),
  philsysEphilid('philsys_ephilid', 'PhilSys ePhilID',
      route: 'B', requiresBack: false),
  postalId('postal_id', 'Postal ID (PHLPost)', route: 'B', requiresBack: true),
  prcId('prc_id', 'PRC ID', route: 'B', requiresBack: true),
  sssId('sss_id', 'SSS ID', route: 'B', requiresBack: true),
  votersCertification('voters_certification', "Voter's Certification",
      route: 'B', requiresBack: false),
  votersId('voters_id', "Voter's ID (older card)",
      route: 'B', requiresBack: false),
  barangayId('barangay_id_with_certification', 'Barangay ID with Certification',
      route: 'B', requiresBack: false);

  const KycIdType(this.apiValue, this.label,
      {required this.route, required this.requiresBack});
  final String apiValue;
  final String label;

  /// 'A' (Didit-hosted, no local upload) | 'B' (manual upload).
  /// routes/kyc.js's own POST /submit doesn't actually branch mobile's
  /// upload behavior on this today (a pre-existing, separate gap, not
  /// fixed here) -- account recovery's ID-check step does.
  final String route;
  final bool requiresBack;
}

// UW 10.4/10.5: resubmissionRequired is a real third outcome, distinct
// from rejected -- "a persistent 'Verification Rejected' or
// 'Resubmission Required' notice" are two different dashboard labels,
// and only resubmissionRequired carries resubmissionFields (below) for
// a narrower, pre-filled re-capture flow instead of a full redo.
enum KycStatus { none, pending, approved, rejected, resubmissionRequired }

// (phPhoneRegex now comes from core/validation/validators.dart — see
// the import/export at the top of this file, consolidated there to
// avoid a genuine duplicate-definition collision with the
// registration-specific patterns that live in the same shared file.)

class KycSubmissionStatus {
  const KycSubmissionStatus({
    required this.status,
    this.message,
    this.route,
    this.diditStatus,
    this.rejectionReason,
    this.resubmissionFields = const [],
    this.submittedAt,
    this.reviewedAt,
    this.priorDateOfBirth,
    this.priorCompleteAddress,
    this.priorContactNumber,
    this.priorIdType,
  });

  final KycStatus status;

  /// GET /kyc/me now resolves the exact right copy server-side,
  /// including the Route A "complete the steps Didit just opened"
  /// case STATUS_MESSAGES[status] alone can't express — read directly
  /// from there via [displayMessage] rather than duplicating
  /// STATUS_MESSAGES' text on the client (the old copy here had no
  /// Route A case at all and would drift from the backend's own
  /// wording over time).
  final String? message;

  /// 'A' (Didit-hosted, automatic) | 'B' (manual review) | null (not submitted).
  final String? route;
  final String? diditStatus;
  final String? rejectionReason;

  /// UW 10.5: which document(s) the Admin flagged -- only ever
  /// populated when [status] is resubmissionRequired. Keys match
  /// RESUBMISSION_FIELD_LABELS in routes/kyc.js: id_front, id_back,
  /// supporting_doc, liveness, id_type, account_details.
  final List<String> resubmissionFields;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// UW 10.5: "Previously submitted information is retained and
  /// pre-filled rather than cleared" -- the prior submission's own
  /// values, used by the resubmission screen to pre-fill the
  /// always-required fields and lock/display whatever wasn't flagged.
  final DateTime? priorDateOfBirth;
  final String? priorCompleteAddress;
  final String? priorContactNumber;
  final String? priorIdType;

  factory KycSubmissionStatus.fromJson(Map<String, dynamic> json) {
    return KycSubmissionStatus(
      status: _statusFromString(json['status'] as String?),
      message: json['message'] as String?,
      route: json['route'] as String?,
      diditStatus: json['didit_status'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      resubmissionFields:
          (json['resubmission_fields'] as List? ?? []).cast<String>(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      priorDateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      priorCompleteAddress: json['complete_address'] as String?,
      priorContactNumber: json['contact_number'] as String?,
      priorIdType: json['id_type'] as String?,
    );
  }

  static KycStatus _statusFromString(String? s) {
    switch (s) {
      case 'pending':
        return KycStatus.pending;
      case 'approved':
        return KycStatus.approved;
      case 'rejected':
        return KycStatus.rejected;
      case 'resubmission_required':
        return KycStatus.resubmissionRequired;
      default:
        return KycStatus.none;
    }
  }

  String get displayMessage =>
      message ?? 'Verify your account to unlock listing, buying, and selling.';
}

/// POST /kyc/submit's own response shape -- distinct from GET /me's
/// (KycSubmissionStatus above): the data object here is the raw
/// kyc_submissions row (not the same field set) plus verification_url,
/// and the message is a sibling of data, not inside it. Only the two
/// fields the submission screen actually needs are pulled out.
class KycSubmitResult {
  const KycSubmitResult({required this.message, this.verificationUrl});
  final String message;

  /// Present only for a Route A submission -- open this (Didit's
  /// hosted page) right after submitting; null means Route B, nothing
  /// further to do beyond the normal "pending review" state.
  final String? verificationUrl;

  factory KycSubmitResult.fromJson(Map<String, dynamic> body) =>
      KycSubmitResult(
        message: body['message'] as String? ?? 'Verification submitted.',
        verificationUrl: (body['data']
            as Map<String, dynamic>?)?['verification_url'] as String?,
      );
}
