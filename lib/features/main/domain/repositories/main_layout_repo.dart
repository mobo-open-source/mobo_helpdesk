import '../entities/main_layout_entity.dart';

/// Abstract repository interface for the Main Layout feature.
///
/// This defines the contract for data operations related to the main layout,
/// ensuring that the domain layer remains independent of concrete implementations
/// such as remote APIs, local storage, or third-party services.
///
/// Implementations of this repository are responsible for:
/// - Fetching user data
/// - Checking user access permissions
///
/// This abstraction follows the Repository Pattern in Clean Architecture,
/// promoting testability, scalability, and separation of concerns.
abstract class MainLayoutRepo {
  Future<List<MainLayoutEntity>> loadUser();

  Future<bool> checkAccess();
}
