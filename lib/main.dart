import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'core/services/company_service.dart';
import 'core/services/theme_service.dart';
import 'core/widgets/restart_widget.dart';
import 'di/injection_container.dart' as di;
import 'features/account/presentation/bloc/account_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/main/presentation/bloc/main_layout_bloc.dart';
import 'features/sla_policy/presentation/bloc/sla_policy_bloc.dart';
import 'features/teams/presentation/bloc/team_bloc.dart';
import 'features/tickets/presentation/bloc/ticket_bloc.dart';

/// The entry point of the Flutter application.
///
/// This function performs the following initialization steps:
///
/// 1. Ensures that Flutter's widget binding is initialized.
/// 2. Initializes the dependency injection container using `di.init()`.
/// 3. Wraps the root widget with [RestartWidget] to allow full app restarts when needed.
/// 4. Provides multiple BLoC instances using [MultiBlocProvider]:
///    - [MainLayoutBloc] – Loads user data on startup.
///    - [DashboardBloc] – Loads dashboard data.
///    - [TicketBloc] – Loads tickets (page 1) and ticket creation data.
///    - [TeamBloc] – Loads teams (page 1) and team creation data.
///    - [SlaPolicyBloc] – Loads SLA policies (page 1) and policy creation data.
///    - [AccountBloc] – Loads profile data and user settings.
/// 5. Provides [ThemeServiceProvider] and [CompanyProvider] using [MultiProvider].
///
/// Note: Two separate [BlocProvider]s are created for [TicketBloc], [TeamBloc],
/// [SlaPolicyBloc], and [AccountBloc] because they handle different events/states.
/// In a production app, consider using a single instance per BLoC type with proper
/// event handling or using `BlocProvider.value` when appropriate.
///
/// See also:
/// - [MyApp] for the root widget of the application.
/// - [di.init] for dependency injection setup.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {};
  PlatformDispatcher.instance.onError = (error, stack) => true;
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      const SizedBox.shrink();

  await di.init();

  runApp(
    RestartWidget(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<MainLayoutBloc>(
            // Not loaded here: MainLayout builds its own MainLayoutBloc and loads
            // the user through that one.
            create: (_) => di.sl<MainLayoutBloc>(),
          ),
          BlocProvider<DashboardBloc>(
            create: (_) => di.sl<DashboardBloc>()..add(DashboardLoad()),
          ),
          BlocProvider<TicketBloc>(
            create: (_) => di.sl<TicketBloc>()
              ..add(TicketsLoad(1))
              ..add(LoadTicketCreateData()),
          ),
          BlocProvider<TeamBloc>(
            create: (_) => di.sl<TeamBloc>()
              ..add(TeamsLoad(1))
              ..add(const LoadTeamCreateData()),
          ),
          BlocProvider<SlaPolicyBloc>(
            create: (_) => di.sl<SlaPolicyBloc>()
              ..add(SlaPolicyLoad(1))
              ..add(LoadPolicyCreateData()),
          ),
          BlocProvider<AccountBloc>(
            create: (_) => di.sl<AccountBloc>()
              ..add(ProfileDataLoad())
              ..add(LoadSettingsEvent()),
          ),
        ],
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeServiceProvider()),
            ChangeNotifierProvider(
              create: (_) {
                final p = CompanyProvider();
                p.initialize();
                return p;
              },
            ),
          ],
          child: const MyApp(),
        ),
      ),
    ),
  );
}
