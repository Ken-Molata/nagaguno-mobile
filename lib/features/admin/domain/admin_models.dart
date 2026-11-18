// lib/features/admin/domain/admin_models.dart
//
// Fields verified against the real GET /kyc/queue, GET /kyc/:id, and
// GET /admin/analytics responses this session.

class KycQueueItem {
  const KycQueueItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.submittedAt,
    required this.fullName,
    required this.role,
    this.barangay,
  });

  final String id;
  final String userId;
  final String status;
  final DateTime submittedAt;
  final String fullName;
  final String role;
  final String? barangay;

  factory KycQueueItem.fromJson(Map<String, dynamic> json) => KycQueueItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submitted_at']),
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        barangay: json['barangay'] as String?,
      );
}

class KycSubmissionDetail {
  const KycSubmissionDetail({
    required this.id,
    required this.userId,
    required this.status,
    required this.age,
    required this.dateOfBirth,
    required this.completeAddress,
    required this.contactNumber,
    required this.idType,
    required this.fullName,
    required this.role,
    this.barangay,
    this.phoneNumber,
    this.email,
    this.idFrontUrl,
    this.idBackUrl,
    this.supportingDocUrl,
    this.livenessPhotoUrl,
    this.rejectionReason,
    this.route,
    this.livenessResult,
    this.livenessChecks,
    this.headTurnSkipped = false,
    this.livenessOptedOut = false,
    this.routeBCaptureUrls,
  });

  final String id;
  final String userId;
  final String status;
  final int age;
  final DateTime dateOfBirth;
  final String completeAddress;
  final String contactNumber;
  final String idType;
  final String fullName;
  final String role;
  final String? barangay;
  final String? phoneNumber;
  final String? email;
  // All four are short-lived SIGNED urls (verified this session:
  // KYC documents live in a private bucket, never a public one) —
  // don't cache these beyond the current screen session.
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? supportingDocUrl;
  final String? livenessPhotoUrl;
  final String? rejectionReason;

  // UW 10.2 Route B: the four-factor breakdown (same_person,
  // light_response, sequence_match, head_turn) alongside the
  // summarized result, plus the 5-photo capture set replacing the
  // single livenessPhotoUrl above. All null for a Route A submission
  // or one where the user opted out of the check entirely.
  final String? route; // 'A' | 'B'
  final String? livenessResult; // 'passed' | 'failed' | 'inconclusive' | 'not_performed'
  final Map<String, dynamic>? livenessChecks;
  final bool headTurnSkipped;
  final bool livenessOptedOut;
  final Map<String, dynamic>? routeBCaptureUrls;

  factory KycSubmissionDetail.fromJson(Map<String, dynamic> json) =>
      KycSubmissionDetail(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String,
        age: json['age'] as int,
        dateOfBirth: DateTime.parse(json['date_of_birth']),
        completeAddress: json['complete_address'] as String,
        contactNumber: json['contact_number'] as String,
        idType: json['id_type'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        barangay: json['barangay'] as String?,
        phoneNumber: json['phone_number'] as String?,
        email: json['email'] as String?,
        idFrontUrl: json['id_front_url'] as String?,
        idBackUrl: json['id_back_url'] as String?,
        supportingDocUrl: json['supporting_doc_url'] as String?,
        livenessPhotoUrl: json['liveness_photo_url'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        route: json['route'] as String?,
        livenessResult: json['liveness_result'] as String?,
        livenessChecks: json['liveness_checks'] as Map<String, dynamic>?,
        headTurnSkipped: json['head_turn_skipped'] as bool? ?? false,
        livenessOptedOut: json['liveness_opted_out'] as bool? ?? false,
        routeBCaptureUrls:
            json['route_b_capture_urls'] as Map<String, dynamic>?,
      );
}

// Fields verified against the real GET /admin/users and
// GET /admin/users/:id responses (routes/admin.js).
class AdminUserListItem {
  const AdminUserListItem({
    required this.id,
    required this.fullName,
    required this.role,
    required this.accountStatus,
    required this.createdAt,
    this.email,
    this.phoneNumber,
    this.barangay,
    this.suspendedUntil,
    this.lastLoginAt,
  });

  final String id;
  final String fullName;
  // Nullable: a user who registered by phone (UW 1.1/1.2) has no email at
  // all -- `json['email'] as String` here was crashing fromJson for every
  // such account, which is why the real GET /admin/users (confirmed 200
  // with real data via network inspection) still showed "Couldn't load
  // users." in the UI -- the parse, not the request, was failing.
  final String? email;
  final String role;
  final String accountStatus; // 'active' | 'blocked' | 'suspended'
  final DateTime createdAt;
  final String? phoneNumber;
  final String? barangay;
  final DateTime? suspendedUntil;
  final DateTime? lastLoginAt;

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) =>
      AdminUserListItem(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        accountStatus: json['account_status'] as String,
        createdAt: DateTime.parse(json['created_at']),
        phoneNumber: json['phone_number'] as String?,
        barangay: json['barangay'] as String?,
        suspendedUntil: json['suspended_until'] != null
            ? DateTime.parse(json['suspended_until'])
            : null,
        lastLoginAt: json['last_login_at'] != null
            ? DateTime.parse(json['last_login_at'])
            : null,
      );
}

class AdminUserDetail extends AdminUserListItem {
  const AdminUserDetail({
    required super.id,
    required super.fullName,
    required super.role,
    required super.accountStatus,
    required super.createdAt,
    required this.orderCount,
    required this.agreementCount,
    super.email,
    super.phoneNumber,
    super.barangay,
    super.suspendedUntil,
    super.lastLoginAt,
    this.violationStatus,
  });

