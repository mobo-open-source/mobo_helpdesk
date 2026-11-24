import '../../../../core/odoo/repositories/module_check_repository.dart';
import '../../../../core/session/models/session_model.dart';
import '../repositories/login_repo.dart';

/// Use case responsible for handling user login and module validation.
///
/// This class coordinates authentication through [LoginRepo]
/// and checks module availability using [ModuleRepository].
class LoginUseCase {
  final LoginRepo loginRepo;
  final moduleRepo = ModuleRepository();

  LoginUseCase(this.loginRepo);

  /// Performs user login with the provided credentials.
  ///
  /// On success, returns a [SessionModel] containing session details.
  /// Returns `null` if authentication fails.
  ///
  /// If [isAddAccount] is false, existing accounts may be cleared
  /// before saving the new session.
  Future<SessionModel?> login({
    required String url,
    required String database,
    required String username,
    required String password,
    bool isAddAccount = false,
  }) async {
    return await loginRepo.login(
      url: url,
      database: database,
      username: username,
      password: password,
      isAddAccount: isAddAccount,
    );
  }

  /// Checks whether a specific module is installed.
  ///
  /// Requires the [moduleName] of the module to verify.
  /// Returns `true` if the module is installed, otherwise `false`.
  Future<bool> installCheck(String moduleName) async {
    return await moduleRepo.isModuleInstalled(moduleName);
  }
}
