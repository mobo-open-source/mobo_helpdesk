import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../di/injection_container.dart';
import '../bloc/account_bloc.dart';
import '../pages/settings.dart';
import 'logged_in_accounts.dart';
import 'logout_dialog.dart';

/// A configuration panel widget that provides quick access to
/// app-level account and system actions.
///
/// This widget includes:
/// - Navigation to the Settings screen (app preferences, security, etc.)
/// - Expansion panel for switching between logged-in accounts
/// - Logout action with confirmation dialog
///
/// It is typically used inside the ConfigurationPage as a section
/// for managing user-level configuration and session control.
///
/// The widget adapts its UI based on the current theme (light/dark)
/// and uses smooth page transitions for navigation.
class ConfigurationItems extends StatelessWidget {
  final String userName;
  final int userId;
  final String currentUrl;
  final String currentDatabase;

  const ConfigurationItems({
    super.key,
    required this.userName,
    required this.userId,
    required this.currentUrl,
    required this.currentDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings02,
              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'App preferences and sync options',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider<AccountBloc>(
                    create: (context) => sl<AccountBloc>(),
                    child: Settings(),
                  ),
                ),
              );
            },
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            indent: 20,
            endIndent: 20,
          ),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: isDark ? Colors.white : Colors.black87,
              collapsedIconColor: isDark
                  ? Colors.grey[400]!
                  : Colors.grey[600]!,
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedUserSwitch,
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
              title: Text(
                'Switch Accounts',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Manage and switch between accounts",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
              children: [
                LoggedInAccounts(
                  userId: userId,
                  currentUrl: currentUrl,
                  currentDatabase: currentDatabase,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey.shade200,
            indent: 20,
            endIndent: 20,
          ),

          ListTile(
            minVerticalPadding: 20,
            leading: const Icon(Icons.logout, color: Color(0xFFD32F2F)),
            title: Text(
              'Logout',
              style: TextStyle(
                color: const Color(0xFFD32F2F),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Sign out from this device',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),
            onTap: () async {
              showDialog(
                context: context,
                builder: (_) => LogoutDialog(storageService: StorageService()),
              );
            },
          ),
        ],
      ),
    );
  }
}