  final int orderCount;
  final int agreementCount;
  final String? violationStatus;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) =>
      AdminUserDetail(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        accountStatus: json['account_status'] as String,
        createdAt: DateTime.parse(json['created_at']),
        phoneNumber: json['phone_number'] as String?,
        barangay: json['barangay'] as String?,
        suspendedUntil: json['suspended_until'] != null
            ? DateTime.parse(json['suspended_until'])
            : null,
        lastLoginAt: json['last_login_at'] != null
            ? DateTime.parse(json['last_login_at'])
            : null,
        orderCount: int.tryParse(json['order_count'].toString()) ?? 0,
        agreementCount: int.tryParse(json['agreement_count'].toString()) ?? 0,
        // REAL BUG FOUND AND FIXED: utils/violations.js's
        // getViolationIndicator() (routes/admin.js's GET
        // /admin/users/:id, verified live) returns a whole object --
        // {indicator, suspended_until, cod_restricted_until,
        // categories} -- not a bare string. Casting the object
        // directly `as String?` threw a type error on every single
        // user detail fetch (a real Map is never a String), which the
        // screen's catch-all surfaced as "Couldn't load this user.",
        // even though the HTTP request itself succeeded with a 200.
        // The screen only ever displays the summary indicator
        // ('suspended' | 'near_suspension' | null), so that's the one
        // field pulled out here rather than restructuring the model
        // for the rest of the object, which nothing reads today.
        violationStatus: (json['violation_status']
            as Map<String, dynamic>?)?['indicator'] as String?,
      );
}

// ──────────────────────────────────────────────────────────────
// Web admin app models: 7 review queues with zero UI anywhere in
// this codebase before the web admin app, each verified against its
// real GET .../admin/queue, GET .../admin/:id, and POST
// .../admin/:id/decision endpoint this session. Each queue item type
// stays minimal (only what the queue list itself needs); the detail
// type adds whatever that specific admin/:id response includes on
// top.
// ──────────────────────────────────────────────────────────────

class ReportQueueItem {
  const ReportQueueItem({
    required this.id,
    required this.violationGroup,
    required this.violationType,
    required this.createdAt,
    required this.filerName,
    required this.reportedName,
    required this.reportedRole,
  });
  final String id;
  final String violationGroup;
  final String violationType;
  final DateTime createdAt;
  final String filerName;
  final String reportedName;
  final String reportedRole;

  factory ReportQueueItem.fromJson(Map<String, dynamic> json) =>
      ReportQueueItem(
        id: json['id'] as String,
        violationGroup: json['violation_group'] as String,
        violationType: json['violation_type'] as String,
        createdAt: DateTime.parse(json['created_at']),
        filerName: json['filer_name'] as String,
        reportedName: json['reported_name'] as String,
        reportedRole: json['reported_role'] as String,
      );
}

