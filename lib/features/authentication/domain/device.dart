// lib/features/authentication/domain/device.dart
//
// UW 21.2 "Logged-in devices": "A list of the devices currently
// signed in to the account, each showing the device name and last
// active time, with the current one marked 'This device.'" Fields
// match GET /auth/devices (controllers/authController.js's
// listDevices) exactly.

class Device {
  const Device({
    required this.id,
    required this.deviceInfo,
    required this.createdAt,
    required this.isCurrent,
    this.ipAddress,
  });

  final String id;

  /// The request's User-Agent header at login, truncated server-side
  /// -- not a parsed "iPhone 14" style name, since no device-naming
  /// step exists anywhere in this app's auth flow.
  final String? deviceInfo;
  final String? ipAddress;

  /// Doubles as "last active time" -- see listDevices's own comment
  /// for why that's correct here, not an approximation.
  final DateTime createdAt;
  final bool isCurrent;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        deviceInfo: json['device_info'] as String?,
        ipAddress: json['ip_address'] as String?,
        createdAt: DateTime.parse(json['created_at']),
        isCurrent: json['is_current'] as bool? ?? false,
      );
}
