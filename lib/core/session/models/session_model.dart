/// Immutable model representing an authenticated Odoo session.
///
/// This model contains all essential information about the logged-in user,
/// their session, and company context. It is returned by [AuthService.authenticateOdoo]
/// and used throughout the app (especially in [CompanySessionManager] and [CompanyProvider]).
class SessionModel {
  final String? userName;
  final String? userLogin;
  final int? userId;
  final String sessionId;
  final String? serverVersion;
  final String? userLang;
  final int? partnerId;
  final String? userTimezone;
  final int? companyId;
  final String? companyName;
  final bool isSystem;
  final int? version;
  final List<int> allowedCompanyIds;

  /// Creates a new [SessionModel] instance.
  ///
  /// Only [sessionId] is required. All other fields are optional and can be
  /// populated based on the authentication flow (credential-based or session-based).
  SessionModel({
    required this.sessionId,
    this.userName,
    this.userLogin,
    this.userId,
    this.serverVersion,
    this.userLang,
    this.partnerId,
    this.userTimezone,
    this.companyId,
    this.companyName,
    this.isSystem = false,
    this.version,
    this.allowedCompanyIds = const [],
  });
}
