// lib/features/dashboard/domain/dashboard_models.dart
//
// Three genuinely different shapes, matching the three separate real
// backend endpoints (routes/dashboard.js, verified this session) —
// deliberately not unified into one generic "Dashboard" model, since
// the backend itself doesn't treat them as one shape.

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.counterpartyName,
    this.productName,
    this.productImageUrl,
    this.itemQuantity,
    this.itemUnit,
  });
  final String id;
  final String status;
  final double totalAmount;
  final DateTime createdAt;

  /// buyer_name (farmer/vendor dashboards) or seller_name (buyer
  /// dashboard) — normalized to one field name here since the UI
  /// treats it the same way either direction; the real backend uses
  /// different column aliases per endpoint (verified this session).
  final String counterpartyName;

  /// The order's first line item (routes/dashboard.js's own
  /// `fi.*` LATERAL join, same order_items/products pattern already
  /// used by GET /orders) -- a compact dashboard tile shows one
  /// representative product, not every item in a multi-item order.
  /// Null only for the (rare) order with zero items.
  final String? productName;
  final String? productImageUrl;
  final double? itemQuantity;
  final String? itemUnit;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        counterpartyName: (json['seller_name'] ?? json['buyer_name']) as String,
        productName: json['product_name'] as String?,
        productImageUrl: json['product_image_url'] as String?,
        itemQuantity: json['item_quantity'] != null
            ? double.tryParse(json['item_quantity'].toString())
            : null,
        itemUnit: json['item_unit'] as String?,
      );
}

class AgreementSummary {
  const AgreementSummary({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.productName,
    required this.sellerName,
    this.deliveryDate,
    this.productImageUrl,
    this.quantity,
    this.unit,
  });
  final String id;
  final String status;
  final double totalPrice;
  final String productName;
  final String sellerName;
  final DateTime? deliveryDate;

  /// routes/dashboard.js's own COALESCE(p.image_url, cp.image_url) --
  /// an agreement links to either an already-harvested product or a
  /// still-growing crop_plan, never both, so only one side of the
  /// COALESCE is ever non-null for a given row.
  final String? productImageUrl;
  final double? quantity;
  final String? unit;

  factory AgreementSummary.fromJson(Map<String, dynamic> json) =>
      AgreementSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        totalPrice: double.tryParse(json['total_price'].toString()) ?? 0,
        productName: json['product_name'] as String,
        sellerName: json['seller_name'] as String,
        deliveryDate: json['delivery_date'] != null
            ? DateTime.parse(json['delivery_date'])
            : null,
        productImageUrl: json['product_image_url'] as String?,
        quantity: json['quantity'] != null
            ? double.tryParse(json['quantity'].toString())
            : null,
        unit: json['unit'] as String?,
      );
}

class HarvestSummary {
  const HarvestSummary({
    required this.id,
    required this.cropName,
    required this.quantityKg,
    required this.expectedHarvest,
    required this.stage,
    this.daysRemaining,
  });
  final String id;
  final String cropName;
  final double quantityKg;
  final DateTime expectedHarvest;
  final String stage;
  final int? daysRemaining;

  factory HarvestSummary.fromJson(Map<String, dynamic> json) => HarvestSummary(
        id: json['id'] as String,
        cropName: json['crop_name'] as String,
        quantityKg: double.tryParse(json['quantity_kg'].toString()) ?? 0,
        expectedHarvest: DateTime.parse(json['expected_harvest']),
        stage: json['stage'] as String,
        daysRemaining: json['days_remaining'] != null
            ? int.tryParse(json['days_remaining'].toString())
            : null,
      );
}

class BuyerDashboard {
  const BuyerDashboard({
    required this.activeAgreements,
    required this.totalOrders,
    required this.thisMonth,
    required this.savedFarmers,
    required this.recentOrders,
    required this.recentAgreements,
  });
  final int activeAgreements;
  final int totalOrders;
  final double thisMonth;
  final int savedFarmers;
  final List<OrderSummary> recentOrders;
  final List<AgreementSummary> recentAgreements;

  factory BuyerDashboard.fromJson(Map<String, dynamic> json) => BuyerDashboard(
        activeAgreements: json['active_agreements'] as int,
        totalOrders: json['total_orders'] as int,
        thisMonth: (json['this_month'] as num).toDouble(),
        savedFarmers: json['saved_farmers'] as int,
        recentOrders: (json['recent_orders'] as List)
            .map((j) => OrderSummary.fromJson(j))
            .toList(),
        recentAgreements: (json['recent_agreements'] as List)
            .map((j) => AgreementSummary.fromJson(j))
            .toList(),
      );
}

class FarmerDashboard {
  const FarmerDashboard({
    required this.activeAgreements,
    required this.totalOrders,
    required this.thisMonth,
    required this.nextHarvest,
    required this.incomingOrders,
    required this.upcomingHarvests,
  });
  final int activeAgreements;
  final int totalOrders;
  final double thisMonth;

  /// Already pre-formatted by the backend (e.g. "Jan 15", or "—" if
  /// none) — NOT a raw parseable date. Verified this session: the
  /// backend uses toLocaleDateString before sending it.
  final String nextHarvest;
  final List<OrderSummary> incomingOrders;
  final List<HarvestSummary> upcomingHarvests;

  factory FarmerDashboard.fromJson(Map<String, dynamic> json) =>
      FarmerDashboard(
        activeAgreements: json['active_agreements'] as int,
        totalOrders: json['total_orders'] as int,
        thisMonth: (json['this_month'] as num).toDouble(),
        nextHarvest: json['next_harvest'] as String,
        incomingOrders: (json['incoming_orders'] as List)
            .map((j) => OrderSummary.fromJson(j))
            .toList(),
        upcomingHarvests: (json['upcoming_harvests'] as List)
            .map((j) => HarvestSummary.fromJson(j))
            .toList(),
      );
}

class VendorDashboard {
  const VendorDashboard({
    required this.activeListings,
    required this.totalOrders,
    required this.totalRevenue,
    required this.thisMonth,
    required this.activeAgreements,
    required this.recentOrders,
  });
  final int activeListings;
  final int totalOrders;
  final double totalRevenue;
  final double thisMonth;
  final int activeAgreements;
  final List<OrderSummary> recentOrders;

  factory VendorDashboard.fromJson(Map<String, dynamic> json) =>
      VendorDashboard(
        activeListings: json['active_listings'] as int,
        totalOrders: json['total_orders'] as int,
        totalRevenue: (json['total_revenue'] as num).toDouble(),
        thisMonth: (json['this_month'] as num).toDouble(),
        activeAgreements: json['active_agreements'] as int,
        recentOrders: (json['recent_orders'] as List)
            .map((j) => OrderSummary.fromJson(j))
            .toList(),
      );
}