class ReportDetail {
  const ReportDetail({
    required this.id,
    required this.violationGroup,
    required this.violationType,
    required this.essay,
    required this.photoUrls,
    required this.filerName,
    required this.reportedName,
    required this.reportedRole,
    required this.createdAt,
    this.transactionId,
    this.originalContentSnapshot,
    this.originalContentAuthorName,
    this.originalContentImageUrls = const [],
    this.reportedNameAtFiling,
    this.reportedAvatarAtFiling,
  });
  final String id;
  final String violationGroup;
  final String violationType;
  final String? essay;
  final List<String> photoUrls;
  final String filerName;
  final String reportedName;
  final String reportedRole;
  final DateTime createdAt;
  final String? transactionId;

  /// UW 21.8: "A report keeps the reported person's name/picture as
  /// they were when filed, shown beside current ones -- renaming/
  /// re-picturing can never erase evidence." [reportedName] above is
  /// the CURRENT, live name (joined fresh on every fetch) -- these two
  /// are the frozen-at-filing-time snapshot, shown alongside it rather
  /// than replacing it. Null only for a report filed before this
  /// column existed.
  final String? reportedNameAtFiling;
  final String? reportedAvatarAtFiling;

  /// UW 9.1: the auto-captured original content, "exactly as it was"
  /// at filing time -- a message's text, a review's comment, a
  /// listing's name/description, or an order summary. Null for an
  /// avatar-only report (a profile picture has no text content, only
  /// [originalContentImageUrls]).
  final String? originalContentSnapshot;

  /// Who actually posted/sent the original content -- distinct from
  /// [reportedName] when, for instance, a listing is reported by its
  /// seller's account but a message was reported that a *different*
  /// user sent in that context. Null when there's nothing to capture.
  final String? originalContentAuthorName;

  /// A product review's photos, a profile picture, or a message's
  /// image attachment -- whichever the reported content type actually
  /// carries one of (UW 9.1/14.1/12.3/12.4).
  final List<String> originalContentImageUrls;

  factory ReportDetail.fromJson(Map<String, dynamic> json) => ReportDetail(
        id: json['id'] as String,
        violationGroup: json['violation_group'] as String,
        violationType: json['violation_type'] as String,
        essay: json['essay'] as String?,
        photoUrls: (json['photo_urls'] as List? ?? []).cast<String>(),
        filerName: json['filer_name'] as String,
        reportedName: json['reported_name'] as String,
        reportedRole: json['reported_role'] as String,
        createdAt: DateTime.parse(json['created_at']),
        transactionId: (json['order_id'] ?? json['agreement_id']) as String?,
        originalContentSnapshot: json['original_content_snapshot'] as String?,
        originalContentAuthorName:
            json['original_content_author_name'] as String?,
        originalContentImageUrls:
            (json['original_content_image_urls'] as List? ?? [])
                .cast<String>(),
        reportedNameAtFiling: json['reported_user_name_snapshot'] as String?,
        reportedAvatarAtFiling:
            json['reported_user_avatar_snapshot'] as String?,
      );
}

class RefundQueueItem {
  const RefundQueueItem({
    required this.id,
    required this.reasonCode,
    required this.status,
    required this.createdAt,
    required this.escalatedAt,
    required this.buyerName,
    required this.sellerName,
  });
  final String id;
  final String reasonCode;
  final String status;
  final DateTime createdAt;
  final DateTime? escalatedAt;
  final String buyerName;
  final String sellerName;

  factory RefundQueueItem.fromJson(Map<String, dynamic> json) =>
      RefundQueueItem(
        id: json['id'] as String,
        reasonCode: json['reason_code'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at']),
        escalatedAt: json['escalated_at'] != null
            ? DateTime.parse(json['escalated_at'])
            : null,
        buyerName: json['buyer_name'] as String,
        sellerName: json['seller_name'] as String,
      );
}

class AppealQueueItem {
  const AppealQueueItem({
    required this.id,
    required this.targetType,
    required this.createdAt,
    required this.userName,
    required this.role,
  });
  final String id;
  final String targetType; // 'suspension' | 'ban'
  final DateTime createdAt;
  final String userName;
  final String role;

  factory AppealQueueItem.fromJson(Map<String, dynamic> json) =>
      AppealQueueItem(
        id: json['id'] as String,
        targetType: json['target_type'] as String,
        createdAt: DateTime.parse(json['created_at']),
        userName: json['user_name'] as String,
        role: json['role'] as String,
      );
}

class AppealDetail {
  const AppealDetail({
    required this.id,
    required this.targetType,
    required this.counterEvidence,
    required this.photoUrls,
    required this.userName,
    required this.role,
    required this.violationCategory,
    required this.violationReason,
    required this.violationSource,
    this.originalReportEssay,
  });
  final String id;
  final String targetType;
  final String? counterEvidence;
  final List<String> photoUrls;
  final String userName;
  final String role;
  final String violationCategory;
  final String violationReason;
  final String violationSource;
  final String? originalReportEssay;

