import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/session/models/session_model.dart';
import 'package:mobo_helpdesk/features/login/domain/entities/database_entity.dart';
import 'package:mobo_helpdesk/features/login/domain/usecases/fetch_database_usecase.dart';
import 'package:mobo_helpdesk/features/login/domain/usecases/load_url_history_usecase.dart';
import 'package:mobo_helpdesk/features/login/domain/usecases/login_usecase.dart';
import 'package:mobo_helpdesk/features/login/domain/usecases/reset_password_usecase.dart';
import 'package:mobo_helpdesk/features/login/domain/usecases/complete_totp_login_usecase.dart';
import 'package:mobo_helpdesk/features/login/presentation/bloc/login_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFetchDatabaseUseCase extends Mock implements FetchDatabaseUseCase {}

class MockLoadUrlHistoryUseCase extends Mock implements LoadUrlHistoryUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class MockCompleteTotpLoginUseCase extends Mock
    implements CompleteTotpLoginUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoginBloc bloc;
  late MockFetchDatabaseUseCase mockFetchDatabaseUseCase;
  late MockLoadUrlHistoryUseCase mockLoadUrlHistoryUseCase;
  late MockLoginUseCase mockLoginUseCase;
  late MockResetPasswordUseCase mockResetPasswordUseCase;
  late MockCompleteTotpLoginUseCase mockCompleteTotpLoginUseCase;

  setUp(() {
    mockFetchDatabaseUseCase = MockFetchDatabaseUseCase();
    mockLoadUrlHistoryUseCase = MockLoadUrlHistoryUseCase();
    mockLoginUseCase = MockLoginUseCase();
    mockResetPasswordUseCase = MockResetPasswordUseCase();
    mockCompleteTotpLoginUseCase = MockCompleteTotpLoginUseCase();
    bloc = LoginBloc(
      fetchDatabasesUseCase: mockFetchDatabaseUseCase,
      loadUrlHistoryUseCase: mockLoadUrlHistoryUseCase,
      loginUseCase: mockLoginUseCase,
      resetPasswordUseCase: mockResetPasswordUseCase,
      completeTotpLoginUseCase: mockCompleteTotpLoginUseCase,
    );
  });

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginBloc - Fetch Databases', () {
    blocTest<LoginBloc, LoginState>(
      'calls fetchDatabases and emits databases and selectedDatabase on success',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).thenAnswer(
          (_) async => [
            DatabaseEntity(name: 'db1'),
            DatabaseEntity(name: 'db2'),
            DatabaseEntity(name: 'db3'),
          ],
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const FetchDatabases('https://abc.com')),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.databases, 'databases', [])
            .having((s) => s.selectedDatabase, 'selectedDatabase', null),

        isA<LoginState>()
            .having((s) => s.databases, 'databases', ['db1', 'db2', 'db3'])
            .having((s) => s.selectedDatabase, 'selectedDatabase', null),

        isA<LoginState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).called(1);
      },
    );

    blocTest<LoginBloc, LoginState>(
      'emits error when database list is empty',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).thenAnswer((_) async => []);
        return bloc;
      },
      act: (bloc) => bloc.add(const FetchDatabases('https://abc.com')),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'isLoading', true),
        isA<LoginState>().having((s) => s.urlError, 'urlError', isNotEmpty),
        isA<LoginState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).called(1);
      },
    );

    blocTest<LoginBloc, LoginState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).thenThrow(Exception('database fetch failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(const FetchDatabases('https://abc.com')),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'isLoading', true),
        isA<LoginState>().having((s) => s.urlError, 'urlError', isNotEmpty),
        isA<LoginState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(
          () => mockFetchDatabaseUseCase.fetchDatabases('https://abc.com'),
        ).called(1);
      },
    );
  });

  group('LoginBloc - Submit Credentials', () {
    blocTest<LoginBloc, LoginState>(
      'successful credential submit emits success state',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.isEnterpriseDatabase(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockLoginUseCase.login(
            url: any(named: 'url'),
            database: any(named: 'database'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            isAddAccount: any(named: 'isAddAccount'),
          ),
        ).thenAnswer((_) async => SessionModel(sessionId: 'session123'));

        when(
          () => mockLoginUseCase.installCheck(any()),
        ).thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(
        const CredentialSubmit(
          url: 'abc.com',
          protocol: 'https://',
          database: 'db1',
          username: 'marc',
          password: 'marc',
          isAddAccount: false,
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'loading', true),
        isA<LoginState>().having((s) => s.isLoginSuccess, 'success', true),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits credentialError when database is not enterprise',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.isEnterpriseDatabase(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => false);
        return bloc;
      },
      act: (bloc) => bloc.add(
        const CredentialSubmit(
          url: 'abc.com',
          protocol: 'https://',
          database: 'db1',
          username: 'marc',
          password: 'marc',
          isAddAccount: false,
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.credentialError,
              'credentialError',
              "You are choosing a Community database.\n"
                  "Helpdesk module is only available in Odoo Enterprise Edition.\n"
                  "Please select an Enterprise database or contact your administrator.",
            ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits requiresTotp when error message is 2FA Required',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.isEnterpriseDatabase(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockLoginUseCase.login(
            url: any(named: 'url'),
            database: any(named: 'database'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            isAddAccount: any(named: 'isAddAccount'),
          ),
        ).thenThrow("2FA Required");

        return bloc;
      },
      act: (bloc) => bloc.add(
        const CredentialSubmit(
          url: 'abc.com',
          protocol: 'https://',
          database: 'db1',
          username: 'marc',
          password: 'marc',
          isAddAccount: false,
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.requiresTotp, 'requiresTotp', true),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits credentialError when credential submit fails',
      build: () {
        when(
          () => mockFetchDatabaseUseCase.isEnterpriseDatabase(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockLoginUseCase.login(
            url: any(named: 'url'),
            database: any(named: 'database'),
            username: any(named: 'username'),
            password: any(named: 'password'),
            isAddAccount: any(named: 'isAddAccount'),
          ),
        ).thenThrow(Exception('Login failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(
        const CredentialSubmit(
          url: 'abc.com',
          protocol: 'https://',
          database: 'db1',
          username: 'marc',
          password: 'marc',
          isAddAccount: false,
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.credentialError,
              'credentialError',
              'Network error occurred. Please check your internet connection or server URL',
            ),
      ],
    );
  });

  group('LoginBloc - Password Reset', () {
    blocTest<LoginBloc, LoginState>(
      'emits success message when reset password succeeds',
      build: () {
        when(
          () => mockResetPasswordUseCase.call(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            email: any(named: 'email'),
          ),
        ).thenAnswer(
          (_) async => {
            'success': true,
            'message': 'Reset email sent successfully',
          },
        );
        return bloc;
      },
      act: (bloc) => bloc.add(
        const RequestPasswordReset(
          url: 'https://abc.com',
          database: 'db1',
          email: 'test@mail.com',
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isResetLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', false)
            .having(
              (s) => s.resetSuccessMessage,
              'success message',
              'Reset email sent successfully',
            ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits webview state when reset requires webview',
      build: () {
        when(
          () => mockResetPasswordUseCase.call(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            email: any(named: 'email'),
          ),
        ).thenAnswer(
          (_) async => {
            'requiresWebView': true,
            'webViewUrl': 'https://reset.odoo.com',
            'message': 'Redirect required',
          },
        );
        return bloc;
      },
      act: (bloc) => bloc.add(
        const RequestPasswordReset(
          url: 'https://abc.com',
          database: 'db1',
          email: 'test@mail.com',
        ),
      ),
      expect: () => [
        isA<LoginState>().having((s) => s.isResetLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', false)
            .having((s) => s.resetRequiresWebView, 'webview', true)
            .having((s) => s.resetWebViewUrl, 'url', 'https://reset.odoo.com')
            .having((s) => s.resetErrorMessage, 'message', 'Redirect required'),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits resetErrorMessage when reset password fails',
      build: () {
        when(
              () => mockResetPasswordUseCase.call(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            email: any(named: 'email'),
          ),
        ).thenAnswer(
              (_) async => {
            'success': false,
            'message': 'Failed to send reset email.',
          },
        );

        return bloc;
      },
      act: (bloc) => bloc.add(
        const RequestPasswordReset(
          url: 'https://abc.com',
          database: 'db1',
          email: 'test@mail.com',
        ),
      ),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', false)
            .having(
              (s) => s.resetErrorMessage,
          'error',
          'Failed to send reset email.',
        ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits formatted error when reset throws exception',
      build: () {
        when(() => mockResetPasswordUseCase(
          serverUrl: any(named: 'serverUrl'),
          database: any(named: 'database'),
          email: any(named: 'email'),
        )).thenThrow(Exception('Network error'));

        return bloc;
      },
      act: (bloc) => bloc.add(
        const RequestPasswordReset(
          url: 'https://abc.com',
          database: 'db1',
          email: 'test@mail.com',
        ),
      ),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isResetLoading, 'loading', false)
            .having((s) => s.resetErrorMessage, 'error',
            isNotEmpty),
      ],
    );
  });

  group('LoginBloc - Complete OTP login', () {
    blocTest<LoginBloc, LoginState>(
      'emits login success when the TOTP session is kept',
      build: () {
        when(
              () => mockCompleteTotpLoginUseCase.call(
                sessionId: any(named: 'sessionId'),
                serverUrl: any(named: 'serverUrl'),
                database: any(named: 'database'),
                username: any(named: 'username'),
                password: any(named: 'password'),
          ),
        ).thenAnswer(
              (_) async => {'success': true},
        );
        when(() => mockLoginUseCase.installCheck(any()))
            .thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(
        CompleteTotpLogin(
          sessionId: 'session-1',
          serverUrl: 'https://abc.com',
          database: 'db1',
          username: 'test',
          password: 'test',
        ),
      ),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isTotpVerifying, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isTotpVerifying, 'loading', false)
            .having((s) => s.isLoginSuccess, 'success', true),
      ],
    );
    blocTest<LoginBloc, LoginState>(
      'emits login fail when the TOTP session is not kept',
      build: () {
        when(
              () => mockCompleteTotpLoginUseCase.call(
                sessionId: any(named: 'sessionId'),
                serverUrl: any(named: 'serverUrl'),
                database: any(named: 'database'),
                username: any(named: 'username'),
                password: any(named: 'password'),
          ),
        ).thenAnswer(
              (_) async => {'success': false},
        );

        return bloc;
      },
      act: (bloc) => bloc.add(
        CompleteTotpLogin(
          sessionId: 'session-1',
          serverUrl: 'https://abc.com',
          database: 'db1',
          username: 'test',
          password: 'test',
        ),
      ),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isTotpVerifying, 'loading', true),

        isA<LoginState>()
            .having((s) => s.isTotpVerifying, 'loading', false)
            .having((s) => s.isLoginSuccess, 'success', false),
      ],
    );
  });
}
