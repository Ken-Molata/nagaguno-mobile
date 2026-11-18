// lib/features/profile/domain/profile_details.dart
//
// Fields verified against the real GET /profiles/me response this
// session: { data: { user: {...}, profile: {...} } } -- profile's
// shape depends on role (buyer_profiles / farmer_profiles /
// vendor_profiles), each genuinely different, not unified.

class ProfileDetails {
  const ProfileDetails({
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.barangay,
    this.avatarUrl,
    this.aboutMe,
    this.farmName,
    this.farmAddress,
    this.aboutFarm,
    this.farmPhotoUrl,
    this.businessName,
    this.businessAddress,
    this.aboutBusiness,
    this.businessPhotoUrl,
  });

  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? barangay;
  final String? avatarUrl;
  // buyer_profiles only
  final String? aboutMe;
  // farmer_profiles only
  final String? farmName;
  final String? farmAddress;
  final String? aboutFarm;
  final String? farmPhotoUrl;
  // vendor_profiles only
  final String? businessName;
  final String? businessAddress;
  final String? aboutBusiness;
  final String? businessPhotoUrl;

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final profile = json['profile'] as Map<String, dynamic>?;
    final role = user['role'] as String;

    return ProfileDetails(
      fullName: user['full_name'] as String,
      role: role,
      phoneNumber: user['phone_number'] as String?,
      barangay: user['barangay'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      aboutMe: role == 'buyer' ? (profile?['about_me'] as String?) : null,
      farmName: role == 'farmer' ? (profile?['farm_name'] as String?) : null,
      farmAddress:
          role == 'farmer' ? (profile?['farm_address'] as String?) : null,
      aboutFarm: role == 'farmer' ? (profile?['about_farm'] as String?) : null,
      farmPhotoUrl:
          role == 'farmer' ? (profile?['farm_photo_url'] as String?) : null,
      businessName:
          role == 'vendor' ? (profile?['business_name'] as String?) : null,
      businessAddress:
          role == 'vendor' ? (profile?['business_address'] as String?) : null,
      aboutBusiness:
          role == 'vendor' ? (profile?['about_business'] as String?) : null,
      businessPhotoUrl:
          role == 'vendor' ? (profile?['business_photo_url'] as String?) : null,
    );
  }
}
