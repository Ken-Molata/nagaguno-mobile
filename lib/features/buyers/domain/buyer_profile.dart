// lib/features/buyers/domain/buyer_profile.dart
//
// UW 12.4 Buyer Profile (Full View). Fields verified against the real
// GET /profiles/buyers/:id this session. No buyer_profiles table
// exists (buyers have no farm/business "about" equivalent the way
// Farmer/Vendor profiles do), so there is deliberately no aboutText
// field here -- UW 12.4 lists "About text, if provided," and for a
// Buyer nothing is ever provided, the same honest omission the backend
// makes.

/// One past order or agreement between this buyer and the specific
/// Farmer/Vendor viewing the profile -- NOT the buyer's full
/// platform-wide history (UW 12.4 is explicit about that scoping).
class BuyerTransactionSummary {
  const BuyerTransactionSummary({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String kind; // 'order' | 'agreement'
  final String status;
  final double amount;
  final DateTime createdAt;

  factory BuyerTransactionSummary.fromOrderJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return BuyerTransactionSummary(
      id: json['id'] as String,
      kind: 'order',
      status: json['status'] as String,
      amount: asDouble(json['total_amount']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory BuyerTransactionSummary.fromAgreementJson(
      Map<String, dynamic> json) {
    double asDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return BuyerTransactionSummary(
      id: json['id'] as String,
      kind: 'agreement',
      status: json['status'] as String,
      amount: asDouble(json['total_price']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class BuyerProfile {
  const BuyerProfile({
    required this.id,
    required this.fullName,
    this.barangay,
    this.avatarUrl,
    this.createdAt,
    this.isVerified = false,
    this.transactions = const [],
  });

  final String id;
  final String fullName;
  final String? barangay;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isVerified;

  /// Orders and agreements between this buyer and the viewing
  /// Farmer/Vendor, newest first.
  final List<BuyerTransactionSummary> transactions;

  factory BuyerProfile.fromJson(Map<String, dynamic> json) {
    final orders = (json['orders'] as List? ?? [])
        .map((o) => BuyerTransactionSummary.fromOrderJson(o))
        .toList();
    final agreements = (json['agreements'] as List? ?? [])
        .map((a) => BuyerTransactionSummary.fromAgreementJson(a))
        .toList();
    final transactions = [...orders, ...agreements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return BuyerProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      barangay: json['barangay'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      transactions: transactions,
    );
  }
}
