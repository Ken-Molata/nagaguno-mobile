// lib/features/profile/domain/correction_request.dart
//
// UW 21.1's "Request a correction" flow. Reason/detail labels mirror
// routes/profileCorrections.js's REASON_TEXT/REJECTION_REASONS maps
// word for word, same convention as reports' violationTypes copy --
// the server is the real source of truth for which codes are valid.
class CorrectionDetail {
  static const fullName = 'full_name';
  static const dateOfBirth = 'date_of_birth';
  static const both = 'both';
}

const Map<String, String> correctionReasons = {
  'spelling_mistake': 'There is a spelling mistake',
  'name_changed': 'My name changed, for example by marriage',
  'wrong_dob': 'I entered the wrong date of birth',
  'other': 'Other',
};

class MyCorrectionRequest {
  const MyCorrectionRequest({
    required this.id,
    required this.detail,
    required this.reasonCode,
    required this.status,
    required this.createdAt,
    this.requestedFullName,
    this.requestedDateOfBirth,
    this.reasonOther,
    this.adminNotes,
    this.decidedAt,
  });

  final String id;
  final String detail; // 'full_name' | 'date_of_birth' | 'both'
  final String? requestedFullName;
  final DateTime? requestedDateOfBirth;
  final String reasonCode;
  final String? reasonOther;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == 'pending';

  factory MyCorrectionRequest.fromJson(Map<String, dynamic> json) =>
      MyCorrectionRequest(
        id: json['id'] as String,
        detail: json['detail'] as String,
        requestedFullName: json['requested_full_name'] as String?,
        requestedDateOfBirth: json['requested_date_of_birth'] != null
            ? DateTime.tryParse(json['requested_date_of_birth'].toString())
            : null,
        reasonCode: json['reason_code'] as String,
        reasonOther: json['reason_other'] as String?,
        status: json['status'] as String,
        adminNotes: json['admin_notes'] as String?,
        createdAt: DateTime.parse(json['created_at']),
        decidedAt: json['decided_at'] != null
            ? DateTime.parse(json['decided_at'])
            : null,
      );
}