  factory AppealDetail.fromJson(Map<String, dynamic> json) => AppealDetail(
        id: json['id'] as String,
        targetType: json['target_type'] as String,
        counterEvidence: json['counter_evidence'] as String?,
        photoUrls: (json['photo_urls'] as List? ?? []).cast<String>(),
        userName: json['user_name'] as String,
        role: json['role'] as String,
        violationCategory: json['violation_category'] as String,
        violationReason: json['violation_reason'] as String,
        violationSource: json['violation_source'] as String,
        originalReportEssay:
            (json['original_report'] as Map?)?['essay'] as String?,
      );
}

/// UW 3.3 "Farmer feedback" -- fields verified against the real
/// GET /admin/shelf-life-feedback/queue (routes/admin.js).
class ShelfLifeFeedbackItem {
  const ShelfLifeFeedbackItem({
    required this.id,
    required this.cropName,
    required this.category,
    required this.storageCondition,
    required this.direction,
    required this.observedDays,
    required this.farmerName,
    required this.createdAt,
    this.note,
    this.currentDaysRoomTemp,
    this.currentDaysRefrigerated,
  });
  final String id;
  final String cropName;
  final String category;
  final String storageCondition;
  final String direction; // 'longer' | 'shorter'
  final int observedDays;
  final String? note;
  final String farmerName;
  final DateTime createdAt;

  /// The reference row's current figure for the matching storage
  /// condition (null if this crop has no reference row at all yet) --
  /// shown alongside [observedDays] so the Admin can compare at a glance.
  final int? currentDaysRoomTemp;
  final int? currentDaysRefrigerated;

  factory ShelfLifeFeedbackItem.fromJson(Map<String, dynamic> json) =>
      ShelfLifeFeedbackItem(
        id: json['id'] as String,
        cropName: json['crop_name'] as String,
        category: json['category'] as String,
        storageCondition: json['storage_condition'] as String,
        direction: json['direction'] as String,
        observedDays: json['observed_days'] as int,
        note: json['note'] as String?,
        farmerName: json['farmer_name'] as String,
        createdAt: DateTime.parse(json['created_at']),
        currentDaysRoomTemp: json['shelf_life_days_room_temp'] as int?,
        currentDaysRefrigerated: json['shelf_life_days_refrigerated'] as int?,
      );
}

class CorrectionQueueItem {
  const CorrectionQueueItem({
    required this.id,
    required this.detail,
    required this.reasonCode,
    required this.createdAt,
    required this.userName,
    required this.role,
  });
  final String id;
  final String detail; // 'full_name' | 'date_of_birth' | 'both'
  final String reasonCode;
  final DateTime createdAt;
  final String userName;
  final String role;

  factory CorrectionQueueItem.fromJson(Map<String, dynamic> json) =>
      CorrectionQueueItem(
        id: json['id'] as String,
        detail: json['detail'] as String,
        reasonCode: json['reason_code'] as String,
        createdAt: DateTime.parse(json['created_at']),
        userName: json['user_name'] as String,
        role: json['role'] as String,
      );
}

class CorrectionDetail {
  const CorrectionDetail({
    required this.id,
    required this.detail,
    required this.reasonCode,
    required this.reasonOther,
    required this.documentUrl,
    required this.currentFullName,
    required this.currentDateOfBirth,
    required this.requestedFullName,
    required this.requestedDateOfBirth,
  });
  final String id;
  final String detail;
  final String reasonCode;
  final String? reasonOther;
  final String? documentUrl;
  final String currentFullName;
  final DateTime? currentDateOfBirth;
  final String? requestedFullName;
  final DateTime? requestedDateOfBirth;

