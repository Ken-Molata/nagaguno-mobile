// lib/shared/widgets/map_pin_picker_screen.dart
//
// Shopee-style "pin your location" picker: a simple, no-API-key map
// (OpenStreetMap tiles via flutter_map -- the user's own choice over
// Google Maps, which would need a real Cloud Console billing key, the
// same category of manual setup as Google Sign-In's own disclosed
// gap). Centered on Naga City by default; the user pans the map under
// a fixed center pin and confirms, same interaction Shopee's own
// address-pin screen uses (not tap-anywhere-to-drop, which is fiddlier
// on a small screen and easy to misplace with a fat finger).
//
// Deliberately simple, per the actual request ("just a simple [pin]
// then they can update"): no "use my current location" GPS button
// (would need location-permission handling, a separate scope), no
// search-by-address box, no reverse geocoding. Pan, confirm, done --
// and the caller can always reopen this screen to update the pin later.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';

/// Naga City, Camarines Sur -- this app's only service area (same
/// scope every other address/barangay field in this codebase assumes).
const LatLng nagaCityCenter = LatLng(13.6218, 123.1948);

class MapPinPickerScreen extends StatefulWidget {
  const MapPinPickerScreen({super.key, this.initialLocation});

  /// When reopened to UPDATE an already-set pin, starts centered there
  /// instead of Naga City's generic center.
  final LatLng? initialLocation;

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  final _mapController = MapController();
  late LatLng _center = widget.initialLocation ?? nagaCityCenter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pin Your Location')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _center = position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nagaguno.mobile',
              ),
            ],
          ),
          // Fixed center pin -- the map pans underneath it, matching
          // Shopee's own "drag the map, the pin stays put" interaction.
          const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Icon(Icons.location_pin,
                size: 48, color: AppColors.accentDark),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: const Text('Confirm Location'),
            ),
          ),
        ],
      ),
    );
  }
}
