import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/session/company_session_manager.dart';
import '../../../../core/storage/password_security.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/profile_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/navigation/navigation_keys.dart';
import '../../../../core/widgets/restart_widget.dart';
import '../../../main/presentation/pages/main_layout_page.dart';
import '../../../login/presentation/pages/url_database_screen.dart';
import '../../../login/presentation/widgets/access_denied_dialog.dart';
import '../bloc/account_bloc.dart';

/// A widget that displays a list of previously logged-in user accounts
/// and allows switching between them.
///
/// This widget provides:
/// - A list of saved accounts excluding the current active account
/// - Quick account switching by tapping a row (SwitchAccountEvent)
/// - Removing a stored account from this device through its row menu
/// - Ability to add a new account using server/database credentials
///
/// It listens to AccountBloc state changes to handle:
/// - Loading state during account switching
/// - Success state to restart and navigate to the main layout
/// - Failure state to show error messages
///
/// The widget integrates with:
/// - Local storage (StorageService) for saved accounts
/// - PasswordSecurity to drop the credentials of a removed account
/// - CompanySessionManager for session handling
/// - RestartWidget for full app restart after switching accounts
///
/// UI adapts dynamically based on theme (light/dark mode).
class LoggedInAccounts extends StatefulWidget {
  final int userId;
  final String currentUrl;
  final String currentDatabase;

  const LoggedInAccounts({
    super.key,
    required this.userId,
    required this.currentUrl,
    required this.currentDatabase,
  });

  @override
  State<LoggedInAccounts> createState() => _LoggedInAccountsState();
}

class _LoggedInAccountsState extends State<LoggedInAccounts> {
  final StorageService _storageService = StorageService();

  /// Saved accounts held in the state rather than read inside `build`, so a
  /// rebuild does not start a fresh read on every frame and a removal can drop
  /// a row immediately.
  List<Map<String, dynamic>> _accounts = [];

  bool _isLoadingAccounts = true;

  /// Login of the account currently signed in, read from stored login state.
  ///
  /// Used to keep the active account out of the list even when its stored user
  /// id was saved in a different shape than the one passed in.
  String? _currentUserLogin;

