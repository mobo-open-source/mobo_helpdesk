import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../core/session/models/session_model.dart';
import '../../../main/presentation/pages/main_layout_page.dart';
import '../../data/services/totp_http_login_service.dart';
import '../bloc/login_bloc.dart';
import '../widgets/access_denied_dialog.dart';
import '../widgets/module_missing_dialog.dart';
import '../widgets/portal_user_dialog.dart';
import '../widgets/totp_webview_fallback.dart';

/// TOTP (two-factor authentication) page: collects the six-digit code and
/// completes the Odoo login with it.
///
/// The login is driven by [OdooTotpHttpClient] as three ordinary form
/// requests. The first two — the ones that need only the password — are sent
/// the moment this page opens, while the user is still reaching for their
/// authenticator app, so by the time a code is typed only one round trip is
/// left.
///
/// [TotpWebViewFallback] takes over for servers whose login pages that client
/// does not recognise. On a standard Odoo server no WebView is ever created.
///
/// Once the server reports an authenticated session for the expected user,
/// [LoginBloc] finishes the login ([CompleteTotpLogin]): the portal, access and
/// module checks, and saving the session. This page reacts to the outcome.
class TotpPage extends StatefulWidget {
  final String protocol;
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final bool isAddAccount;
  final SessionModel? currentSession;

