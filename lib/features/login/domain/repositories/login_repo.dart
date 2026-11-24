import '../../../../core/session/models/session_model.dart';
import '../entities/database_entity.dart';

/// Abstract repository that defines authentication-related operations.
///
/// This interface acts as a contract between the domain layer and
/// data layer, handling login, database retrieval, password reset,
/// URL history, and TOTP verification.
abstract class LoginRepo {
  /// Fetches the list of available databases from the given [url].
  ///
  /// Returns a list of [DatabaseEntity].
  Future<List<DatabaseEntity>> fetchDatabases(String url);

  /// Determines whether the given database is an Enterprise instance.
  ///
  /// Requires valid [url], [database], [username], and [password].
  /// Returns `true` if the database is Enterprise, otherwise `false`.
  Future<bool> isEnterpriseDatabase(
    String url,
    String database,
    String username,
    String password,
  );

  /// Loads previously stored URL history grouped by the given [protocol].
  ///
  /// Example protocols: `http://`, `https://`.
  /// Returns a nested map containing stored URLs and related details.
  Future<Map<String, Map<String, String>>> loadUrlHistoryForProtocol(
    String protocol,
  );

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
  });

  /// Sends a password reset request for the given user [email].
  ///
  /// Requires [serverUrl] and [database].
  /// Returns a response map containing status and message.
  Future<Map<String, dynamic>> requestPasswordReset({
    required String serverUrl,
    required String database,
    required String email,
  });

  /// Completes a TOTP (Two-Factor Authentication) login for [sessionId], a
  /// session the caller has already confirmed as authenticated.
  ///
  /// Validates Enterprise access, then saves the session and account details.
  ///
  /// Returns a map containing:
  /// - `success`: boolean indicating result
  /// - `message`: error message if the session could not be kept
  Future<Map<String, dynamic>> completeTotpLogin({
    required String sessionId,
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  });
}
