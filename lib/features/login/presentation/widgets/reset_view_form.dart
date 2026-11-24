import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../data/services/reset_password_service.dart';
import '../bloc/login_bloc.dart';

/// A form widget used for requesting a password reset email.
///
/// This widget allows the user to enter their email address and
/// triggers a [RequestPasswordReset] event via [LoginBloc].
///
/// It also handles:
/// - Email validation, held back until the first send attempt
/// - Loading state UI
/// - Displaying server-side error messages, cleared once the user edits again
/// - Disabling input while request is in progress
class ResetViewForm extends StatefulWidget {
  final bool isLoading;
  final String? errorMessage;
  final String url;
  final String database;

  const ResetViewForm({
    super.key,
    required this.isLoading,
    this.errorMessage,
    required this.url,
    required this.database,
  });

  @override
  State<ResetViewForm> createState() => _ResetViewFormState();
}

class _ResetViewFormState extends State<ResetViewForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  /// Validation stays quiet until the user has tried to send once, so the field
  /// does not turn red while it is still being filled in.
  bool _shouldValidate = false;

  bool _emailHasError = false;

  /// Hides the error returned by the server once the user starts editing again.
  bool _errorDismissed = false;

  @override
  void didUpdateWidget(ResetViewForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new error is a new thing to say, so it is shown even if the previous one
    // had been dismissed.
    if (widget.errorMessage != oldWidget.errorMessage) {
      _errorDismissed = false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? get _errorMessage =>
      _errorDismissed ? null : widget.errorMessage;

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _shouldValidate = true;
      _errorDismissed = true;
    });

    final email = _emailController.text.trim();
    final formValid = _formKey.currentState?.validate() ?? false;

    setState(() {
      _emailHasError =
          email.isEmpty || !ResetPasswordService.isValidEmail(email);
    });

    if (!formValid) {
      await HapticFeedback.lightImpact();
      return;
    }

    if (!mounted) return;
    context.read<LoginBloc>().add(
      RequestPasswordReset(
        email: email,
        url: widget.url,
        database: widget.database,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !widget.isLoading,
            autovalidateMode: _shouldValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: (value) {
              if (!_shouldValidate) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _emailHasError =
                    value.trim().isEmpty ||
                    !ResetPasswordService.isValidEmail(value.trim());
                _errorDismissed = true;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Email Address',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withValues(alpha: .4),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(13.0),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMail01,
                  size: 20,
                  color: Colors.black54,
                ),
              ),
              prefixIconColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              suffixIcon: _emailHasError
                  ? Icon(Icons.error_outline, color: Colors.red, size: 20)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: errorMessage != null ? 48 : 0,
            child: errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
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
                            errorMessage,
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
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withValues(alpha: .75),
                disabledForegroundColor: Colors.white,
                overlayColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sending',
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
                      'Send',
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
