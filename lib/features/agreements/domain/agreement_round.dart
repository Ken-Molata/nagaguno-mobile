// lib/features/agreements/domain/agreement_round.dart
//
// One row of the agreement's negotiation history (UW 4.1: "the terms
// being countered remain visible"), returned by
// GET /agreements/:id/rounds. Verified against the real agreement_rounds
// table and routes/agreement.js's insert sites (initial/accept/counter/
// reject/cancel/farmer_adjustment action values).

class AgreementRound {
  const AgreementRound({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.createdAt,
    this.quantity,
    this.pricePerUnit,
    this.deliveryDateStart,
    this.deliveryDateEnd,
    this.reason,
    this.note,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String
      action; // initial | accept | counter | reject | cancel | farmer_adjustment
  final DateTime createdAt;
  final double? quantity;
  final double? pricePerUnit;
  final DateTime? deliveryDateStart;
  final DateTime? deliveryDateEnd;
  final String? reason;
  final String? note;

  factory AgreementRound.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    DateTime? asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return AgreementRound(
      id: json['id'] as String,
      actorId: json['actor_id'] as String,
      actorName: json['actor_name'] as String,
      action: json['action'] as String,
      createdAt: DateTime.parse(json['created_at']),
      quantity: asDouble(json['quantity']),
      pricePerUnit: asDouble(json['price_per_unit']),
      deliveryDateStart: asDate(json['delivery_date_start']),
      deliveryDateEnd: asDate(json['delivery_date_end']),
      reason: json['reason'] as String?,
      note: json['note'] as String?,
    );
  }
}
