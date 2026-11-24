import '../repositories/auth_repository.dart';

/// Use case responsible for checking whether the user is currently logged in.
///
/// This use case acts as a bridge between the presentation layer (BLoC/UI)
/// and the domain layer repository. It delegates the actual login state check
/// to the [AuthRepository].
///
/// Returns:
/// - `true` if the user is logged in
/// - `false` if the user is not logged in
class CheckLoginUseCase {
  final AuthRepository repository;

  CheckLoginUseCase(this.repository);

  /// Executes the use case to check login status.
  ///
  /// Returns a [Future] that completes with a boolean:
  /// - `true` if user is logged in
  /// - `false` otherwise
  Future<bool> call() async {
    return await repository.isLoggedIn();
  }
}
