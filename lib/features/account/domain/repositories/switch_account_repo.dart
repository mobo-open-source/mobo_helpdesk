/// Repository contract for switching between user accounts.
///
/// Defines the operation required to change the active session
/// to another user account and persist the new session state.
abstract class SwitchAccountRepo {
  Future<void> switchAccount(Map<String, dynamic> user);
}
