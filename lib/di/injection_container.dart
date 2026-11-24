import 'package:get_it/get_it.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobo_helpdesk/features/account/data/repositories/switch_account_repo_impl.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobo_helpdesk/features/tickets/data/repositories/ticket_form_repo_impl.dart';
import 'package:mobo_helpdesk/features/tickets/domain/repositories/ticket_form_repo.dart';
import 'package:mobo_helpdesk/features/tickets/domain/usecases/ticket_form_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/account/data/datasources/profile_remote_datasource.dart';
import '../features/account/data/datasources/setting_remote_datasource.dart';
import '../features/account/data/repositories/biometric_repo_impl.dart';
import '../features/account/data/repositories/profile_repo_impl.dart';
import '../features/account/data/repositories/setting_repo_impl.dart';
import '../features/account/domain/repositories/biometric_repo.dart';
import '../features/account/domain/repositories/profile_repo.dart';
import '../features/account/domain/repositories/setting_repo.dart';
import '../features/account/domain/repositories/switch_account_repo.dart';
import '../features/account/domain/usecases/biometric_usecase.dart';
import '../features/account/domain/usecases/profile_usecase.dart';
import '../features/account/domain/usecases/setting_usecase.dart';
import '../features/account/domain/usecases/switch_account_usecase.dart';
import '../features/account/presentation/bloc/account_bloc.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/check_login_usecase.dart';
import '../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../features/dashboard/data/repositories/dashboard_repo_impl.dart';
import '../features/dashboard/domain/repositories/dashboard_repo.dart';
import '../features/dashboard/domain/usecases/dashboard_usecase.dart';
import '../features/login/data/datasources/login_local_datasource.dart';
import '../features/login/data/datasources/login_remote_datasource.dart';
import '../features/login/data/datasources/reset_password_remote_datasource.dart';
import '../features/login/data/repositories/login_repo_impl.dart';
import '../features/login/domain/repositories/login_repo.dart';
import '../features/login/domain/usecases/fetch_database_usecase.dart';
import '../features/login/domain/usecases/load_url_history_usecase.dart';
import '../features/login/domain/usecases/login_usecase.dart';
import '../features/login/domain/usecases/reset_password_usecase.dart';
import '../features/login/domain/usecases/complete_totp_login_usecase.dart';
import '../features/login/presentation/bloc/login_bloc.dart';
import '../features/main/data/datasources/main_layout_remote_datasource.dart';
import '../features/main/data/repositories/main_layout_repo_impl.dart';
import '../features/main/domain/repositories/main_layout_repo.dart';
import '../features/main/domain/usecases/main_layout_usecase.dart';
import '../features/main/presentation/bloc/main_layout_bloc.dart';
import '../features/rating/data/repositories/review_repository_impl.dart';
import '../features/rating/domain/repositories/review_repository.dart';
import '../features/rating/domain/usecases/review_usecase.dart';
import '../features/sla_policy/data/datasources/sla_policy_form_remote_datasource.dart';
import '../features/sla_policy/data/datasources/sla_policy_list_remote_datasource.dart';
import '../features/sla_policy/data/repositories/sla_policy_form_repo_impl.dart';
import '../features/sla_policy/data/repositories/sla_policy_list_repo_impl.dart';
import '../features/sla_policy/domain/repositories/sla_policy_form_repo.dart';
import '../features/sla_policy/domain/repositories/sla_policy_list_repo.dart';
import '../features/sla_policy/domain/usecases/sla_policy_form_usecase.dart';
import '../features/sla_policy/domain/usecases/sla_policy_list_usecase.dart';
import '../features/sla_policy/presentation/bloc/sla_policy_bloc.dart';
import '../features/teams/data/datasources/team_form_remote_datasource.dart';
import '../features/teams/data/datasources/team_list_remote_datasource.dart';
import '../features/teams/data/repositories/team_form_repo_impl.dart';
import '../features/teams/data/repositories/team_list_repo_impl.dart';
import '../features/teams/domain/repositories/team_form_repo.dart';
import '../features/teams/domain/repositories/team_list_repo.dart';
import '../features/teams/domain/usecases/team_form_usecase.dart';
import '../features/teams/domain/usecases/team_list_usecase.dart';
import '../features/teams/presentation/bloc/team_bloc.dart';
import '../features/tickets/data/datasources/ticket_form_remote_datasource.dart';
import '../features/tickets/data/datasources/ticket_list_remote_datasource.dart';
import '../features/tickets/data/repositories/ticket_list_repo_impl.dart';
import '../features/tickets/domain/repositories/ticket_list_repo.dart';
import '../features/tickets/domain/usecases/ticket_list_usecase.dart';
import '../features/tickets/presentation/bloc/ticket_bloc.dart';

