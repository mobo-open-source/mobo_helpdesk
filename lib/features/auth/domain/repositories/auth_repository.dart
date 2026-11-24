/// Abstract contract for authentication-related operations.
///
/// This repository defines the interface for checking and managing
/// the user's authentication state.
///
/// Implementations of this repository are responsible for:
/// - Determining whether the user is currently logged in
/// - Providing a consistent authentication state across the app
/// - Abstracting the underlying data source (e.g., SharedPreferences,
///   secure storage, or remote authentication services)
///
/// This allows the domain layer to remain independent of the actual
/// authentication implementation.
abstract class AuthRepository {
  Future<bool> isLoggedIn();
}
