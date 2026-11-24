import 'package:mobo_helpdesk/features/account/domain/repositories/switch_account_repo.dart';

/// Use case for switching between user accounts.
///
/// Acts as an intermediary between the presentation layer and
/// [SwitchAccountRepo], handling account switching logic
/// and session updates.
class SwitchAccountUseCase {
  final SwitchAccountRepo switchAccountRepo;

  SwitchAccountUseCase(this.switchAccountRepo);

  Future<void> switchAccount(Map<String, dynamic> user) {
    return switchAccountRepo.switchAccount(user);
  }
}
