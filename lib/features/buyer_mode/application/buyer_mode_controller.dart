// lib/features/buyer_mode/application/buyer_mode_controller.dart
//
// UW 1.5: a Farmer or Vendor can source from fellow Farmers/Vendors
// without a second account. This is purely a presentational/context
// toggle -- nothing about it needs a backend flag or a new column.
// A Farmer/Vendor account can already place an order as a buyer today
// (nothing server-side gates that), and whether a given order/
// agreement counts as "placed in buyer mode" is itself fully derivable
// from data that already exists: it's a buyer-mode record exactly when
// the viewer is a Farmer/Vendor AND they are the buyer_id on that
// record (their own sales as a seller always have seller_id == them,
// never buyer_id == them). See isBuyerModeRecord below -- no schema
// change, no new provider endpoint.
//
// In-memory only, not persisted -- resets to the account's own role on
// app restart. UW describes this as a transient browsing context
// ("for the duration of buyer mode"), not a durable account setting,
// so there's nothing here worth the complexity of shared_preferences.
import 'package:flutter_riverpod/flutter_riverpod.dart';

final buyerModeProvider = StateProvider<bool>((ref) => false);

/// True when [recordBuyerId] (an order's or agreement's buyer_id)
/// should carry the "Buyer Mode" label for [viewerRole]/[viewerId] --
/// i.e. a Farmer/Vendor looking at their OWN purchase, not a Buyer
/// account's normal order, and not this same user's sale of their own
/// listing (where they'd be the seller_id, never the buyer_id).
bool isBuyerModeRecord({
  required String? viewerRole,
  required String? viewerId,
  required String recordBuyerId,
}) {
  if (viewerId == null) return false;
  if (viewerRole != 'farmer' && viewerRole != 'vendor') return false;
  return recordBuyerId == viewerId;
}