  factory CorrectionDetail.fromJson(Map<String, dynamic> json) =>
      CorrectionDetail(
        id: json['id'] as String,
        detail: json['detail'] as String,
        reasonCode: json['reason_code'] as String,
        reasonOther: json['reason_other'] as String?,
        documentUrl: json['document_url'] as String?,
        currentFullName: json['current_full_name'] as String,
        currentDateOfBirth: json['current_date_of_birth'] != null
            ? DateTime.parse(json['current_date_of_birth'])
            : null,
        requestedFullName: json['requested_full_name'] as String?,
        requestedDateOfBirth: json['requested_date_of_birth'] != null
            ? DateTime.parse(json['requested_date_of_birth'])
            : null,
      );
}

class RecoveryQueueItem {
  const RecoveryQueueItem({
    required this.id,
    required this.requestNumber,
    required this.status,
    required this.accountIdentified,
    required this.reason,
    required this.createdAt,
    this.accountFullName,
    this.role,
  });
  final String id;
  final String requestNumber;
  final String status;
  final bool accountIdentified;
  final String reason;
  final DateTime createdAt;
  final String? accountFullName;
  final String? role;

  factory RecoveryQueueItem.fromJson(Map<String, dynamic> json) =>
      RecoveryQueueItem(
        id: json['id'] as String,
        requestNumber: json['request_number'] as String,
        status: json['status'] as String,
        accountIdentified: json['account_identified'] as bool? ?? false,
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['created_at']),
        accountFullName: json['account_full_name'] as String?,
        role: json['role'] as String?,
      );
}

/// Kept as a raw map rather than a fully typed class -- this response
/// is unusually wide (submitted-vs-on-record side by side, plus 7
/// derived flags, UW 2.5's own "each shown with an icon and words"
/// list) and every field here is purely for admin-eyes display, never
/// written back anywhere except through the separate decision call
/// below. Typing all ~30 fields would buy no real safety over reading
/// them once in the detail screen.
typedef RecoveryDetail = Map<String, dynamic>;

class SpoilageListing {
  const SpoilageListing({
    required this.productId,
    required this.name,
    required this.sellerName,
    required this.stage,
    required this.remainingPct,
    this.productStatus,
    this.autoHiddenReason,
  });
  final String productId;
  final String name;
  final String sellerName;
  final String stage;
  final double remainingPct;
  // 'live' | 'hidden' -- GET /spoilage/dashboard now includes a listing
  // the spoilage job already auto-hid on expiry, not just still-live
  // ones, so this and autoHiddenReason let the UI show that distinctly.
  final String? productStatus;
  final String? autoHiddenReason;

  factory SpoilageListing.fromJson(Map<String, dynamic> json) =>
      SpoilageListing(
        productId: json['product_id'] as String,
        name: json['name'] as String,
        sellerName: json['seller_name'] as String? ?? '',
        stage: json['stage'] as String? ?? 'fresh',
        remainingPct:
            double.tryParse(json['remaining_pct'].toString()) ?? 0,
        productStatus: json['product_status'] as String?,
        autoHiddenReason: json['auto_hidden_reason'] as String?,
      );
}

class SpoilageDashboard {
  const SpoilageDashboard({
    required this.listings,
    required this.counts,
    required this.autoDiscountsApplied,
  });
  final List<SpoilageListing> listings;
  final Map<String, int> counts;
  final int autoDiscountsApplied;

  factory SpoilageDashboard.fromJson(Map<String, dynamic> json) =>
      SpoilageDashboard(
        listings: (json['listings'] as List)
            .map((l) => SpoilageListing.fromJson(l))
            .toList(),
        counts: Map<String, int>.from(json['counts'] as Map),
        autoDiscountsApplied: json['auto_discounts_applied'] as int? ?? 0,
      );
}

class AdminOrderListItem {
  const AdminOrderListItem({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.buyerName,
    required this.sellerName,
  });
  final String id;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final String buyerName;
  final String sellerName;

  factory AdminOrderListItem.fromJson(Map<String, dynamic> json) =>
      AdminOrderListItem(
        id: json['id'] as String,
        status: json['status'] as String,
        totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        buyerName: json['buyer_name'] as String,
        sellerName: json['seller_name'] as String,
      );
}

class AdminAgreementListItem {
  const AdminAgreementListItem({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.productName,
    required this.createdAt,
    required this.buyerName,
    required this.sellerName,
  });
  final String id;
  final String status;
  final double totalPrice;
  final String productName;
  final DateTime createdAt;
  final String buyerName;
  final String sellerName;

  factory AdminAgreementListItem.fromJson(Map<String, dynamic> json) =>
      AdminAgreementListItem(
        id: json['id'] as String,
        status: json['status'] as String,
        totalPrice: double.tryParse(json['total_price'].toString()) ?? 0,
        productName: json['product_name'] as String,
        createdAt: DateTime.parse(json['created_at']),
        buyerName: json['buyer_name'] as String,
        sellerName: json['seller_name'] as String,
      );
}

