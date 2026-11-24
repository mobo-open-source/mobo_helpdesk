import '../entities/main_layout_entity.dart';
import '../repositories/main_layout_repo.dart';

/// Use case class for handling business logic related to the Main Layout feature.
///
/// This class acts as an intermediary between the presentation layer (BLoC/UI)
/// and the domain repository ([MainLayoutRepo]).
///
/// It encapsulates application-specific operations such as:
/// - Fetching user details
/// - Checking user access permissions
///
/// By using a use case layer, the business logic is kept separate from
/// UI and data layers, improving testability and maintainability.
class MainLayoutUseCase {
  final MainLayoutRepo mainLayoutRepo;

  MainLayoutUseCase(this.mainLayoutRepo);

  /// Retrieves the current user information.
  ///
  /// Returns a list of [MainLayoutEntity] containing user details.
  Future<List<MainLayoutEntity>> loadUser() {
    return mainLayoutRepo.loadUser();
  }

  /// Checks whether the user has required access permissions.
  ///
  /// Returns `true` if access is granted, otherwise `false`.
  Future<bool> checkAccess() {
    return mainLayoutRepo.checkAccess();
  }
}
