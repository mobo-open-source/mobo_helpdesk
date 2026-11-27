import '../../../../core/session/database_expiry.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/events/company_refresh_bus.dart';
import '../../../../core/events/profile_refresh_bus.dart';
import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/company_selector_widget.dart';
import '../../../../core/widgets/profile_image.dart';
import '../../../../core/widgets/snackbar.dart';
import '../../../../di/injection_container.dart';
import '../../../account/presentation/bloc/account_bloc.dart';
import '../../../account/presentation/pages/configuration_page.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../rating/domain/usecases/review_usecase.dart';
import '../../../sla_policy/presentation/bloc/sla_policy_bloc.dart';
import '../../../sla_policy/presentation/pages/sla_policy_list.dart';
import '../../../teams/presentation/bloc/team_bloc.dart';
import '../../../teams/presentation/pages/team_list.dart';
import '../../../tickets/presentation/bloc/ticket_bloc.dart';
import '../../../tickets/presentation/pages/ticket_main_view.dart';
import '../bloc/main_layout_bloc.dart';
import '../../../../core/security/biometric_lock.dart';

/// Main entry screen of the application after successful authentication.
///
/// This widget serves as the root layout of the app and manages:
/// - Bottom navigation between core modules (Dashboard, Tickets, Teams, SLA Policies)
/// - User profile and access-based UI rendering
/// - Company switching and session refresh handling
/// - App lifecycle initialization and bootstrap actions
///
/// It listens to [MainLayoutBloc] for user profile and access state,
/// and dynamically adjusts available pages based on permissions.
class MainLayout extends StatelessWidget {
  final bool? skipReload;

  const MainLayout({super.key, this.skipReload = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MainLayoutBloc>(),
      child: MainLayoutPage(skipReload),
    );
  }
}

/// Stateful implementation of the main application layout.
///
/// Responsibilities:
/// - Maintain bottom navigation state
/// - Load persisted session (URL, database)
/// - Listen to company switching events
/// - Trigger user profile loading
/// - Handle back navigation behavior
///
/// This widget coordinates multiple modules such as:
/// Dashboard, Tickets, Teams, SLA Policies, Account configuration.
class MainLayoutPage extends StatefulWidget {
  final bool? skipReload;

