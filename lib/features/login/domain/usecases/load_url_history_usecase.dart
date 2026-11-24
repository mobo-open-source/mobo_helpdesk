import '../repositories/login_repo.dart';

/// Use case responsible for loading stored URL history.
///
/// This class retrieves previously saved URL history data
/// based on the given protocol (e.g., `http://`, `https://`)
/// from the [LoginRepo].
class LoadUrlHistoryUseCase {
  final LoginRepo loginRepo;

  LoadUrlHistoryUseCase(this.loginRepo);

  Future<Map<String, Map<String, String>>> call(String protocol) {
    return loginRepo.loadUrlHistoryForProtocol(protocol);
  }
}
