import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/account/presentation/bloc/account_bloc.dart';
import '../../features/main/presentation/bloc/main_layout_bloc.dart';
import '../../features/sla_policy/presentation/bloc/sla_policy_bloc.dart';
import '../../features/teams/presentation/bloc/team_bloc.dart';
import '../../features/tickets/presentation/bloc/ticket_bloc.dart';
import 'company_service.dart';

/// Utility class responsible for reloading all major BLoCs in the application.
///
/// This is typically used after significant state changes such as:
/// - Switching companies
/// - User logout and re-login
/// - Profile or settings updates that affect multiple features
///
/// It triggers a full refresh of the app's core data by dispatching the
/// initial load events to all registered BLoCs.
class AppBootstrapper {
  /// Reloads all primary BLoCs by dispatching their initial load events.
  ///
  /// This method uses `context.read<T>()` to access the BLoC instances
  /// provided at the root level via [MultiBlocProvider].
  ///
  /// Usually called from [CompanyRefreshBus] listener or after company switch.
  static void reloadAppBlocs(BuildContext context) {
    context.read<MainLayoutBloc>().add(LoadUser());
    context.read<DashboardBloc>().add(const DashboardLoad());
    // A reload here follows a switch of company, account or profile, so the
    // lists show their skeleton instead of the previous data.
    context.read<TicketBloc>().add(const TicketsLoad(1, showSkeleton: true));
    context.read<TicketBloc>().add(const LoadTicketCreateData());
    context.read<TeamBloc>().add(const TeamsLoad(1, showSkeleton: true));
    final companyId = context.read<CompanyProvider>().selectedCompanyId;
    context.read<TeamBloc>().add(LoadTeamCreateData(companyId: companyId));
    context.read<SlaPolicyBloc>().add(
      const SlaPolicyLoad(1, showSkeleton: true),
    );
    context.read<SlaPolicyBloc>().add(const LoadPolicyCreateData());
    context.read<AccountBloc>().add(ProfileDataLoad());
    context.read<AccountBloc>().add(LoadSettingsEvent());
  }
}