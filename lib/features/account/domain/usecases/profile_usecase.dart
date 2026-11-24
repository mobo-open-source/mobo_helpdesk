import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../entities/profile_entity.dart';
import '../repositories/profile_repo.dart';

/// Use case layer for profile-related operations.
///
/// Acts as an intermediary between presentation layer and [ProfileRepo],
/// and also handles image picking logic for profile updates.
///
/// Responsibilities:
/// - Fetch user profile data
/// - Load country and state information
/// - Update user address/profile details
/// - Pick and process profile images
class ProfileUseCase {
  final ProfileRepo profileRepo;

  final ImagePicker picker = ImagePicker();

  ProfileUseCase(this.profileRepo);

  Future<ProfileEntity> loadProfile() {
    return profileRepo.loadProfile();
  }

  Future<List<Map<String, dynamic>>> loadCountry() {
    return profileRepo.loadCountry();
  }

  Future<List<Map<String, dynamic>>> loadState(int countryId) {
    return profileRepo.loadState(countryId);
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String query) {
    return profileRepo.searchCompanies(query);
  }

  Future<Map<String, dynamic>> updateUserAddress(
    Map<String, dynamic> data,
    int id,
  ) {
    return profileRepo.updateUserDetails(data, id);
  }

  Future<Uint8List?> imagePick(ImageSource source) async {
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );

    if (file == null) return null;

    return await file.readAsBytes();
  }
}