  const MainLayoutPage(this.skipReload, {super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  /// Tabs opened at least once. A tab's search text lives in its own screen
  /// while the results it searched live in the bloc above, so a tab torn down
  /// on every switch came back with an empty search bar over the previous
  /// search's results. Visited tabs are kept alive instead; tabs never opened
  /// are not built, so nothing loads before it is needed.
  final Set<int> _visitedTabs = {0};
  String? currentUrl;
  String? currentDatabase;
  late final StreamSubscription companySub;
  late final StreamSubscription profileSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DatabaseExpiry.enforceOnStoredSession();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _init();
    });
    if (!widget.skipReload!) {
      AppBootstrapper.reloadAppBlocs(context);
    }
    companySub = CompanyRefreshBus.stream.listen((_) async {
      if (!mounted) return;
      final provider = context.read<CompanyProvider>();
      await provider.initialize();
      if (!mounted) return;
      AppBootstrapper.reloadAppBlocs(context);
    });
    // A saved profile: redraw everything that shows the user's name or photo -
    // the app bar avatar and greeting through the user load, the tickets'
    // assignee names and avatars through their reload.
    profileSub = ProfileRefreshBus.stream.listen((_) {
      if (!mounted) return;
      AppBootstrapper.reloadAppBlocs(context);
    });
  }

  /// Away this long and a returning user must unlock again (when the
  /// biometric lock is on). Short enough to matter, long enough that a quick
  /// switch to another app or a permission dialog does not nag.
  static const Duration _relockAfter = Duration(minutes: 1);

  /// Away this long and the lists and dashboard are stale enough to reload.
  static const Duration _refreshAfter = Duration(minutes: 5);

  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _backgroundedAt;
  bool _authenticating = false;
  final ValueNotifier<bool> _locked = ValueNotifier(false);

  /// Plain cover shown while the app is not in the foreground, so the recent
  /// apps thumbnail does not expose tickets and customer data. Only used when
  /// the biometric lock is on.
  final ValueNotifier<bool> _hidden = ValueNotifier(false);

  bool get _biometricOn =>
      sl<SharedPreferences>().getBool('biometricEnabled') ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The biometric prompt itself pauses and resumes the app.
    if (_authenticating) return;

    if (_biometricOn &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused)) {
      _hidden.value = true;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      DatabaseExpiry.enforceOnStoredSession();
      if (since == null) {
        _hidden.value = false;
        return;
      }
      _onReturned(DateTime.now().difference(since));
    }
  }

  Future<void> _onReturned(Duration away) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    if (away >= _relockAfter && (prefs.getBool('biometricEnabled') ?? false)) {
      // Covered at once so nothing shows while the prompt is up.
      _locked.value = true;
      _hidden.value = false;
      await _unlock();
      if (!_locked.value) _refreshIfStale(away);
      return;
    }
    _hidden.value = false;
    _refreshIfStale(away);
  }

  /// Asks for the biometric again; on success the cover is lifted, otherwise
  /// it stays and offers a retry.
  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      // The phone can no longer provide a biometric: the prompt could never
      // succeed, so lift the cover and turn the lock off instead of trapping
      // the user behind it.
      if (!await BiometricLock.isUsable(_localAuth)) {
        await BiometricLock.disable();
        if (mounted) _locked.value = false;
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) _locked.value = false;
    } catch (e) {
      if (BiometricLock.isUnavailableError(e)) {
        await BiometricLock.disable();
        if (mounted) _locked.value = false;
      }
      // Otherwise stays locked; the cover has a retry button.
    } finally {
      _authenticating = false;
    }
  }

  /// Reloads what goes stale in the background. The create forms' lookups are
  /// left alone so a form someone is filling in is not reset.
  void _refreshIfStale(Duration away) {
    if (!mounted || away < _refreshAfter) return;
    context.read<MainLayoutBloc>().add(LoadUser());
    context.read<DashboardBloc>().add(const DashboardLoad());
    context.read<TicketBloc>().add(const TicketsLoad(1));
    context.read<TeamBloc>().add(const TeamsLoad(1));
    context.read<SlaPolicyBloc>().add(const SlaPolicyLoad(1));
  }

  Widget _lockCover(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Material(
        color: isDark ? Colors.black : Colors.white,
        child: Center(
          child: ElevatedButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Unlock'),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    companySub.cancel();
    profileSub.cancel();
    _locked.dispose();
    _hidden.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    sl<TrackAppOpen>()();
    // Each thing is loaded once. With a reload requested, initState's
    // reloadAppBlocs has already asked for the user; without one (cold start,
    // account switch) the root blocs and the company provider were just
    // created and loaded themselves, so only the user - which this page's own
    // bloc holds - is still to load.
    final loadedByRoot = widget.skipReload == true;
    if (loadedByRoot) {
      context.read<MainLayoutBloc>().add(LoadUser());
    }
    final provider = context.read<CompanyProvider>();
    if (!loadedByRoot) await provider.initialize();
    if (!mounted) return;
    await _loadStoredAccounts();
  }

  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUrl = prefs.getString('url') ?? "";
      currentDatabase = prefs.getString('database') ?? "";
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color getIconColor(int index) {
      return _currentIndex == index
          ? AppColors.primary
          : (isDark ? Colors.grey[400]! : Colors.grey.shade600);
    }

    final content = BlocBuilder<MainLayoutBloc, MainLayoutState>(
      builder: (context, state) {
        final List<Map<String, dynamic>> pages = state.isAccess
            ? <Map<String, dynamic>>[
                {'title': 'Dashboard', 'widget': DashboardPage()},
                {'title': 'Tickets', 'widget': TicketMainView()},
                {'title': 'Teams', 'widget': TeamList()},
                {'title': 'SLA Policies', 'widget': SlaPolicyList()},
              ]
            : <Map<String, dynamic>>[
                {'title': 'Dashboard', 'widget': DashboardPage()},
                {'title': 'Tickets', 'widget': TicketMainView()},
              ];
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (_currentIndex != 0) {
              setState(() {
                _currentIndex = 0;
              });
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            appBar: AppBarWidget(
              automaticallyImplyLeading: false,
              title: pages[_currentIndex]['title'],
              isDark: isDark,

              actions: [
                CompanySelectorWidget(
                  onCompanyChanged: () async {
                    if (!mounted) return;
                    final provider = context.read<CompanyProvider>();
                    final companyName =
                        provider.selectedCompany?['name']?.toString() ??
                        'company';
                    context.read<MainLayoutBloc>().add(LoadUser());
                    CompanyRefreshBus.notify();
                    CustomSnackBar.showSuccess(
                      context,
                      'Switched to $companyName',
                    );
                  },
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    if (currentUrl != null && currentDatabase != null) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider(
                            create: (context) => sl<AccountBloc>(),
                            child: ConfigurationPage(
                              userName: state.userName,
                              mail: state.mail,
                              profileImage: state.profileImage,
                              userId: state.userId,
                              currentUrl: currentUrl!,
                              currentDatabase: currentDatabase!,
                              isSvg: state.profileImage != null
                                  ? isSvgBytes(state.profileImage!)
                                  : false,
                            ),
                          ),
                          settings: const RouteSettings(
                            name: ConfigurationPage.routeName,
                          ),
                        ),
                      );
                    }
                  },
                  child: ProfileImage(
                    avatarBytes: state.profileImage,
                    isSvg: state.profileImage != null
                        ? isSvgBytes(state.profileImage!)
                        : false,
                    size: 40,
                    backgroundColor: AppColors.white,
                    isDashboard: true,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: [
                for (var i = 0; i < pages.length; i++)
                  _visitedTabs.contains(i)
                      ? pages[i]['widget'] as Widget
                      : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: PhysicalModel(
              color: isDark ? Colors.grey[900]! : Colors.white,
              borderRadius: BorderRadius.circular(20),
              shadowColor: Colors.black12,
              child: SnakeNavigationBar.color(
                elevation: 0,
                height: 60,
                behaviour: SnakeBarBehaviour.floating,
                snakeShape: SnakeShape.indicator,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                snakeViewColor: AppColors.primary,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: isDark
                    ? Colors.grey[400]
                    : Colors.grey.shade600,
                selectedLabelStyle: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontWeight: FontWeight.w500, fontSize: 12),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    _visitedTabs.add(index);
                  });
                },
                items: pages.map((page) {
                  int index = pages.indexOf(page);
                  IconData icon;
                  String title;
                  switch (index) {
                    case 0:
                      icon = HugeIcons.strokeRoundedDashboardSquare02;
                      title = "Dashboard";
                      break;
                    case 1:
                      icon = HugeIcons.strokeRoundedTask01;
                      title = "Tickets";
                      break;
                    case 2:
                      icon = HugeIcons.strokeRoundedUserMultiple;
                      title = "Teams";
                      break;
                    case 3:
                      icon = HugeIcons.strokeRoundedPolicy;
                      title = "SLA Policies";
                      break;
                    default:
                      icon = HugeIcons.strokeRoundedDashboardSquare02;
                      title = "Dashboard";
                  }
                  return BottomNavigationBarItem(
                    icon: HugeIcon(icon: icon, color: getIconColor(index)),
                    label: title,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_locked, _hidden]),
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(child: content),
          if (_hidden.value && !_locked.value)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          if (_locked.value) _lockCover(context),
        ],
      ),
    );
  }
}
