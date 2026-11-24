import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementation of [AuthRepository] that manages authentication state
/// using local persistent storage.
///
/// This repository is responsible for:
/// - Checking whether the user is currently logged in
/// - Reading authentication state from [SharedPreferences]
///
/// It acts as a simple local data source for authentication status
/// and does not handle network or server-side authentication logic.
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}