  const TotpPage({
    super.key,
    required this.protocol,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    this.isAddAccount = false,
    this.currentSession,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isButtonEnabled = false;

  /// Drives the login over plain HTTP. Null once the flow has handed off to
  /// [_webViewFallback].
  OdooTotpHttpClient? _httpClient;

  /// Only created for servers the HTTP client could not drive.
  TotpWebViewFallbackController? _webViewFallback;

  /// Completes when a code can be submitted. Awaited by [_submitTotp] so a
  /// user who types faster than the handshake still gets a single, seamless
  /// wait rather than a failed attempt.
  late Future<void> _preparation;

  /// Blocking overlay, fallback only — the HTTP handshake never shows one.
  /// It runs in the background while the user reads their code off their
  /// authenticator app, so there is nothing to make them wait for.
  bool _loading = false;

  /// True while a code is in flight, or while the session it produced is
  /// being verified and saved.
  bool _verifying = false;

  /// Set when the flow cannot continue as it stands (refused password,
  /// unreachable server). The next Authenticate tap starts it over.
  bool _blocked = false;

  /// A session the server issued without ever asking for a code, i.e.
  /// two-factor is no longer enabled for this account. Held rather than only
  /// acted on, so a code submitted in the same moment finishes with this
  /// session instead of being sent to a server that is no longer expecting
  /// one.
  String? _sessionWithoutCode;

  String? _error;

  /// True while [LoginBloc] is finishing the login for a verified session, so
  /// a second completion (a fallback WebView report racing a submitted code)
  /// cannot be started on top of it.
  bool _completing = false;

  /// Set once the bloc has kept the session, so no later completion can start
  /// a second login on top of the one that already succeeded.
  bool _finished = false;

  String get _baseUrl {
    final url = (widget.protocol + widget.serverUrl).trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  void initState() {
    super.initState();
    _preparation = _prepare();
  }

  @override
  void dispose() {
    _httpClient?.close();
    _totpController.dispose();
    super.dispose();
  }

  /// Returns to the credential screen.
  ///
  /// One pop, not two: this screen sits directly on top of the credential
  /// screen, and popping twice also dropped that screen, landing the user back
  /// on the server configuration screen. The 2FA flags are cleared first, so
  /// the credential screen is not left holding a challenge that is no longer on
  /// screen - otherwise signing in again could not reopen this page.
  void _handleBack() {
    context.read<LoginBloc>().add(const CancelTotp());
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Login flow
  // ---------------------------------------------------------------------

  /// Sends the password half of the login — everything that does not need
  /// the user's code — so only the code submission is left by the time they
  /// have one. Never throws: every outcome is reported through the UI state.
  Future<void> _prepare() async {
    if (_webViewFallback != null) {
      // This server already turned out not to be one the HTTP client can
      // drive; replay the WebView rather than re-testing that.
      await _startWebViewFallback();
      return;
    }

    _httpClient?.close();
    final client = OdooTotpHttpClient(
      serverUrl: _baseUrl,
      database: widget.database,
    );
    _httpClient = client;

    TotpHandshake handshake;
    try {
      handshake = await client.begin(
        login: widget.username,
        password: widget.password,
      );
    } on TotpHandshakeUnsupported {
      // A login flow this client does not drive — hand over to the WebView,
      // which renders whatever the server actually serves.
      await _startWebViewFallback();
      return;
    } on SocketException {
      await _startWebViewFallback();
      return;
    } on HandshakeException {
      // A certificate Dart refuses but the WebView is configured to accept.
      await _startWebViewFallback();
      return;
    } on TimeoutException {
      _fail('The server took too long to respond. Please try again.');
      return;
    } catch (_) {
      await _startWebViewFallback();
      return;
    }

    if (!mounted) return;

    switch (handshake.outcome) {
      case TotpHandshakeOutcome.codeRequired:
        break;

      case TotpHandshakeOutcome.authenticated:
        // Two-factor is no longer switched on for this account, and the
        // password alone signed it in. There is no code to ask for.
        // [_signInWithoutCode] still verifies the session with the server
        // before it is kept.
        await _signInWithoutCode(handshake.sessionId!);

      case TotpHandshakeOutcome.credentialsRejected:
        _fail(
          handshake.message ??
              'Sign-in was refused. Please check your credentials and try '
                  'again.',
        );
    }
  }

  /// Signs in with a session the server issued without asking for a code,
  /// which happens only when two-factor is no longer enabled for this
  /// account. Shown as a normal authentication so the screen does not look
  /// frozen while the session is verified and saved.
  Future<void> _signInWithoutCode(String sessionId) async {
    _sessionWithoutCode = sessionId;
    // A submission already in flight picks this session up itself once it is
    // done waiting on the handshake, so this stays out of its way.
    if (_verifying || !mounted) return;
    setState(() => _verifying = true);
    try {
      await _completeLogin(sessionId);
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Mounts the WebView fallback and waits for it to reach the TOTP form.
  Future<void> _startWebViewFallback() async {
    if (!mounted) return;

    final fallback = TotpWebViewFallbackController();
    _httpClient?.close();
    setState(() {
      _httpClient = null;
      _webViewFallback = fallback;
      // The only path that still shows the overlay: driving the real login
      // pages means two full page loads before a code can be sent.
      _loading = true;
    });

    try {
      await fallback.ready;
    } catch (_) {
      _fail(
        'Could not reach the sign-in page on this server. Please check your '
        'connection and try again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submitTotp() async {
    if (_verifying) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() => _error = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      if (_blocked) {
        // The last attempt to reach the server failed outright. Start the
        // whole flow over rather than leaving this button dead.
        setState(() => _blocked = false);
        _preparation = _prepare();
      }

      // Normally already finished — the handshake ran while the code was
      // being read off the authenticator app.
      await _preparation;
      if (!await _readyToSendCode()) return;

      var submission = await _sendCode(totp);

      if (submission.outcome == TotpSubmitOutcome.handshakeExpired) {
        // The partial session aged out while this screen sat open. Replay
        // the password step and resend the same code, which is still inside
        // its own validity window.
        _preparation = _prepare();
        await _preparation;
        if (!await _readyToSendCode()) return;
        submission = await _sendCode(totp);
      }

      if (!mounted) return;

      switch (submission.outcome) {
        case TotpSubmitOutcome.authenticated:
          await _completeLogin(submission.sessionId!);

        case TotpSubmitOutcome.codeRejected:
          _showError(submission.message!);

        case TotpSubmitOutcome.handshakeExpired:
          _showError(
            'Your sign-in attempt expired. Please enter a fresh code.',
          );
      }
    } on TimeoutException {
      _showError('The server took too long to respond. Please try again.');
    } on SocketException {
      _showError(
        'Could not reach the server. Please check your connection and try '
        'again.',
      );
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Whether the code still has anywhere to go once the handshake has
  /// settled. A handshake that came back already signed in finishes the
  /// login here instead — sending a code to a server that is no longer
  /// expecting one would only fail.
  Future<bool> _readyToSendCode() async {
    if (!mounted || _blocked) return false;

    final sessionWithoutCode = _sessionWithoutCode;
    if (sessionWithoutCode != null) {
      await _completeLogin(sessionWithoutCode);
      return false;
    }
    return true;
  }

  /// Submits [code] through whichever transport is driving this login,
  /// switching to the WebView fallback if the HTTP one turns out not to
  /// handle this server's TOTP form after all.
  Future<TotpSubmission> _sendCode(String code) async {
    final client = _httpClient;
    if (client != null) {
      try {
        return await client.submitCode(code);
      } on TotpHandshakeUnsupported {
        await _startWebViewFallback();
        if (!mounted || _blocked) {
          return const TotpSubmission.handshakeExpired();
        }
      }
    }

    final fallback = _webViewFallback;
    if (fallback == null) {
      throw StateError('no transport is driving this login');
    }
    await fallback.ready;
    return fallback.submit(code);
  }

  /// Verifies the session the server issued, then hands it to [LoginBloc] to
  /// be kept and waits for the bloc to finish. The bloc reports the outcome —
  /// success, or a portal / access / module rejection — through its state,
  /// which the page's listener acts on.
  Future<void> _completeLogin(String sessionId) async {
    if (_finished || _completing) return;

    // The only authoritative check: ask Odoo whether this session is
    // actually authenticated, and as the expected user. A cookie or a
    // redirect on its own can't tell a verified session apart from one that
    // skipped the challenge entirely.
    final sessionInfo = await OdooTotpHttpClient.fetchSessionInfo(
      serverUrl: _baseUrl,
      sessionId: sessionId,
    );

    final uid = sessionInfo?['uid'];
    final sessionLogin = (sessionInfo?['username'] ?? sessionInfo?['login'])
        ?.toString();
    final isVerified =
        uid is int &&
        uid > 0 &&
        (sessionLogin == null ||
            sessionLogin.toLowerCase() == widget.username.trim().toLowerCase());

    if (!isVerified) {
      if (!mounted) return;
      if (_sessionWithoutCode == sessionId) {
        // Nothing for the user to retype: this session came from a server
        // that never asked for a code, so a fresh one would go nowhere.
        _sessionWithoutCode = null;
        _fail('Sign-in could not be completed. Please try again.');
      } else {
        _showError('Invalid code or login failed. Please try again.');
      }
      return;
    }

    if (!mounted || _finished || _completing) return;
    _completing = true;

    final bloc = context.read<LoginBloc>();
    // The bloc answers with a "verifying" state followed by the outcome. Only
    // the outcome that follows the "verifying" state is this login's, so an
    // unrelated state emitted before the bloc picks the event up is skipped.
    var started = false;
    // Subscribed before the event is added, so no state it emits can be
    // missed.
    final done = bloc.stream.firstWhere((state) {
      if (state.isTotpVerifying) {
        started = true;
        return false;
      }
      return started;
    });
    // Awaited below; ignoring here only keeps a failed `add` from leaving this
    // future to error with nobody listening.
    done.ignore();

    try {
      bloc.add(
        CompleteTotpLogin(
          sessionId: sessionId,
          serverUrl: _baseUrl,
          database: widget.database,
          username: widget.username,
          password: widget.password,
        ),
      );
      final result = await done;
      if (result.isLoginSuccess) _finished = true;
    } on StateError {
      // The bloc was closed before it answered; there is nothing left to wait
      // for.
    } finally {
      _completing = false;
    }
  }

  // ---------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  /// A failure no retyped code can get past on its own. Lifts any overlay so
  /// the screen shows [message]; the next Authenticate tap starts the whole
  /// flow over.
  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _blocked = true;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        _handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  image: DecorationImage(
                    image: AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.white,
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),

            if (_webViewFallback != null)
              TotpWebViewFallback(
                // Keyed on the controller so restarting the fallback builds a
                // fresh WebView bound to the new controller, rather than
                // leaving the old State attached to the old one.
                key: ObjectKey(_webViewFallback),
                controller: _webViewFallback!,
                serverUrl: _baseUrl,
                database: widget.database,
                username: widget.username,
                password: widget.password,
                onAuthenticated: _signInWithoutCode,
              ),

            SafeArea(
              child: BlocConsumer<LoginBloc, LoginState>(
                // Transitions only, so a rebuild cannot raise the same dialog
                // or navigate twice.
                listenWhen: (previous, current) =>
                    previous.totpError != current.totpError ||
                    previous.isLoginSuccess != current.isLoginSuccess ||
                    previous.isModuleInstall != current.isModuleInstall,
                listener: (context, state) {
                  if (state.totpError == "Portal Access") {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => PortalUserDialog(
                        isAddAccount: widget.isAddAccount,
                        currentSession: widget.currentSession,
                        initialUrl: _baseUrl,
                        initialDatabase: widget.database,
                      ),
                    );
                    return;
                  }
                  if (state.totpError == "Access Denied") {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AccessDeniedDialog(
                        returnToConfiguration: true,
                        isAddAccount: widget.isAddAccount,
                        currentSession: widget.currentSession,
                        initialUrl: _baseUrl,
                        initialDatabase: widget.database,
                      ),
                    );
                    return;
                  }
                  if (state.totpError == "Module Missing") {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ModuleMissingDialog(
                        isAddAccount: widget.isAddAccount,
                        currentSession: widget.currentSession,
                        initialUrl: _baseUrl,
                        initialDatabase: widget.database,
                      ),
                    );
                    return;
                  }
                  if (state.isLoginSuccess) {
                    // Same handling as the credential screen: a database
                    // without the module must not reach the dashboard, and the
                    // login screens below are removed so back cannot return to
                    // them once signed in. `pushReplacement` only replaced this
                    // page and left the credential and configuration screens in
                    // the stack.
                    if (!state.isModuleInstall) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ModuleMissingDialog(
                          isAddAccount: widget.isAddAccount,
                          currentSession: widget.currentSession,
                          initialUrl: _baseUrl,
                          initialDatabase: widget.database,
                        ),
                      );
                      return;
                    }

                    // MainLayout reloads every bloc itself.
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => MainLayout()),
                      (route) => false,
                    );
                    return;
                  }
                  if (state.totpError != null) {
                    // A code is single use, so the refused digits are cleared:
                    // submitting them again could only fail again.
                    _totpController.clear();
                    setState(() {
                      _isButtonEnabled = false;
                      _error = state.totpError;
                    });
                  }
                },
                builder: (context, state) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 80, 28, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 48),
                                _buildTotpForm(state),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: BlocBuilder<LoginBloc, LoginState>(
                  builder: (context, state) {
                    // Back is only held while the fallback is still reaching
                    // the challenge, or while the bloc is saving the session.
                    final canGoBack = !state.isTotpVerifying && !_loading;
                    return IgnorePointer(
                      ignoring: !canGoBack,
                      child: IconButton(
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: canGoBack ? Colors.white : Colors.white54,
                          size: 28,
                        ),
                        onPressed: canGoBack ? () => _handleBack() : null,
                      ),
                    );
                  },
                ),
              ),
            ),

            if (_loading)
              Container(
                color: isDark ? Colors.black54 : Colors.white70,
                child: Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: Theme.of(context).colorScheme.primary,
                    size: 60,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 64,
        ),
        const SizedBox(height: 24),
        Text(
          "Two-Factor Authentication",
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "Enter the 6-digit code from your authenticator app",
          style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(_baseUrl, style: TextStyle(fontSize: 13, color: Colors.white54)),
      ],
    );
  }

  Widget _buildTotpForm(LoginState state) {
    final busy = _verifying || state.isTotpVerifying;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextFormField(
              controller: _totpController,
              keyboardType: TextInputType.number,
              enabled: !busy && !_loading,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Enter OTP Code",
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: .4),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 10, right: 4),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSmsCode,
                    color: Colors.black54,
                    size: 25,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 40,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'TOTP is required';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _isButtonEnabled = value.trim().isNotEmpty;
                  _formKey.currentState?.validate();
                  if (_error != null) _error = null;
                });
              },
            ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10.0,
                      left: 2,
                      right: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (busy || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
