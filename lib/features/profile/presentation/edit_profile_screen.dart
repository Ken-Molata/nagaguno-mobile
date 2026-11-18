// lib/features/profile/presentation/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/square_crop_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile_details.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));
final myProfileProvider = FutureProvider.autoDispose<ProfileDetails>(
    (ref) => ref.watch(profileRepositoryProvider).getMyProfile());

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _barangayController = TextEditingController();
  final _aboutController = TextEditingController();
  final _businessOrFarmNameController = TextEditingController();
  final _businessOrFarmAddressController = TextEditingController();
  bool _initialized = false;
  bool _submitting = false;
  String? _newPhotoPath;
  String? _existingPhotoUrl;
  bool _removePhoto = false;

  void _initFromProfile(ProfileDetails p) {
    if (_initialized) return;
    _fullNameController.text = p.fullName;
    _phoneController.text = p.phoneNumber ?? '';
    _barangayController.text = p.barangay ?? '';
    _aboutController.text = p.aboutMe ?? p.aboutFarm ?? p.aboutBusiness ?? '';
    _businessOrFarmNameController.text = p.farmName ?? p.businessName ?? '';
    _businessOrFarmAddressController.text =
        p.farmAddress ?? p.businessAddress ?? '';
    _existingPhotoUrl = p.avatarUrl ?? p.farmPhotoUrl ?? p.businessPhotoUrl;
    _initialized = true;
  }

  // UW 21.1: "Upload photo, Take photo, or Remove photo." Previously
  // this tapped straight into the gallery with no source choice and no
  // remove option at all.
  Future<void> _pickPhoto() async {
    final hasPhoto = _newPhotoPath != null ||
        (_existingPhotoUrl != null && !_removePhoto);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload photo'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      setState(() {
        _newPhotoPath = null;
        _removePhoto = true;
      });
      return;
    }

    final file = await pickAndCompressImage(
        source:
            choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
    if (file == null || !mounted) return;

    // UW 21.1: "the user crops to a square before saving."
    final cropped = await showSquareCropScreen(context, file.path);
    if (cropped == null) return;
    setState(() {
      _newPhotoPath = cropped;
      _removePhoto = false;
    });
  }

  Future<void> _save(String role) async {
    setState(() => _submitting = true);
    try {
      if (_newPhotoPath != null) {
        await ref.read(profileRepositoryProvider).uploadPhoto(_newPhotoPath!);
      } else if (_removePhoto) {
        await ref.read(profileRepositoryProvider).removePhoto();
      }
      await ref.read(profileRepositoryProvider).updateProfile(
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            barangay: _barangayController.text.trim().isEmpty
                ? null
                : _barangayController.text.trim(),
            aboutMe: role == 'buyer' ? _aboutController.text.trim() : null,
            farmName: role == 'farmer' &&
                    _businessOrFarmNameController.text.trim().isNotEmpty
                ? _businessOrFarmNameController.text.trim()
                : null,
            farmAddress: role == 'farmer' &&
                    _businessOrFarmAddressController.text.trim().isNotEmpty
                ? _businessOrFarmAddressController.text.trim()
                : null,
            aboutFarm:
                role == 'farmer' && _aboutController.text.trim().isNotEmpty
                    ? _aboutController.text.trim()
                    : null,
            businessName: role == 'vendor' &&
                    _businessOrFarmNameController.text.trim().isNotEmpty
                ? _businessOrFarmNameController.text.trim()
                : null,
            businessAddress: role == 'vendor' &&
                    _businessOrFarmAddressController.text.trim().isNotEmpty
                ? _businessOrFarmAddressController.text.trim()
                : null,
            aboutBusiness:
                role == 'vendor' && _aboutController.text.trim().isNotEmpty
                    ? _aboutController.text.trim()
                    : null,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t save your profile. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Couldn\'t load your profile.')),
        data: (profile) {
          _initFromProfile(profile);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(48),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.backgroundStart,
                        backgroundImage: _newPhotoPath != null
                            ? FileImage(File(_newPhotoPath!))
                            : (_existingPhotoUrl != null && !_removePhoto
                                ? NetworkImage(_existingPhotoUrl!)
                                    as ImageProvider
                                : null),
                        child: (_newPhotoPath == null &&
                                (_existingPhotoUrl == null || _removePhoto))
                            ? const Icon(Icons.camera_alt_outlined,
                                color: AppColors.primary, size: 28)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                      controller: _fullNameController,
                      decoration:
                          const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                      controller: _phoneController,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                      controller: _barangayController,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                      maxLength: 100), // matches users.barangay VARCHAR(100)
                  const SizedBox(height: AppSpacing.md),

                  if (profile.role == 'farmer') ...[
                    TextField(
                        controller: _businessOrFarmNameController,
                        decoration:
                            const InputDecoration(labelText: 'Farm Name')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                        controller: _businessOrFarmAddressController,
                        decoration:
                            const InputDecoration(labelText: 'Farm Address')),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (profile.role == 'vendor') ...[
                    TextField(
                        controller: _businessOrFarmNameController,
                        decoration:
                            const InputDecoration(labelText: 'Business Name')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                        controller: _businessOrFarmAddressController,
                        decoration: const InputDecoration(
                            labelText: 'Business Address')),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  TextField(
                    controller: _aboutController,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: profile.role == 'buyer'
                            ? 'About Me'
                            : profile.role == 'farmer'
                                ? 'About the Farm'
                                : 'About the Business'),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  ElevatedButton(
                    onPressed: _submitting ? null : () => _save(profile.role),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _barangayController.dispose();
    _aboutController.dispose();
    _businessOrFarmNameController.dispose();
    _businessOrFarmAddressController.dispose();
    super.dispose();
  }
}
