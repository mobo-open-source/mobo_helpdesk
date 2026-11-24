import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:mobo_helpdesk/features/login/presentation/pages/reset_password_screen.dart';
import 'package:mobo_helpdesk/features/login/presentation/pages/totp_page.dart';

import '../../../../core/session/models/session_model.dart';
import '../../../../core/widgets/auth_header_widget.dart';
import '../../../../di/injection_container.dart';
import '../../../main/presentation/pages/main_layout_page.dart';
import '../bloc/login_bloc.dart';
import '../widgets/credential_fields.dart';
import '../widgets/error_message.dart';
import '../widgets/module_missing_dialog.dart';
import '../widgets/portal_user_dialog.dart';
import '../widgets/access_denied_dialog.dart';

/// Screen responsible for handling user credential input for login.
///
/// This screen allows users to:
/// - Enter username and password
/// - Toggle password visibility
/// - Submit login credentials
/// - Navigate to password reset flow
/// - Handle Two-Factor Authentication (TOTP) flow
/// - Display authentication errors
///
/// It communicates with [LoginBloc] to manage authentication state
/// and reacts to state changes such as:
/// - Login success
/// - Enterprise module validation
/// - TOTP requirement
/// - Password reset flow
///
/// On successful login, it navigates to the main application screen.
/// If TOTP is required, it navigates to the [TotpPage].
class CredentialScreen extends StatefulWidget {
  final String protocol;
  final String url;
  final String database;

  final String? initialUsername;
  final String? initialPassword;

  final String? previousUrl;
  final String? previousDatabase;
  final bool isAddAccount;
  final SessionModel? currentSession;

  const CredentialScreen({
    super.key,
    required this.protocol,
    required this.url,
    required this.database,
    this.initialUsername,
    this.initialPassword,
    this.previousUrl,
    this.previousDatabase,
    this.isAddAccount = false,
    this.currentSession,
  });

  @override
  State<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends State<CredentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _usernameController.text = widget.initialUsername ?? '';

