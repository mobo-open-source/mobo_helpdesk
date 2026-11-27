import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/core/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../../../core/session/company_session_manager.dart';
import '../../../../core/session/database_expiry.dart';
import '../../../../core/session/models/session_model.dart';
import '../../../../core/usecases/reset_session_usecase.dart';
import '../../domain/usecases/fetch_database_usecase.dart';
import '../../domain/entities/database_entity.dart';
import '../../domain/usecases/load_url_history_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/complete_totp_login_usecase.dart';
import '../utils/login_error_formatter.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/storage/session_token_store.dart';
import '../../../../core/security/certificate_trust_prompt.dart';
import '../../../../core/security/transport_policy.dart';

part 'login_event.dart';

part 'login_state.dart';

/// Bloc responsible for managing the login flow of the application.
///
/// This Bloc handles all authentication-related operations including:
/// - Fetching available databases from a server
/// - Managing URL input and history
/// - Performing user login with credential validation
/// - Checking Enterprise module availability
/// - Handling password reset flows (including WebView-based reset)
/// - Processing Two-Factor Authentication (TOTP)
///
/// It coordinates multiple use cases and services such as:
/// - [FetchDatabaseUseCase]
/// - [LoadUrlHistoryUseCase]
/// - [LoginUseCase]
/// - [ResetPasswordUseCase]
/// - [CompleteTotpLoginUseCase]
///
/// State transitions are emitted based on user interactions and
/// asynchronous authentication results.
///
/// This Bloc also manages:
/// - Debounced URL validation and database fetching
/// - Session persistence via [CompanySessionManager]
/// - Local storage updates via [StorageService]
/// - Connectivity and session switching logic
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final FetchDatabaseUseCase fetchDatabasesUseCase;
  final LoadUrlHistoryUseCase loadUrlHistoryUseCase;
  final LoginUseCase loginUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final CompleteTotpLoginUseCase completeTotpLoginUseCase;

  /// Decides whether the server's certificate may be used (asking the user to
  /// approve a self-signed one). Injectable so tests need no network or UI.
  final Future<bool> Function(String fullUrl) serverTrustCheck;

  Timer? _debounce;

  LoginBloc({
    required this.fetchDatabasesUseCase,
    required this.loadUrlHistoryUseCase,
    required this.loginUseCase,
    required this.resetPasswordUseCase,
    required this.completeTotpLoginUseCase,
    this.serverTrustCheck = ensureServerTrusted,
  }) : super(const LoginState()) {
    on<ProtocolChanged>(_onProtocolChanged);
    on<UrlChanged>(_onUrlChanged);
    on<LoadUrlHistory>(_onLoadUrlHistory);
    on<DatabaseSelected>(_onDatabaseSelected);
    on<FetchDatabases>(_onFetchDatabases);
    on<TogglePasswordVisibility>(_onPasswordVisibility);
    on<ClearErrorMessage>(_onClearErrorMessage);
    on<CredentialSubmit>(_onCredentialSubmit);
    on<RequestPasswordReset>(_onRequestPasswordReset);
    on<CompleteTotpLogin>(_onCompleteTotpLogin);
    on<CancelTotp>(_onCancelTotp);
  }

  Future<void> _onProtocolChanged(
    ProtocolChanged event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      state.copyWith(
        // http:// is accepted in debug builds only (see transport_policy.dart).
        protocol: allowInsecureHttp ? event.protocol : 'https://',
        databases: [],
        selectedDatabase: null,
        urlError: "",
      ),
    );

    if (state.url.isNotEmpty) {
      add(FetchDatabases('${event.protocol}${state.url.trim()}'));
    }
  }

  static String extractDomain(String fullUrl) {
    if (fullUrl.startsWith('https://')) return fullUrl.substring(8);
    if (fullUrl.startsWith('http://')) return fullUrl.substring(7);
    return fullUrl;
  }

  static String extractProtocol(String fullUrl) {
    if (fullUrl.startsWith('https://')) return 'https://';
    if (fullUrl.startsWith('http://')) return 'http://';
    return '';
  }

  void _onUrlChanged(UrlChanged event, Emitter<LoginState> emit) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    String raw = event.url.trim();
    String detectedProtocol = state.protocol;

    if (raw.startsWith('https://')) {
      detectedProtocol = 'https://';
    } else if (raw.startsWith('http://')) {
      detectedProtocol = 'http://';
    }

    final String domain = extractDomain(raw);

    // Credentials and session cookies must never travel over plain HTTP.
    if (!allowInsecureHttp && raw.toLowerCase().startsWith('http://')) {
      emit(
        state.copyWith(
          protocol: 'https://',
          url: domain,
          databases: [],
          selectedDatabase: null,
          urlError: 'Only secure servers (https://) are supported.',
          isLoading: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        protocol: detectedProtocol,
        url: domain,
        databases: [],
        selectedDatabase: null,
        urlError: "",
        isLoading: domain.isNotEmpty,
      ),
    );

    if (domain.isEmpty) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () {
      add(FetchDatabases('$detectedProtocol$domain'));
    });
  }

  Future<void> _onLoadUrlHistory(
    LoadUrlHistory event,
    Emitter<LoginState> emit,
  ) async {
    final history = await loadUrlHistoryUseCase.call(event.protocol);

    emit(
      state.copyWith(
        urlHistory: history,
        urlSuggestions: history.keys.toList(),
      ),
    );
  }

  void _onDatabaseSelected(
    DatabaseSelected event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(selectedDatabase: event.database, urlError: ""));
  }

  Future<void> _onFetchDatabases(
    FetchDatabases event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        urlError: "",
        databases: [],
        selectedDatabase: null,
      ),
    );

    try {
      // Self-signed / private-CA servers need the user's explicit approval of
      // their exact certificate before any credentials are sent.
      if (!await serverTrustCheck(event.fullUrl)) {
        emit(
          state.copyWith(
            urlError: 'The server certificate was not trusted.',
            isLoading: false,
          ),
        );
        return;
      }

      final List<DatabaseEntity> result = await fetchDatabasesUseCase
          .fetchDatabases(event.fullUrl);

      if (result.isNotEmpty) {
        final dbNames = result.map((e) => e.name).toList();

        String? selectedDb;

        if (state.selectedDatabase != null &&
            dbNames.contains(state.selectedDatabase)) {
          selectedDb = state.selectedDatabase;
        } else if (result.length == 1) {
          selectedDb = result.first.name;
        }

        emit(state.copyWith(databases: dbNames, selectedDatabase: selectedDb));
      } else {
        emit(
          state.copyWith(
            urlError: LoginErrorFormatter.formatUrlError(
              "db list failed",
              event.fullUrl,
            ),
          ),
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          urlError: LoginErrorFormatter.formatUrlError(error, event.fullUrl),
        ),
      );
    }

    emit(state.copyWith(isLoading: false));
  }

  void _onPasswordVisibility(
    TogglePasswordVisibility event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  void _onClearErrorMessage(ClearErrorMessage event, Emitter<LoginState> emit) {
    emit(
      state.copyWith(
        credentialError: '',
        selectedDatabase: event.selectedDatabase,
      ),
    );
  }

  Future<void> _onCredentialSubmit(
    CredentialSubmit event,
    Emitter<LoginState> emit,
  ) async {
    // Every flag a previous attempt may have left behind is cleared here, so the
    // screens react to this attempt only: a stale `requiresTotp` would stop the
    // 2FA screen from being opened again, and a stale `isLoginSuccess` would
    // navigate away from a login that has not happened yet.
    emit(
      state.copyWith(
        isLoading: true,
        credentialError: null,
        requiresTotp: false,
        isLoginSuccess: false,
        totpError: null,
        isTotpVerifying: false,
      ),
    );
    try {
      final cleanUrl = event.url
          .replaceFirst('http://', '')
          .replaceFirst('https://', '')
          .trim();
      final fullUrl = event.protocol + cleanUrl;

      final isEnterprise = await fetchDatabasesUseCase.isEnterpriseDatabase(
        fullUrl,
        event.database,
        event.username.trim(),
        event.password.trim(),
      );
      if (isEnterprise) {
        final session = await loginUseCase.login(
          url: fullUrl,
          database: event.database,
          username: event.username.trim(),
          password: event.password.trim(),
          isAddAccount: event.isAddAccount,
        );

        if (session == null) {
          emit(
            state.copyWith(
              isLoading: false,
              credentialError: "Authentication failed",
            ),
          );
          return;
        }

        bool? isInstall = await loginUseCase.installCheck('helpdesk');
        final prefs = await SharedPreferences.getInstance();

        if (event.isAddAccount) {
          if (isInstall == false) {
            await prefs.remove('lastUsername');
            await StorageService().removeAccount(
              userLogin: session.userLogin ?? '',
              userName: session.userName ?? '',
              userId: session.userId ?? 0,
              url: event.protocol + event.url,
              database: event.database,
            );

            final prev = event.currentSession;
            if (prev != null) {
              // Restoring the previous account: a value it never had is left
              // out instead of aborting the restore half way.
              Future<void> restoreString(String key, String? value) async {
                if (value != null) await prefs.setString(key, value);
              }

              Future<void> restoreInt(String key, int? value) async {
                if (value != null) await prefs.setInt(key, value);
              }

              await restoreString('url', event.previousUrl);
              await restoreString('database', event.previousDatabase);
              await SessionTokenStore.setActive(prev.sessionId);
              await restoreString('userName', prev.userName);
              await restoreString('userLogin', prev.userLogin);
              await restoreInt('userId', prev.userId);
              await restoreString('serverVersion', prev.serverVersion);
              await restoreString('userLang', prev.userLang);
              await restoreInt('partnerId', prev.partnerId);
              await restoreString('userTimezone', prev.userTimezone);
              await restoreInt('companyId', prev.companyId);
              await restoreString('company_name', prev.companyName);
              await prefs.setBool('isSystem', prev.isSystem);
              await restoreInt('version', prev.version);
              await prefs.setStringList(
                'allowed_company_ids',
                prev.allowedCompanyIds.map((e) => e.toString()).toList(),
              );

              await CompanySessionManager.clearSessionCache();
              OdooFieldResolver.clearCache();
              await CompanySessionManager.forceRefreshFromPrefs();

              final previousUrl = event.previousUrl;
              if (previousUrl != null) {
                ConnectivityService.instance.setCurrentServerUrl(previousUrl);
              }
            }
          }
        } else {
          if (isInstall == false) {
            await ResetSessionUseCase().execute();
          }
        }

        emit(
          state.copyWith(
            isLoading: false,
            isLoginSuccess: true,
            isModuleInstall: isInstall,
            session: session,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            credentialError:
                "You are choosing a Community database.\n"
                "Helpdesk module is only available in Odoo Enterprise Edition.\n"
                "Please select an Enterprise database or contact your administrator.",
          ),
        );
      }
    } catch (error) {
      if (error.toString().contains("Module Missing")) {
        emit(
          state.copyWith(isLoading: false, credentialError: "Module Missing"),
        );
        return;
      }
      if (error is DatabaseExpiredException) {
        emit(
          state.copyWith(
            isLoading: false,
            credentialError: DatabaseExpiredException.message,
          ),
        );
        return;
      }
      if (error.toString().contains("Portal Access")) {
        emit(
          state.copyWith(isLoading: false, credentialError: "Portal Access"),
        );
        return;
      }
      if (error.toString().contains("Access Denied")) {
        emit(
          state.copyWith(isLoading: false, credentialError: "Access Denied"),
        );
        return;
      }
      final message = LoginErrorFormatter.formatError(error);
      if (message == '2FA Required') {
        emit(state.copyWith(isLoading: false, requiresTotp: true));
        return;
      }
      emit(state.copyWith(isLoading: false, credentialError: message));
    }
  }

  Future<void> _onRequestPasswordReset(
    RequestPasswordReset event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      state.copyWith(
        isResetLoading: true,
        resetErrorMessage: null,
        resetSuccessMessage: null,
        resetRequiresWebView: false,
        resetWebViewUrl: null,
      ),
    );

    try {
      final fullServerUrl = event.url.trim();
      final database = event.database;

      final result = await resetPasswordUseCase(
        serverUrl: fullServerUrl,
        database: database,
        email: event.email.trim(),
      );

      if (result['success'] == true) {
        emit(
          state.copyWith(
            isResetLoading: false,
            resetSuccessMessage:
                result['message'] as String? ??
                'Reset link sent to your email.',
          ),
        );
      } else if (result['requiresWebView'] == true) {
        emit(
          state.copyWith(
            isResetLoading: false,
            resetRequiresWebView: true,
            resetWebViewUrl: result['webViewUrl'] as String?,
            resetErrorMessage: result['message'] as String?,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isResetLoading: false,
            resetErrorMessage:
                result['message'] as String? ?? 'Failed to send reset email.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isResetLoading: false,
          resetErrorMessage: LoginErrorFormatter.formatError(e),
        ),
      );
    }
  }

  Future<void> _onCompleteTotpLogin(
    CompleteTotpLogin event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(isTotpVerifying: true, totpError: null));

    try {
      final success = await completeTotpLoginUseCase(
        sessionId: event.sessionId,
        serverUrl: event.serverUrl,
        database: event.database,
        username: event.username,
        password: event.password,
      );

      final bool isSuccess = success['success'] ?? false;

      if (isSuccess) {
        final session = await CompanySessionManager.getCurrentSession();
        bool? isInstall = await loginUseCase.installCheck('helpdesk');
        if (isInstall == false) {
          await ResetSessionUseCase().execute();
        }
        emit(
          state.copyWith(
            isTotpVerifying: false,
            isLoginSuccess: true,
            isModuleInstall: isInstall,
            session: session,
          ),
        );
      } else {
        final errorMsg = success['message'] ?? "TOTP verification failed";
        if (errorMsg.toString().contains("Portal Access")) {
          emit(
            state.copyWith(isTotpVerifying: false, totpError: "Portal Access"),
          );
        } else if (errorMsg.toString().contains("Access Denied")) {
          emit(
            state.copyWith(isTotpVerifying: false, totpError: "Access Denied"),
          );
        } else {
          emit(state.copyWith(isTotpVerifying: false, totpError: errorMsg));
        }
      }
    } catch (error) {
      if (error.toString().contains("Module Missing")) {
        emit(
          state.copyWith(isTotpVerifying: false, totpError: "Module Missing"),
        );
      } else if (error.toString().contains("Portal Access")) {
        emit(
          state.copyWith(isTotpVerifying: false, totpError: "Portal Access"),
        );
      } else if (error.toString().contains("Access Denied")) {
        emit(
          state.copyWith(isTotpVerifying: false, totpError: "Access Denied"),
        );
      } else {
        emit(
          state.copyWith(
            isTotpVerifying: false,
            totpError: LoginErrorFormatter.formatError(error),
          ),
        );
      }
    }
  }

  /// Clears the two-factor flags when the user backs out of the TOTP screen.
  void _onCancelTotp(CancelTotp event, Emitter<LoginState> emit) {
    emit(
      state.copyWith(
        requiresTotp: false,
        isTotpVerifying: false,
        totpError: null,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
