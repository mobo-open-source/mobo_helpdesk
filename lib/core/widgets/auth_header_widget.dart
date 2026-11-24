import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A header widget used in authentication screens.
///
/// Displays the app logo and name ("mobo Helpdesk") centered at the top.
/// Optionally shows a back button on the top-left when `isBackAvailable` is true.
class AuthHeaderWidget extends StatelessWidget {
  final String assetPath;
  final VoidCallback? onBack;
  final bool isLoading;
  final bool isBackAvailable;

  const AuthHeaderWidget({
    super.key,
    this.assetPath = 'assets/helpdesk-icon.png',
    this.onBack,
    this.isLoading = false,
    this.isBackAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Back Button
        if (isBackAvailable)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (onBack != null) {
                      onBack!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
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

        // Logo + App Name
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lifted so the icon's bottom edge sits on the same
                    // line as the text's baseline.
                    Transform.translate(
                      offset: const Offset(0, -6),
                      child: Image.asset(
                        'assets/helpdesk-icon.png',
                        fit: BoxFit.fitWidth,
                        height: 30,
                        width: 30,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.support_agent_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      // Yaro font has extra top spacing; nudge text up so it
                      // sits level with the logo.
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'mobo Helpdesk',
                        style: TextStyle(
                          fontFamily: 'Yaro',
                          color: Colors.white,
                          fontSize: 24,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
