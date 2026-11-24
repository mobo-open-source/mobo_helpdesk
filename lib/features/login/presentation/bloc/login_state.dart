part of 'login_bloc.dart';

/// Represents the complete state of the login feature.
///
/// This state holds all UI and business logic related to authentication,
/// including:
///
/// - Server connection details (protocol, URL)
/// - Database fetching and selection
/// - Login status and session information
/// - Error handling for URL and credentials
/// - URL history and suggestions
/// - Password visibility state
/// - Enterprise module validation
/// - Two-Factor Authentication (TOTP)
/// - Password reset flow (including WebView-based reset)
///
/// This state is immutable and updated using [copyWith].
class LoginState extends Equatable {
  final String protocol;
  final String url;

  final bool isLoading;
  final List<String> databases;
  final String? selectedDatabase;

  final String? urlError;
  final String? credentialError;

  final List<String> urlSuggestions;
  final Map<String, Map<String, String>> urlHistory;

  final bool isPasswordVisible;

  final bool isLoginSuccess;
  final SessionModel? session;

  final bool isModuleInstall;
  final bool requiresTotp;

  final bool isResetLoading;
  final String? resetSuccessMessage;
  final String? resetErrorMessage;
  final bool resetRequiresWebView;
  final String? resetWebViewUrl;

  final String? pendingUsername;
  final String? pendingPassword;
  final String? pendingServerUrl;
  final String? pendingDatabase;

  final bool isTotpVerifying;
  final String? totpError;

  const LoginState({
    this.protocol = 'https://',
    this.url = '',
    this.isLoading = false,
    this.databases = const [],
    this.selectedDatabase,
    this.urlError = "",
    this.credentialError = "",
    this.urlSuggestions = const [],
    this.urlHistory = const {},
    this.isPasswordVisible = false,
    this.isLoginSuccess = false,
    this.session,
    this.isModuleInstall = false,
    this.requiresTotp = false,

    this.isResetLoading = false,
    this.resetSuccessMessage,
    this.resetErrorMessage,
    this.resetRequiresWebView = false,
    this.resetWebViewUrl,

    this.pendingUsername,
    this.pendingPassword,
    this.pendingServerUrl,
    this.pendingDatabase,

    this.isTotpVerifying = false,
    this.totpError,
  });

  LoginState copyWith({
    String? protocol,
    String? url,
    bool? isLoading,
    List<String>? databases,
    String? selectedDatabase,
    String? urlError,
    String? credentialError,
    List<String>? urlSuggestions,
    Map<String, Map<String, String>>? urlHistory,
    bool? isPasswordVisible,
    bool? isLoginSuccess,
    SessionModel? session,
    bool? isModuleInstall,
    bool? requiresTotp,

    bool? isResetLoading,
    String? resetSuccessMessage,
    String? resetErrorMessage,
    bool? resetRequiresWebView,
    String? resetWebViewUrl,

    String? pendingUsername,
    String? pendingPassword,
    String? pendingServerUrl,
    String? pendingDatabase,
    bool? isTotpVerifying,
    String? totpError,
  }) {
    return LoginState(
      protocol: protocol ?? this.protocol,
      url: url ?? this.url,
      isLoading: isLoading ?? this.isLoading,
      databases: databases ?? this.databases,
      selectedDatabase: selectedDatabase,
      urlError: urlError ?? this.urlError,
      credentialError: credentialError ?? this.credentialError,
      urlSuggestions: urlSuggestions ?? this.urlSuggestions,
      urlHistory: urlHistory ?? this.urlHistory,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isLoginSuccess: isLoginSuccess ?? this.isLoginSuccess,
      session: session ?? this.session,
      isModuleInstall: isModuleInstall ?? this.isModuleInstall,
      requiresTotp: requiresTotp ?? this.requiresTotp,

      isResetLoading: isResetLoading ?? this.isResetLoading,
      resetSuccessMessage: resetSuccessMessage ?? this.resetSuccessMessage,
      resetErrorMessage: resetErrorMessage ?? this.resetErrorMessage,
      resetRequiresWebView: resetRequiresWebView ?? this.resetRequiresWebView,
      resetWebViewUrl: resetWebViewUrl ?? this.resetWebViewUrl,

      pendingUsername: pendingUsername ?? this.pendingUsername,
      pendingPassword: pendingPassword ?? this.pendingPassword,
      pendingServerUrl: pendingServerUrl ?? this.pendingServerUrl,
      pendingDatabase: pendingDatabase ?? this.pendingDatabase,

      isTotpVerifying: isTotpVerifying ?? this.isTotpVerifying,
      totpError: totpError,
    );
  }

  @override
  List<Object?> get props => [
    protocol,
    url,
    isLoading,
    databases,
    selectedDatabase,
    urlError,
    credentialError,
    urlSuggestions,
    urlHistory,
    isPasswordVisible,
    isLoginSuccess,
    session,
    isModuleInstall,

    isResetLoading,
    resetSuccessMessage,
    resetErrorMessage,
    resetRequiresWebView,
    resetWebViewUrl,
    isTotpVerifying,
  ];
}