class AdminListingItem {
  const AdminListingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePerUnit,
    required this.unit,
    required this.stockQty,
    required this.status,
    required this.sellerName,
    required this.sellerRole,
    this.shelfLifeDays,
    this.daysElapsed,
    this.spoilageStage,
    this.autoHiddenReason,
  });
  final String id;
  final String name;
  final String category;
  final double pricePerUnit;
  final String unit;
  final double stockQty;
  final String status;
  final String sellerName;
  final String sellerRole;
  // null for a non-perishable listing (routes/admin.js only computes
  // these for is_perishable = true, matching product_spoilage_status's
  // own rule).
  final int? shelfLifeDays;
  final int? daysElapsed;
  final String? spoilageStage; // 'fresh' | 'near_spoilage' | 'critical' | 'expired'
  final String? autoHiddenReason;

  factory AdminListingItem.fromJson(Map<String, dynamic> json) =>
      AdminListingItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        pricePerUnit:
            double.tryParse(json['price_per_unit'].toString()) ?? 0,
        unit: json['unit'] as String,
        stockQty: double.tryParse(json['stock_qty'].toString()) ?? 0,
        status: json['status'] as String,
        sellerName: json['seller_name'] as String,
        sellerRole: json['seller_role'] as String,
        shelfLifeDays: json['shelf_life_days'] != null
            ? int.tryParse(json['shelf_life_days'].toString())
            : null,
        daysElapsed: json['days_elapsed'] != null
            ? int.tryParse(json['days_elapsed'].toString())
            : null,
        spoilageStage: json['spoilage_stage'] as String?,
        autoHiddenReason: json['auto_hidden_reason'] as String?,
      );
}

/// UW 6.1: one seller's running total of unsettled Gateway orders.
class SettlementQueueItem {
  const SettlementQueueItem({
    required this.sellerId,
    required this.sellerName,
    required this.sellerRole,
    required this.orderCount,
    required this.totalOwed,
    required this.hasLinkedAccount,
  });
  final String sellerId;
  final String sellerName;
  final String sellerRole;
  final int orderCount;
  final double totalOwed;
  final bool hasLinkedAccount;

  factory SettlementQueueItem.fromJson(Map<String, dynamic> json) =>
      SettlementQueueItem(
        sellerId: json['seller_id'] as String,
        sellerName: json['seller_name'] as String,
        sellerRole: json['seller_role'] as String,
        orderCount: json['order_count'] as int,
        totalOwed: double.tryParse(json['total_owed'].toString()) ?? 0,
        hasLinkedAccount: json['has_linked_account'] as bool? ?? false,
      );
}

class PlatformFeedbackItem {
  const PlatformFeedbackItem({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.fullName,
    required this.role,
  });
  final String id;
  final String message;
  final DateTime createdAt;
  final String fullName;
  final String role;

  factory PlatformFeedbackItem.fromJson(Map<String, dynamic> json) =>
      PlatformFeedbackItem(
        id: json['id'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at']),
        fullName: json['full_name'] as String,
        role: json['role'] as String,
      );
}

/// UW 8: one row of any of the four report types. Column shape varies
/// per report (see AdminRepository's own doc comments), so this stays
/// a thin, generic wrapper rather than 4 near-identical classes --
/// the report screen already knows which columns to read for which
/// report type it requested.
typedef PlatformReportRow = Map<String, dynamic>;

class AdminAnalytics {
  const AdminAnalytics(
      {required this.usersByRole,
      required this.ordersByStatus,
      required this.totalRevenue});
  final Map<String, int> usersByRole;
  final Map<String, int> ordersByStatus;
  final double totalRevenue;

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    Map<String, int> groupBy(List list, String key) {
      final map = <String, int>{};
      for (final row in list) {
        map[row[key] as String] = int.tryParse(row['count'].toString()) ?? 0;
      }
      return map;
    }

    return AdminAnalytics(
      usersByRole: groupBy(json['users'] as List, 'role'),
      ordersByStatus: groupBy(json['orders'] as List, 'status'),
      totalRevenue:
          double.tryParse((json['revenue']?['total'] ?? '0').toString()) ?? 0,
    );
  }
}