  /// Identifies the account being switched to, so only that row shows progress
  /// and the other rows stay locked while the switch is in flight.
  String? _switchingAccountKey;
  bool _switchHandled = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _storageService.getAccounts();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _currentUserLogin = prefs.getString('userLogin');
      _isLoadingAccounts = false;
    });
  }

  /// Reads a stored account id that may have been persisted as an int or as a
  /// string, depending on which build wrote it.
  int? _accountUserId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Identity of a stored account, used to tell the rows apart.
  String _accountKey(Map<String, dynamic> account) =>
      '${account['url']}|${account['database']}|${account['userLogin']}';

  /// Label for a stored account.
  ///
  /// Falling back to the login keeps an account saved without a display name
  /// reachable, instead of hiding it from the list.
  String _accountDisplayName(Map<String, dynamic> account) {
    final storedName = (account['userName'] ?? '').toString();
    if (storedName.isNotEmpty) return storedName;
    final login = (account['userLogin'] ?? '').toString();
    return login.isNotEmpty ? login : 'Account';
  }

  /// Accounts other than the one currently signed in, without duplicates.
  List<Map<String, dynamic>> _otherAccounts(
    List<Map<String, dynamic>> accounts,
  ) {
    final seenAccounts = <String>{};

    return accounts.where((user) {
      final userUrl = (user['url'] ?? '').toString();
      final userDatabase = (user['database'] ?? '').toString();
      final userLogin = (user['userLogin'] ?? '').toString();

      // Without a server and database there is nothing to sign in to.
      if (userUrl.isEmpty || userDatabase.isEmpty) return false;

      final sameServer =
          userUrl == widget.currentUrl &&
          userDatabase == widget.currentDatabase;

      // Older entries were saved without a login, so fall back to the user id.
      final sameUser = userLogin.isNotEmpty
          ? userLogin.toLowerCase() == (_currentUserLogin ?? '').toLowerCase()
          : _accountUserId(user['userId']) != null &&
                _accountUserId(user['userId']) == widget.userId;

      if (sameServer && sameUser) return false;

      // Collapses duplicates left behind by builds that wrote the same account
      // twice.
      return seenAccounts.add(
        '$userUrl|$userDatabase|${userLogin.toLowerCase()}',
      );
    }).toList();
  }

  /// Asks before removing a saved account, then removes it.
  ///
  /// Only accounts other than the active one are listed, so this never deletes
  /// the session the user is currently signed in with.
  Future<void> _confirmRemoveAccount(Map<String, dynamic> account) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _accountDisplayName(account);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Remove $name from this device? You will need to sign in again to '
          'add it back.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    elevation: 0,
                    side: BorderSide(
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeAccount(account);
    }
  }

  /// Blocking loading dialog shown while an account switch or removal runs.
  ///
  /// Not dismissible, so taps and back presses can't interrupt the work; the
  /// caller closes it with a `Navigator.pop`.
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoadingAnimationWidget.fourRotatingDots(
                    color: AppColors.primary,
                    size: 50,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Drops a saved account from this device and refreshes the list.
  Future<void> _removeAccount(Map<String, dynamic> account) async {
    final url = (account['url'] ?? '').toString();
    final database = (account['database'] ?? '').toString();
    final userLogin = (account['userLogin'] ?? '').toString();
    final name = _accountDisplayName(account);

    _showLoadingDialog('Removing Account...');
    // Held so the dialog is only closed when it is still the top route.
    final navigator = Navigator.of(context, rootNavigator: false);

    try {
      await _storageService.removeAccountByIdentity(
        url: url,
        database: database,
        userLogin: userLogin,
      );
    } catch (_) {
      navigator.pop();
      if (!mounted) return;
      CustomSnackBar.showError(
        context,
        'Could not remove the account. Please try again.',
      );
      return;
    }

    // The saved password is keyed by the same url/database/login triple -
    // leaving it behind would keep credentials on the device for an account the
    // user just removed. Secure storage can fail on some devices, and the
    // account is already gone by now, so this must not be reported as a failed
    // removal or stop the list from refreshing.
    try {
      await PasswordSecurity().deletePassword(
        url: url,
        database: database,
        username: userLogin,
      );
    } catch (_) {}

    navigator.pop();
    if (!mounted) return;

    // Dropped from the list held in the state as well, so the row goes away
    // without waiting on another read of storage.
    setState(() {
      _accounts = _accounts
          .where((a) => _accountKey(a) != _accountKey(account))
          .toList();
    });
    CustomSnackBar.showSuccess(context, '$name removed from this device');
  }

  /// Starts the "add account" flow on the server configuration screen.
  Future<void> _openAddAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('url') ?? '';
    final database = prefs.getString('database') ?? '';
    final session = await CompanySessionManager.getCurrentSession();
    if (!mounted) return;
    RestartWidget.restartApp(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UrlDatabaseScreen(
          isAddAccount: true,
          title: "Add Account",
          subtitle: "Enter your server details to continue",
          initialUrl: url,
          initialDatabase: database,
          currentSession: session,
        ),
        settings: const RouteSettings(name: UrlDatabaseScreen.routeName),
      ),
    );
  }

  /// Completes a switch: settles the new account's company, then restarts once
  /// and opens the main screen.
  ///
  /// The company is resolved first, still behind the switching dialog, so the
  /// rebuilt app's lists load against the right company on their first request
  /// instead of loading empty and correcting themselves afterwards.
  Future<void> _finishSwitch(BuildContext context) async {
    try {
      await context.read<CompanyProvider>().initialize();
    } catch (_) {
      // The rebuilt provider retries; the switch itself has succeeded.
    }
    if (!context.mounted) return;
    RestartWidget.restartApp(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainLayout(skipReload: true)),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AccountBloc, AccountState>(
      // Only a change of switch status: every other emission (profile loads,
      // messages) keeps the same status, and re-running the success branch for
      // each would restart the whole app once per emission.
      listenWhen: (prev, curr) =>
          prev.configurationStatus != curr.configurationStatus,
      listener: (context, state) {
        // The settings load reuses this status; only a switch started from
        // this list may show the dialog or restart the app.
        if (_switchingAccountKey == null || _switchHandled) return;
        if (state.configurationStatus == ConfigurationStatus.loading) {
          _showLoadingDialog('Switching Account...');
        }
        if (state.configurationStatus == ConfigurationStatus.success) {
          // The restart rebuilds every bloc and provider, but the app's
          // Navigator (a GlobalKey) is carried over with its whole stack -
          // this page and the switching dialog included. So the stack is
          // replaced explicitly: one step to the main screen for the new
          // account, which also dismisses the dialog.
          // The rebuilt blocs briefly feed this (still mounted) list; nothing
          // they emit may start a second switch.
          _switchHandled = true;
          _finishSwitch(context);
        }
        if (state.configurationStatus == ConfigurationStatus.failure) {
          Navigator.of(context).pop();
          // The switch is over, so the rows become tappable again.
          setState(() => _switchingAccountKey = null);
          if (state.message != null &&
              state.message!.contains("Access Denied")) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => const AccessDeniedDialog(),
            );
          } else {
            CustomSnackBar.showError(
              context,
              "Something went wrong while switching, Please try again later.",
            );
          }
        }
      },
      builder: (context, state) {
        final otherAccounts = _otherAccounts(_accounts);

        return Column(
          children: [
            if (_isLoadingAccounts) ...[
              _buildAccountSkeleton(isDark),
              _buildAccountSkeleton(isDark),
            ] else if (otherAccounts.isEmpty)
              _buildEmptyState(isDark),
            ...otherAccounts.map((user) => _buildAccountTile(user, isDark)),
            const SizedBox(height: 10),
            _buildAddAccountButton(isDark),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  /// Stands in for an account row while the saved accounts load: a full card
  /// at the row's margin and height, with an avatar and two lines on it.
  Widget _buildAccountSkeleton(bool isDark) {
    return const SkeletonCard(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBar(widthFactor: 0.55, height: 16),
                SizedBox(height: 8),
                SkeletonBar(widthFactor: 0.4, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserAdd01,
              size: 30,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Other Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add multiple accounts to switch between them quickly',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(Map<String, dynamic> user, bool isDark) {
    Uint8List? avatar;
    if (user['image'] != null &&
        user['image'] is String &&
        (user['image'] as String).isNotEmpty) {
      try {
        avatar = base64Decode(user['image']);
      } catch (_) {
        avatar = null;
      }
    }

    final accountKey = _accountKey(user);
    final isSwitching = _switchingAccountKey == accountKey;
    final url = (user['url'] ?? '').toString();
    final database = (user['database'] ?? '').toString();
    final subtitle = url == widget.currentUrl ? database : '$database';

    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF434242) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),

          // Tapping anywhere on the row switches to that account; the trailing
          // menu holds the destructive action instead.
          onTap: _switchingAccountKey != null
              ? null
              : () {
                  setState(() => _switchingAccountKey = accountKey);
                  context.read<AccountBloc>().add(SwitchAccountEvent(user));
                },
          leading: ProfileImage(
            avatarBytes: avatar,
            isSvg: avatar != null ? isSvgBytes(avatar) : false,
            size: 40,
            backgroundColor: AppColors.primary,
          ),
          title: Text(
            _accountDisplayName(user),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
            ),
          ),
          trailing: isSwitching
              ? LoadingAnimationWidget.threeArchedCircle(
                  color: isDark ? Colors.white : AppColors.primary,
                  size: 20,
                )
              : PopupMenuButton<String>(
                  // Locked while a switch is in flight, so an account cannot be
                  // removed out from under the switch.
                  enabled: _switchingAccountKey == null,
                  tooltip: 'Account options',
                  position: PopupMenuPosition.over,
                  color: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') _confirmRemoveAccount(user);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAddAccountButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _switchingAccountKey != null ? null : _openAddAccount,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedUserAdd01,
            color: Colors.white,
          ),
          label: Text(
            "Add Account",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
