import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// A header widget displayed on the Reset Password screen.
///
/// This widget shows:
/// - A lock icon
/// - Title ("Reset Password")
/// - Instruction text for the user
/// - The current server URL being used for the reset request
///
/// It is typically used at the top of [ResetViewForm] to provide
/// context for the password reset flow.
class ResetViewHeader extends StatelessWidget {
  final String url;

  const ResetViewHeader({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedLockPassword,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        Text(
          'Reset Password',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Enter your email address and we\'ll send you a link to reset your password',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Server: $url',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