final sl = GetIt.instance;

/// Initializes the dependency injection container using GetIt.
///
/// This function registers all dependencies for the Mobo Helpdesk application
/// following the Clean Architecture pattern (Presentation → Domain → Data).
///
/// Registration order:
/// 1. **BLoCs** – All feature BLoCs are registered as factories.
/// 2. **External services** – SharedPreferences, InAppReview, LocalAuthentication.
/// 3. **UseCases** – All business logic use cases as lazy singletons.
/// 4. **Repositories** – Implementation of domain repositories.
/// 5. **Data Sources** – Remote and local data sources.
///
/// This setup enables easy testing, loose coupling, and maintainability across
/// the entire application.
///
/// **Note:** Some use cases and repositories related to in-app review
/// (`TrackAppOpen`, `RequestReview`, etc.) are registered but their
/// corresponding imports are missing in this file. Make sure they are properly
/// imported if used.
Future<void> init() async {
  /// BLOC
  sl.registerFactory(
    () => LoginBloc(
      fetchDatabasesUseCase: sl(),
      loadUrlHistoryUseCase: sl(),
      loginUseCase: sl(),
      resetPasswordUseCase: sl(),
      completeTotpLoginUseCase: sl(),
    ),
  );

  sl.registerFactory(() => MainLayoutBloc(sl()));
  sl.registerFactory(() => AccountBloc(sl(), sl(), sl(), sl()));

  sl.registerFactory(() => TicketBloc(sl(), sl(), sl()));
  sl.registerFactory(() => TeamBloc(sl(), sl(), sl()));
  sl.registerFactory(() => SlaPolicyBloc(sl(), sl(), sl()));

  sl.registerFactory(() => DashboardBloc(sl()));

  /// EXTERNAL
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  sl.registerLazySingleton<InAppReview>(() => InAppReview.instance);

  /// USECASES
  sl.registerLazySingleton(() => FetchDatabaseUseCase(sl()));
  sl.registerLazySingleton(() => LoadUrlHistoryUseCase(sl()));
  sl.registerLazySingleton(() => CheckLoginUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(sl()),
  );
  sl.registerLazySingleton<CompleteTotpLoginUseCase>(
    () => CompleteTotpLoginUseCase(sl()),
  );

  sl.registerLazySingleton<MainLayoutUseCase>(() => MainLayoutUseCase(sl()));
  sl.registerLazySingleton<ProfileUseCase>(() => ProfileUseCase(sl()));
  sl.registerLazySingleton<SwitchAccountUseCase>(
    () => SwitchAccountUseCase(sl()),
  );
  sl.registerLazySingleton<SettingUseCase>(() => SettingUseCase(sl()));
  sl.registerLazySingleton<BiometricUseCase>(() => BiometricUseCase(sl()));

  sl.registerLazySingleton<TicketListUseCase>(() => TicketListUseCase(sl()));
  sl.registerLazySingleton<TicketFormUseCase>(() => TicketFormUseCase(sl()));

  sl.registerLazySingleton<TeamListUseCase>(() => TeamListUseCase(sl()));
  sl.registerLazySingleton<TeamFormUseCase>(() => TeamFormUseCase(sl()));

  sl.registerLazySingleton<SlaPolicyListUseCase>(
    () => SlaPolicyListUseCase(sl()),
  );
  sl.registerLazySingleton<SlaPolicyFormUseCase>(
    () => SlaPolicyFormUseCase(sl()),
  );

  sl.registerLazySingleton<DashboardUseCase>(() => DashboardUseCase(sl()));

  sl.registerLazySingleton(() => TrackAppOpen(sl()));
  sl.registerLazySingleton(() => TrackEvent(sl()));
  sl.registerLazySingleton(() => ShouldShowReview(sl()));
  sl.registerLazySingleton(() => RequestReview(sl()));
  sl.registerLazySingleton(() => PostponeReview(sl()));
  sl.registerLazySingleton(() => NeverAskAgain(sl()));
  sl.registerLazySingleton(() => SendFeedback(sl()));

  /// LocalAuthentication
  sl.registerLazySingleton<LocalAuthentication>(() => LocalAuthentication());

  /// REPOSITORY
  sl.registerLazySingleton<LoginRepo>(() => LoginRepoImpl());
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());

  sl.registerLazySingleton<MainLayoutRepo>(() => MainLayoutRepoImpl(sl()));
  sl.registerLazySingleton<ProfileRepo>(() => ProfileRepoImpl(sl()));
  sl.registerLazySingleton<SwitchAccountRepo>(() => SwitchAccountRepoImpl());
  sl.registerLazySingleton<SettingRepo>(() => SettingRepoImpl(sl()));
  sl.registerLazySingleton<BiometricRepo>(
    () => BiometricRepoImpl(sl<LocalAuthentication>()),
  );

  sl.registerLazySingleton<TicketListRepo>(() => TicketListRepoImpl(sl()));
  sl.registerLazySingleton<TicketFormRepo>(() => TicketFormRepoImpl(sl()));

  sl.registerLazySingleton<TeamListRepo>(() => TeamListRepoImpl(sl()));
  sl.registerLazySingleton<TeamFormRepo>(() => TeamFormRepoImpl(sl()));

  sl.registerLazySingleton<SlaPolicyListRepo>(
    () => SlaPolicyListRepoImpl(sl()),
  );
  sl.registerLazySingleton<SlaPolicyFormRepo>(
    () => SlaPolicyFormRepoImpl(sl()),
  );

  sl.registerLazySingleton<DashboardRepo>(() => DashboardRepoImpl(sl()));

  sl.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(prefs: sl(), review: sl()),
  );

  /// Datasource
  sl.registerLazySingleton<LoginRemoteDatasource>(
    () => LoginRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<LoginLocalDatasource>(
    () => LoginLocalDatasourceImpl(),
  );
  sl.registerLazySingleton<ResetPasswordRemoteDataSource>(
    () => ResetPasswordRemoteDataSourceImpl(),
  );

  sl.registerLazySingleton<MainLayoutRemoteDatasource>(
    () => MainLayoutRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<ProfileRemoteDatasource>(
    () => ProfileRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<SettingRemoteDatasource>(
    () => SettingRemoteDatasourceImpl(),
  );

  sl.registerLazySingleton<TicketListRemoteDatasource>(
    () => TicketListRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<TicketFormRemoteDataSource>(
    () => TicketFormRemoteDataSourceImpl(),
  );

  sl.registerLazySingleton<TeamListRemoteDatasource>(
    () => TeamListRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<TeamFormRemoteDatasource>(
    () => TeamFormRemoteDatasourceImpl(),
  );

  sl.registerLazySingleton<SlaPolicyListRemoteDatasource>(
    () => SlaPolicyListRemoteDatasourceImpl(),
  );
  sl.registerLazySingleton<SlaPolicyFormRemoteDatasource>(
    () => SlaPolicyFormRemoteDatasourceImpl(),
  );

  sl.registerLazySingleton<DashboardRemoteDatasource>(
    () => DashboardRemoteDatasourceImpl(),
  );
}
