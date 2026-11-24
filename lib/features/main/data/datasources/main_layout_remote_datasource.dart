import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/odoo_binary.dart';
import '../../domain/entities/main_layout_entity.dart';
import '../models/main_layout_model.dart';

/// Remote datasource responsible for fetching user-related data
/// and validating access permissions for the main layout module.
///
/// This class interacts with:
/// - Odoo backend via [CompanySessionManager]
/// - Local storage via [SharedPreferences]
///
/// Responsibilities:
/// - Load user profile information from server
/// - Persist user details locally (id, name, email, image)
/// - Check whether the user has required access permissions
abstract class MainLayoutRemoteDatasource {
  /// Fetches the current user profile from the remote server.
  ///
  /// Returns a list of [MainLayoutEntity] representing user data.
  Future<List<MainLayoutEntity>> loadUser();

  /// Checks whether the current user has system access permission.
  ///
  /// Returns `true` if the user has the required access group,
  /// otherwise returns `false`.
  Future<bool> checkAccess();
}

class MainLayoutRemoteDatasourceImpl implements MainLayoutRemoteDatasource {
  @override
  Future<List<MainLayoutEntity>> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;
      final details = ['id', 'name', 'email', 'image_1920'];
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
        ],
        'kwargs': {'fields': details},
      });

      final profileItems = response is List ? response : [];
      if (profileItems.isNotEmpty) {
        final user = profileItems.first;

        await prefs.setInt('userId', user['id'] ?? 0);
        await prefs.setString('userName', user['name'] ?? '');
        await prefs.setString('userEmail', user['email'] ?? '');
        await prefs.setString(
          'userImage',
          odooBinaryToBase64(user['image_1920']),
        );
      }
      return profileItems
          .map((item) => MainLayoutModel.fromJson(item))
          .toList();
    } catch (e) {
      throw 'Error fetching database list';
    }
  }

  /// Extracts the major version number from a server version string.
  ///
  /// Example:
  /// - "18.0+e" → 18
  /// - "17.2" → 17
  int parseMajorVersion(String serverVersion) {
    // ignore: deprecated_member_use
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  @override
  Future<bool> checkAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isSystem = prefs.getBool('isSystem') ?? false;

    prefs.setBool('isAccess', isSystem);

    return isSystem;
  }
}
