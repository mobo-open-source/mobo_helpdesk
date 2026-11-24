import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/features/login/presentation/pages/webview_screen.dart';

import '../bloc/login_bloc.dart';
import '../widgets/reset_view_form.dart';
import '../widgets/reset_view_header.dart';

/// Screen responsible for handling password reset flow.
///
/// This screen allows users to request a password reset email and
/// handles multiple states of the reset process, including:
///
/// - Sending password reset request
/// - Displaying loading state
/// - Showing success confirmation animation
/// - Displaying error messages
/// - Redirecting to WebView-based reset flow when required
///
/// It listens to [LoginBloc] state changes and reacts accordingly:
/// - Shows success animation when reset email is sent
/// - Navigates to [WebViewScreen] if server requires WebView authentication
/// - Displays form or success UI based on current state
///
/// The screen also supports:
/// - Smooth success animations (fade + slide)
/// - Back navigation control during loading states
class ResetPasswordScreen extends StatefulWidget {
  final String url;
  final String database;

  const ResetPasswordScreen({
    super.key,
    required this.url,
    required this.database,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _successAnimationController;
  late Animation<Offset> _successSlideAnimation;
  late Animation<double> _successFadeAnimation;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _successSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _successAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _successFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.resetSuccessMessage != null) {
          _successAnimationController.forward(from: 0.0);
          HapticFeedback.selectionClick();
        }

        if (state.resetErrorMessage != null) {
          HapticFeedback.heavyImpact();
        }

        if (state.resetRequiresWebView && state.resetWebViewUrl != null) {
          HapticFeedback.lightImpact();

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewScreen(
                  url: state.resetWebViewUrl!,
                  title: 'Reset Password',
                ),
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state.isResetLoading;
        final successMessage = state.resetSuccessMessage;
        final errorMessage = state.resetErrorMessage;
        return PopScope(
          canPop: !isLoading,
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[950] : Colors.grey[50],
                      image: DecorationImage(
                        image: AssetImage('assets/background.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          isDark
                              ? Colors.black.withValues(alpha: 1)
                              : Colors.white.withValues(alpha: 1),
                          BlendMode.dstATop,
                        ),
                      ),
                    ),
                  ),
                ),

                LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ResetViewHeader(url: widget.url),
                                  const SizedBox(height: 48),

                                  if (successMessage != null)
                                    AnimatedBuilder(
                                      animation: _successAnimationController,
                                      builder: (context, child) {
                                        return SlideTransition(
                                          position: _successSlideAnimation,
                                          child: FadeTransition(
                                            opacity: _successFadeAnimation,
                                            child: Container(
                                              padding: const EdgeInsets.all(32),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedCheckmarkCircle02,
                                                    color: Colors.green,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Email Sent!',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    successMessage,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 14,
                                                      color: Colors.white70,
                                                      height: 1.4,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  if (successMessage == null) ...[
                                    ResetViewForm(
                                      isLoading: isLoading,
                                      errorMessage: errorMessage,
                                      url: widget.url,
                                      database: widget.database,
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.black
                                              .withValues(alpha: .75),
                                          disabledForegroundColor: Colors.white,
                                          overlayColor: Colors.transparent,
                                          surfaceTintColor: Colors.transparent,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Back to Login',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          height: 64,
                          width: 64,
                          alignment: Alignment.center,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowLeft01,
                            color: isLoading ? Colors.white54 : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
