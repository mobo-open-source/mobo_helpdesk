import '../entities/database_entity.dart';
import '../repositories/login_repo.dart';

/// Use case responsible for fetching database-related information.
///
/// This class acts as an intermediary between the presentation layer
/// and the [LoginRepo], handling operations such as retrieving the
/// list of databases and checking whether a database is an
/// Enterprise instance.
class FetchDatabaseUseCase {
  final LoginRepo loginRepo;

  FetchDatabaseUseCase(this.loginRepo);

  /// Fetches the list of available databases from the given [url].
  ///
  /// Returns a list of [DatabaseEntity].
  Future<List<DatabaseEntity>> fetchDatabases(String url) {
    return loginRepo.fetchDatabases(url);
  }

  /// Checks whether the given database is an Enterprise database.
  ///
  /// Requires valid [url], [database], [username], and [password].
  /// Returns `true` if the database is Enterprise, otherwise `false`.
  Future<bool> isEnterpriseDatabase(
    String url,
    String database,
    String username,
    String password,
  ) {
    return loginRepo.isEnterpriseDatabase(url, database, username, password);
  }
}
