import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/session/models/session_model.dart';
import '../../../../core/widgets/auth_header_widget.dart';
import '../../../../di/injection_container.dart';
import '../../../main/presentation/pages/main_layout_page.dart';
import '../bloc/login_bloc.dart';
import '../widgets/database_dropdown.dart';
import '../widgets/error_message.dart';
import '../widgets/url_input_field.dart';
import 'credential_screen.dart';

/// Entry screen for collecting server URL and selecting a database.
///
/// This screen is the first step in the authentication flow and is responsible for:
/// - Accepting the server URL input
/// - Fetching available databases from the server
/// - Allowing the user to select a database
/// - Navigating to the credential (login) screen
///
/// It uses [LoginBloc] to:
/// - Load URL history
/// - Fetch databases based on URL
/// - Maintain selected database state
///
/// If [isAddAccount] is true, this screen behaves in "add account" mode
/// and returns to the main application instead of exiting.
///
/// Once a valid URL and database are selected, it navigates to [CredentialScreen].
class UrlDatabaseScreen extends StatelessWidget {
  /// Route name used to locate an already opened server configuration screen
  /// in the navigation stack (see `backFromFailedLogin`).
  static const String routeName = '/url-database';

  final bool isAddAccount;
  final String? title;
  final String? subtitle;
  final String? initialUrl;
  final String? initialDatabase;
  final SessionModel? currentSession;

  const UrlDatabaseScreen({
    super.key,
    this.isAddAccount = false,
    this.title,
    this.subtitle,
    this.initialUrl,
    this.initialDatabase,
    this.currentSession,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: UrlDatabaseView(
        isAddAccount: isAddAccount,
        title: title,
        subtitle: subtitle,
        initialUrl: initialUrl,
        initialDatabase: initialDatabase,
        currentSession: currentSession,
      ),
    );
  }
}

/// Stateful implementation of [UrlDatabaseScreen].
///
/// Handles:
/// - Initialization of URL history and prefilled values
/// - Back navigation behavior (exit app or return to main layout)
/// - UI rendering for URL input, database dropdown, and next button
/// - Navigation to [CredentialScreen] with selected data
class UrlDatabaseView extends StatefulWidget {
  final bool isAddAccount;
  final String? title;
  final String? subtitle;
  final String? initialUrl;
  final String? initialDatabase;
  final SessionModel? currentSession;

  const UrlDatabaseView({
    super.key,
    this.isAddAccount = false,
    this.title,
    this.subtitle,
    this.initialUrl,
    this.initialDatabase,
    this.currentSession,
  });

  @override
  State<UrlDatabaseView> createState() => _UrlDatabaseViewState();
}

class _UrlDatabaseViewState extends State<UrlDatabaseView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<LoginBloc>();
      bloc.add(LoadUrlHistory(widget.initialUrl ?? 'https://'));

      if (widget.initialUrl != null) {
        bloc.add(UrlChanged(widget.initialUrl!));

        Future.delayed(const Duration(milliseconds: 900), () {
          if (widget.initialDatabase != null) {
            bloc.add(DatabaseSelected(widget.initialDatabase!));
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (widget.isAddAccount) {
          final navigator = Navigator.of(context);

          // Going back means returning to the screen this was opened from -
          // the Configuration page - which is still in the stack. Pushing a
          // fresh MainLayout instead grew the stack on every back press and
          // was also inconsistent with the header's back button, which pops.
          if (navigator.canPop()) {
            navigator.pop();
            return;
          }

          // Nothing left to go back to (the stack was replaced), so the app is
          // shown rather than leaving the user on the login screen.
          navigator.push(MaterialPageRoute(builder: (context) => MainLayout()));
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  image: DecorationImage(
                    image: AssetImage("assets/background.png"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
            AuthHeaderWidget(isBackAvailable: widget.isAddAccount),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        SizedBox(height: 30),
                        Text(
                          widget.title ?? 'Sign In',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle ??
                              'use proper information to continue',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 40),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: const UrlInputField(),
                        ),

                        BlocBuilder<LoginBloc, LoginState>(
                          builder: (context, state) {
                            if (state.databases.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 30),
                                child: const DatabaseDropdown(),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: const SizedBox.shrink(),
                              );
                            }
                          },
                        ),
                        const ErrorMessage(type: 'url'),

                        BlocSelector<LoginBloc, LoginState, bool>(
                          selector: (state) =>
                              state.databases.isEmpty ||
                              (state.selectedDatabase == null),
                          builder: (context, isDisabled) {
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isDisabled
                                    ? null
                                    : () {
                                        final state = context
                                            .read<LoginBloc>()
                                            .state;
                                        String finalDb =
                                            state.selectedDatabase ?? '';
                                        String cleanUrl = state.url.trim();
                                        String protocolToUse = state.protocol;

                                        if (cleanUrl.startsWith('http://')) {
                                          protocolToUse = 'http://';
                                          cleanUrl = cleanUrl.replaceFirst(
                                            'http://',
                                            '',
                                          );
                                        } else if (cleanUrl.startsWith(
                                          'https://',
                                        )) {
                                          protocolToUse = 'https://';
                                          cleanUrl = cleanUrl.replaceFirst(
                                            'https://',
                                            '',
                                          );
                                        }
                                        final loginBloc = context
                                            .read<LoginBloc>();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BlocProvider.value(
                                                  value: loginBloc,
                                                  child: CredentialScreen(
                                                    protocol: protocolToUse,
                                                    url: cleanUrl,
                                                    database: finalDb,
                                                    isAddAccount:
                                                        widget.isAddAccount,
                                                    currentSession:
                                                        widget.currentSession,
                                                    previousUrl:
                                                        widget.initialUrl,
                                                    previousDatabase:
                                                        widget.initialDatabase,
                                                  ),
                                                ),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Next',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
