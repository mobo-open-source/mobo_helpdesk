part of 'login_bloc.dart';

/// Base class for all login-related events.
///
/// This abstract class is extended by all events used in [LoginBloc]
/// to manage authentication flow, including:
/// - Protocol and URL changes
/// - Database selection and fetching
/// - User credential submission
/// - Password visibility toggling
/// - URL history loading
/// - Password reset requests
/// - TOTP verification
abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when the protocol (http/https) is changed.
class ProtocolChanged extends LoginEvent {
  final String protocol;

  const ProtocolChanged(this.protocol);

  @override
  List<Object?> get props => [protocol];
}

/// Event triggered when the login URL is changed by the user.
class UrlChanged extends LoginEvent {
  final String url;

  const UrlChanged(this.url);

  @override
  List<Object?> get props => [url];
}

/// Event triggered when a database is selected by the user.
class DatabaseSelected extends LoginEvent {
  final String database;

  const DatabaseSelected(this.database);

  @override
  List<Object?> get props => [database];
}

/// Event triggered to fetch available databases from a server URL.
class FetchDatabases extends LoginEvent {
  final String fullUrl;

  const FetchDatabases(this.fullUrl);

  @override
  List<Object?> get props => [fullUrl];
}

/// Event triggered when user submits login credentials.
///
/// Contains all required authentication details along with optional
/// previous session data for account switching scenarios.
class CredentialSubmit extends LoginEvent {
  final String protocol;
  final String url;
  final String database;
  final String? previousDatabase;
  final String? previousUrl;
  final String username;
  final String password;
  final bool isAddAccount;
  final SessionModel? currentSession;

  const CredentialSubmit({
    required this.protocol,
    required this.url,
    required this.database,
    this.previousDatabase,
    this.previousUrl,
    required this.username,
    required this.password,
    this.isAddAccount = false,
    this.currentSession,
  });

  @override
  List<Object?> get props => [
    protocol,
    url,
    database,
    previousDatabase,
    previousUrl,
    username,
    password,
  ];
}

/// Event triggered to toggle password field visibility.
class TogglePasswordVisibility extends LoginEvent {}

/// Event triggered to clear any login error messages.
class ClearErrorMessage extends LoginEvent {
  final String selectedDatabase;

  const ClearErrorMessage(this.selectedDatabase);
}

/// Event triggered to load previously stored URL history.
///
/// Uses [protocol] to filter saved entries.
class LoadUrlHistory extends LoginEvent {
  final String protocol;

  const LoadUrlHistory(this.protocol);

  @override
  List<Object?> get props => [protocol];
}

/// Event triggered to request a password reset email.
///
/// Requires user [email], [url], and [database] information.
class RequestPasswordReset extends LoginEvent {
  final String email;
  final String url;
  final String database;

  const RequestPasswordReset({
    required this.email,
    required this.url,
    required this.database,
  });

  @override
  List<Object?> get props => [email, url, database];
}

/// Event triggered once the TOTP screen holds a session that the server
/// reported as authenticated for [username].
///
/// The code itself is submitted by the TOTP screen (over HTTP, or through its
/// WebView fallback); this event only finishes the login for the resulting
/// [sessionId] - the account, module and access checks, and saving the session.
class CompleteTotpLogin extends LoginEvent {
  final String sessionId;
  final String serverUrl;
  final String database;
  final String username;
  final String password;

  const CompleteTotpLogin({
    required this.sessionId,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [sessionId, serverUrl, database, username];
}

/// Event triggered when the user leaves the TOTP screen without verifying.
///
/// Clears the two-factor flags so the credential screen is back to a clean
/// state: the flow can be started again, and nothing is left in the state that
/// looks like a pending 2FA challenge.
class CancelTotp extends LoginEvent {
  const CancelTotp();
}
