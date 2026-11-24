import '../entities/profile_entity.dart';

/// Repository contract for profile-related operations.
///
/// Defines all available actions related to user profile management,
/// including fetching profile data, loading location data,
/// and updating user details.
abstract class ProfileRepo {
  Future<ProfileEntity> loadProfile();

  Future<List<Map<String, dynamic>>> loadCountry();

  Future<List<Map<String, dynamic>>> loadState(int countryId);

  Future<List<Map<String, dynamic>>> searchCompanies(String query);

  Future<Map<String, dynamic>> updateUserDetails(
    Map<String, dynamic> data,
    int id,
  );
}
