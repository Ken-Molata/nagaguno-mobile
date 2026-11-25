// lib/features/vendor_permits/application/vendor_permits_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../data/vendor_permits_repository.dart';
import '../domain/vendor_permit_models.dart';

final vendorPermitsRepositoryProvider = Provider<VendorPermitsRepository>((ref) {
  return VendorPermitsRepository(ref.watch(apiClientProvider));
});

final businessPermitTypesProvider =
    FutureProvider.autoDispose<List<BusinessPermitType>>((ref) async {
  return ref.watch(vendorPermitsRepositoryProvider).getReferenceTypes();
});

/// Most recent submission first, same ordering as GET /vendor-permits/my.
/// null when the vendor has never submitted anything.
final myVendorPermitSubmissionsProvider =
    FutureProvider.autoDispose<List<VendorPermitSubmission>>((ref) async {
  return ref.watch(vendorPermitsRepositoryProvider).getMySubmissions();
});
