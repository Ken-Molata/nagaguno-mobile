// lib/features/reports/domain/report_models.dart
//
// UW 9/7.6/17.6/17.7. Violation type labels mirror
// routes/reports.js's VIOLATION_TYPES map exactly, word for word --
// the server is the real source of truth for which (group, type)
// pairs are valid; this client-side copy exists only to render a
// picker, and a mismatch would surface as the server's own 400
// rather than silently accepting something invalid.
class ViolationGroup {
  static const transaction = 'transaction';
  static const nonArrival = 'non_arrival';
  static const buyerConduct = 'buyer_conduct';
  static const sellerConduct = 'seller_conduct';
}

const Map<String, Map<String, String>> violationTypes = {
  ViolationGroup.transaction: {
    'product_quality_issue':
        'Product quality issue (spoiled, mislabeled, or substituted crop)',
    'crop_state_misrepresented':
        'Crop state misrepresented at listing (condition differs from what was described)',
    'non_delivery_despite_payment': 'Non-delivery despite payment',
    'payment_conflict_or_nonpayment': 'Payment conflict or non-payment',
    'other': 'Other',
  },
  ViolationGroup.nonArrival: {
    'delivery_date_passed': 'Estimated delivery date has passed with no update',
    'dispatched_but_never_arrived':
        'Order was marked Dispatched but never arrived',
    'seller_unreachable': 'Seller is unreachable',
    'other': 'Other',
  },
  // RE-AUDIT CORRECTION: restored UW 9.1's own generic conduct/content
  // options (sexual harassment through inappropriate image), missing
  // here the same way they were missing server-side -- see
  // routes/reports.js's VIOLATION_TYPES comment for the full reasoning
  // on why 17.6/17.7's narrower lists don't replace these.
  ViolationGroup.buyerConduct: {
    'harassment_toward_seller':
        'Harassment or abusive language toward a Farmer or Vendor',
    'repeated_unpaid_online_orders':
        'Repeatedly placing Online Payment orders and never submitting proof of payment',
    'false_or_malicious_report':
        'Filed a report against a seller found to be deliberately false or malicious',
    'sexual_harassment': 'Sexual harassment',
    'animal_abuse': 'Animal abuse',
    'hate_speech_or_discrimination': 'Hate speech or discrimination',
    'cursing_or_profanity': 'Cursing or profanity',
    'spam_or_scam': 'Spam or scam attempt',
    'impersonation_or_fake_account': 'Impersonation or fake account',
    'inappropriate_or_offensive_image': 'Inappropriate or offensive image',
    'other': 'Other',
  },
  ViolationGroup.sellerConduct: {
    'harassment_toward_buyer': 'Harassment or abusive language toward a Buyer',
    'harassment_toward_fellow_seller':
        'Harassment or abusive language toward a fellow Farmer or Vendor (when sourcing from them in buyer mode)',
    'false_or_malicious_report':
        'Filed a report against a buyer found to be deliberately false or malicious',
    'sexual_harassment': 'Sexual harassment',
    'animal_abuse': 'Animal abuse',
    'hate_speech_or_discrimination': 'Hate speech or discrimination',
    'cursing_or_profanity': 'Cursing or profanity',
    'spam_or_scam': 'Spam or scam attempt',
    'impersonation_or_fake_account': 'Impersonation or fake account',
    'inappropriate_or_offensive_image': 'Inappropriate or offensive image',
    'other': 'Other',
  },
};

/// Which conduct group applies to reporting a given [reportedUserRole]
/// -- matches routes/reports.js's own role check exactly (buyer_conduct
/// only against a Buyer, seller_conduct only against a Farmer/Vendor).
String conductGroupFor(String reportedUserRole) => reportedUserRole == 'buyer'
    ? ViolationGroup.buyerConduct
    : ViolationGroup.sellerConduct;

class MyReport {
  const MyReport({
    required this.id,
    required this.violationGroup,
    required this.violationType,
    required this.status,
    required this.createdAt,
    this.adminReason,
    this.decidedAt,
  });

  final String id;
  final String violationGroup;
  final String violationType;
  final String
      status; // 'pending' | 'verified' | 'dismissed' | 'more_info_requested'
  final String? adminReason;
  final DateTime createdAt;
  final DateTime? decidedAt;

  String get violationLabel =>
      violationTypes[violationGroup]?[violationType] ?? violationType;

  factory MyReport.fromJson(Map<String, dynamic> json) => MyReport(
        id: json['id'] as String,
        violationGroup: json['violation_group'] as String,
        violationType: json['violation_type'] as String,
        status: json['status'] as String,
        adminReason: json['admin_reason'] as String?,
        createdAt: DateTime.parse(json['created_at']),
        decidedAt: json['decided_at'] != null
            ? DateTime.parse(json['decided_at'])
            : null,
      );
}
