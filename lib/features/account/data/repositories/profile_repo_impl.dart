import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repo.dart';
import '../datasources/profile_remote_datasource.dart';

/// Repository implementation for profile-related operations.
///
/// Acts as a bridge between the domain layer and the remote datasource.
/// Delegates all profile operations to [ProfileRemoteDatasource].
///
/// Responsibilities:
/// - Fetch user profile data
/// - Load country and state data
/// - Update user profile details
class ProfileRepoImpl implements ProfileRepo {
  final ProfileRemoteDatasource profileRemoteDatasource;

  ProfileRepoImpl(this.profileRemoteDatasource);

  /// Loads the current user's profile from the remote datasource.
  @override
  Future<ProfileEntity> loadProfile() async {
    return await profileRemoteDatasource.loadProfile();
  }

  /// Fetches list of available countries.
  @override
  Future<List<Map<String, dynamic>>> loadCountry() async {
    return await profileRemoteDatasource.loadCountry();
  }

  /// Fetches list of states for a given [countryId].
  @override
  Future<List<Map<String, dynamic>>> loadState(int countryId) async {
    return await profileRemoteDatasource.loadState(countryId);
  }

  @override
  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    return await profileRemoteDatasource.searchCompanies(query);
  }

  /// Updates user profile details on the server.
  ///
  /// [data] contains updated profile fields.
  /// [id] is the user identifier.
  @override
  Future<Map<String, dynamic>> updateUserDetails(
    Map<String, dynamic> data,
    int id,
  ) async {
    return await profileRemoteDatasource.updateUserDetails(data, id);
  }
}
