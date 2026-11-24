import '../../domain/entities/main_layout_entity.dart';
import '../../domain/repositories/main_layout_repo.dart';
import '../datasources/main_layout_remote_datasource.dart';

/// Concrete implementation of [MainLayoutRepo] responsible for handling
/// data operations related to the main layout feature.
///
/// This repository acts as an intermediary between the domain layer and
/// the data layer, delegating all data-fetching logic to
/// [MainLayoutRemoteDatasource].
///
/// Responsibilities:
/// - Fetch user profile data from the remote datasource
/// - Check user access permissions (e.g., group-based access control)
///
/// This implementation follows the Repository Pattern, ensuring that
/// the domain layer remains independent of data sources such as APIs,
/// databases, or shared preferences.
class MainLayoutRepoImpl implements MainLayoutRepo {
  final MainLayoutRemoteDatasource remoteDatasource;

  MainLayoutRepoImpl(this.remoteDatasource);

  /// Loads the current user profile information.
  ///
  /// Returns a list of [MainLayoutEntity] containing user details.
  /// The data is retrieved from the remote datasource.
  @override
  Future<List<MainLayoutEntity>> loadUser() async {
    return await remoteDatasource.loadUser();
  }

  /// Checks whether the current user has required access permissions.
  ///
  /// Typically verifies group membership or access rights from the server.
  ///
  /// Returns `true` if the user has access, otherwise `false`.
  @override
  Future<bool> checkAccess() async {
    return await remoteDatasource.checkAccess();
  }
}
