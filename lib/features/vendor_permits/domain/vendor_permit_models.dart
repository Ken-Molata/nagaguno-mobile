// lib/features/vendor_permits/domain/vendor_permit_models.dart
//
// Mirrors routes/vendorPermits.js and migrations/
// 057_vendor_business_permits.sql exactly -- business_permit_type_reference
// (permit_type/label/description) and vendor_business_permits
// (status: pending/approved/rejected).

class BusinessPermitType {
  const BusinessPermitType({
    required this.permitType,
    required this.label,
    required this.description,
  });

  final String permitType;
  final String label;
  final String description;

  factory BusinessPermitType.fromJson(Map<String, dynamic> json) =>
      BusinessPermitType(
        permitType: json['permit_type'] as String,
        label: json['label'] as String,
        description: json['description'] as String? ?? '',
      );
}

class VendorPermitSubmission {
  const VendorPermitSubmission({
    required this.id,
    required this.permitType,
    required this.permitNumber,
    required this.businessName,
    this.tin,
    this.businessAddress,
    this.issuingAuthority,
    this.dateIssued,
    this.expiryDate,
    required this.isExpired,
    required this.status,
    this.rejectionReason,
    required this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String permitType;
  final String permitNumber;
  final String businessName;
  /// BIR Tax Identification Number, as printed on the document --
  /// required by GCash for Business onboarding for every entity type
  /// (see migrations/058's header), kept here as a cross-document
  /// identifier. Nullable only because a submission filed before
  /// migration 058 added this field won't have one -- every new
  /// submission requires it.
  final String? tin;
  final String? businessAddress;
  final String? issuingAuthority;
  final DateTime? dateIssued;
  /// Null when the document itself carries none (e.g. BIR Form 2303
  /// typically doesn't) -- not a missing-data error.
  final DateTime? expiryDate;
  /// Server-computed (expiry_date < today) -- a plain date comparison
  /// against what the submitter themselves entered, never a registry
  /// authenticity check.
  final bool isExpired;
  /// 'pending' | 'approved' | 'rejected'
  final String status;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory VendorPermitSubmission.fromJson(Map<String, dynamic> json) =>
      VendorPermitSubmission(
        id: json['id'] as String,
        permitType: json['permit_type'] as String,
        permitNumber: json['permit_number'] as String,
        businessName: json['business_name'] as String,
        tin: json['tin'] as String?,
        businessAddress: json['business_address'] as String?,
        issuingAuthority: json['issuing_authority'] as String?,
        dateIssued: json['date_issued'] == null
            ? null
            : DateTime.parse(json['date_issued'] as String),
        expiryDate: json['expiry_date'] == null
            ? null
            : DateTime.parse(json['expiry_date'] as String),
        isExpired: json['is_expired'] as bool? ?? false,
        status: json['status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at'] as String),
      );
}

/// Admin review-queue row -- same submission shape plus the vendor's
/// own name and the permit type's human label, joined server-side.
class AdminVendorPermitRow {
  const AdminVendorPermitRow({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.permitType,
    required this.permitTypeLabel,
    required this.permitNumber,
    required this.businessName,
    this.tin,
    this.businessAddress,
    this.issuingAuthority,
    this.dateIssued,
    this.expiryDate,
    required this.isExpired,
    required this.status,
    this.rejectionReason,
    required this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String permitType;
  final String permitTypeLabel;
  final String permitNumber;
  final String businessName;
  /// Nullable: a submission filed before migration 058 added this
  /// field won't have one -- every new submission requires it.
  final String? tin;
  final String? businessAddress;
  final String? issuingAuthority;
  final DateTime? dateIssued;
  final DateTime? expiryDate;
  final bool isExpired;
  final String status;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  factory AdminVendorPermitRow.fromJson(Map<String, dynamic> json) =>
      AdminVendorPermitRow(
        id: json['id'] as String,
        vendorId: json['vendor_id'] as String,
        vendorName: json['vendor_name'] as String,
        permitType: json['permit_type'] as String,
        permitTypeLabel: json['permit_type_label'] as String,
        permitNumber: json['permit_number'] as String,
        businessName: json['business_name'] as String,
        tin: json['tin'] as String?,
        businessAddress: json['business_address'] as String?,
        issuingAuthority: json['issuing_authority'] as String?,
        dateIssued: json['date_issued'] == null
            ? null
            : DateTime.parse(json['date_issued'] as String),
        expiryDate: json['expiry_date'] == null
            ? null
            : DateTime.parse(json['expiry_date'] as String),
        isExpired: json['is_expired'] as bool? ?? false,
        status: json['status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at'] as String),
      );
}

/// Demo-only reference registry (see migrations/057 and
/// routes/vendorPermits.js's own header) -- never a real registry
/// integration, shown to the admin only as a manual cross-check aid.
class DemoRegisteredVendor {
  const DemoRegisteredVendor({
    required this.businessName,
    required this.permitType,
    required this.permitNumber,
    this.tin,
    this.businessAddress,
    this.dateIssued,
    this.expiryDate,
    required this.note,
  });

  final String businessName;
  final String permitType;
  final String permitNumber;
  final String? tin;
  final String? businessAddress;
  /// Added alongside [expiryDate], by explicit request, when the
  /// admin review match moved off (permitType, permitNumber) onto
  /// (permitNumber, tin, dateIssued, expiryDate) -- businessName and
  /// businessAddress are shown for the admin's own eyes but
  /// deliberately play no part in the match itself.
  final DateTime? dateIssued;
  final DateTime? expiryDate;
  final String note;

  factory DemoRegisteredVendor.fromJson(Map<String, dynamic> json) =>
      DemoRegisteredVendor(
        businessName: json['business_name'] as String,
        permitType: json['permit_type'] as String,
        permitNumber: json['permit_number'] as String,
        tin: json['tin'] as String?,
        businessAddress: json['business_address'] as String?,
        dateIssued: json['date_issued'] != null
            ? DateTime.parse(json['date_issued'] as String)
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'] as String)
            : null,
        note: json['note'] as String? ?? '',
      );
}