    _passwordController.text = widget.initialPassword ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrorAndGoBack() {
    context.read<LoginBloc>().add(ClearErrorMessage(widget.database));

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _clearErrorAndGoBack();
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
                child: SafeArea(
                  child: Column(
                    children: [
                      BlocBuilder<LoginBloc, LoginState>(
                        builder: (context, state) {
                          return AuthHeaderWidget(
                            isLoading: state.isLoading,
                            isBackAvailable: true,
                            onBack: _clearErrorAndGoBack,
                          );
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    Text(
                                      widget.isAddAccount
                                          ? 'Add Account'
                                          : 'Sign In',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.isAddAccount
                                          ? 'Enter your credentials to add account'
                                          : 'use proper information to continue',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 30),

                                    CredentialFields(
                                      controller: _usernameController,
                                      label: "Username",
                                      icon: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10.0,
                                          right: 4,
                                        ),
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedUser03,
                                          color: Colors.black54,
                                          size: 20,
                                        ),
                                      ),
                                      onChanged: (_) {
                                        if (context
                                                .read<LoginBloc>()
                                                .state
                                                .credentialError !=
                                            '') {
                                          context.read<LoginBloc>().add(
                                            ClearErrorMessage(widget.database),
                                          );
                                        }
                                        if (_formKey.currentState!
                                            .validate()) {}
                                      },
                                    ),

                                    const SizedBox(height: 20),
                                    BlocBuilder<LoginBloc, LoginState>(
                                      builder: (context, state) => CredentialFields(
                                        controller: _passwordController,
                                        label: "Password",
                                        icon: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 10.0,
                                            right: 4,
                                          ),
                                          child: HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedSquareLockPassword,
                                            color: Colors.black54,
                                            size: 20,
                                          ),
                                        ),
                                        isPasswordField: true,
                                        isPasswordVisible:
                                            state.isPasswordVisible,
                                        onVisibilityToggle: () {
                                          context.read<LoginBloc>().add(
                                            TogglePasswordVisibility(),
                                          );
                                        },
                                        onChanged: (_) {
                                          if (context
                                                  .read<LoginBloc>()
                                                  .state
                                                  .credentialError !=
                                              '') {
                                            context.read<LoginBloc>().add(
                                              ClearErrorMessage(
                                                widget.database,
                                              ),
                                            );
                                          }
                                          if (_formKey.currentState!
                                              .validate()) {}
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  BlocProvider(
                                                    create: (_) =>
                                                        sl<LoginBloc>(),
                                                    child: ResetPasswordScreen(
                                                      url:
                                                          widget.protocol +
                                                          widget.url,
                                                      database: widget.database,
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const ErrorMessage(type: 'credential'),
                                    BlocConsumer<LoginBloc, LoginState>(
                                      // Only transitions are acted on. The
                                      // TOTP screen shares this bloc, so every
                                      // state it emits also reaches this
                                      // listener: without this, a state that
                                      // still carries `requiresTotp` or
                                      // `isLoginSuccess` pushed the TOTP screen
                                      // (or the dashboard) a second time.
                                      listenWhen: (previous, current) =>
                                          previous.credentialError !=
                                              current.credentialError ||
                                          previous.requiresTotp !=
                                              current.requiresTotp ||
                                          previous.isLoginSuccess !=
                                              current.isLoginSuccess ||
                                          previous.isModuleInstall !=
                                              current.isModuleInstall,
                                      listener: (context, state) async {
                                        if (state.credentialError ==
                                            "Portal Access") {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => PortalUserDialog(
                                              isAddAccount: widget.isAddAccount,
                                              currentSession:
                                                  widget.currentSession,
                                              initialUrl:
                                                  widget.protocol + widget.url,
                                              initialDatabase: widget.database,
                                            ),
                                          );
                                          return;
                                        }
                                        if (state.credentialError ==
                                            "Access Denied") {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => AccessDeniedDialog(
                                              returnToConfiguration: true,
                                              isAddAccount: widget.isAddAccount,
                                              currentSession:
                                                  widget.currentSession,
                                              initialUrl:
                                                  widget.protocol + widget.url,
                                              initialDatabase: widget.database,
                                            ),
                                          );
                                          return;
                                        }
                                        if (state.credentialError ==
                                            "Module Missing") {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => ModuleMissingDialog(
                                              isAddAccount: widget.isAddAccount,
                                              currentSession:
                                                  widget.currentSession,
                                              initialUrl:
                                                  widget.protocol + widget.url,
                                              initialDatabase: widget.database,
                                            ),
                                          );
                                          return;
                                        }
                                        if (state.requiresTotp) {
                                          final loginBloc = context
                                              .read<LoginBloc>();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BlocProvider.value(
                                                    value: loginBloc,
                                                    child: TotpPage(
                                                      protocol: widget.protocol,
                                                      serverUrl: widget.url,
                                                      database: widget.database,
                                                      username:
                                                          _usernameController
                                                              .text
                                                              .trim(),
                                                      password:
                                                          _passwordController
                                                              .text
                                                              .trim(),
                                                      isAddAccount:
                                                          widget.isAddAccount,
                                                      currentSession:
                                                          widget.currentSession,
                                                    ),
                                                  ),
                                            ),
                                          );
                                          return;
                                        }
                                        // While a 2FA challenge is open the
                                        // TOTP screen owns what happens next,
                                        // so this screen stays out of it.
                                        if (state.isLoginSuccess &&
                                            !state.requiresTotp) {
                                          if (!state.isModuleInstall) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) =>
                                                  ModuleMissingDialog(
                                                    isAddAccount:
                                                        widget.isAddAccount,
                                                    currentSession:
                                                        widget.currentSession,
                                                    initialUrl:
                                                        widget.protocol +
                                                        widget.url,
                                                    initialDatabase:
                                                        widget.database,
                                                  ),
                                            );
                                          } else {
                                            // MainLayout reloads every bloc
                                            // itself; doing it here too would
                                            // load everything twice.
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => MainLayout(),
                                              ),
                                              (route) => false,
                                            );
                                          }
                                        }
                                      },
                                      builder: (context, state) {
                                        return SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: state.isLoading
                                                ? null
                                                : () {
                                                    if (_formKey.currentState!
                                                        .validate()) {
                                                      context.read<LoginBloc>().add(
                                                        CredentialSubmit(
                                                          protocol:
                                                              widget.protocol,
                                                          url: widget.url,
                                                          database:
                                                              widget.database,
                                                          username:
                                                              _usernameController
                                                                  .text
                                                                  .trim(),
                                                          password:
                                                              _passwordController
                                                                  .text
                                                                  .trim(),
                                                          isAddAccount: widget
                                                              .isAddAccount,
                                                          currentSession: widget
                                                              .currentSession,
                                                          previousUrl: widget
                                                              .previousUrl,
                                                          previousDatabase: widget
                                                              .previousDatabase,
                                                        ),
                                                      );
                                                    }
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: state.isLoading
                                                ? Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        widget.isAddAccount
                                                            ? 'Adding'
                                                            : 'Signing',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      LoadingAnimationWidget.staggeredDotsWave(
                                                        color: Colors.white,
                                                        size: 28,
                                                      ),
                                                    ],
                                                  )
                                                : Text(
                                                    widget.isAddAccount
                                                        ? "Add Account"
                                                        : "Sign In",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
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
                      ),
                    ],
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
