import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

/// A circular profile image widget.
///
/// Displays an image from [avatarBytes] (supports SVG and normal images).
/// If no image is available, a fallback icon is shown.
///
/// Customizable with size, background color, border, and context
/// (dashboard or profile) for styling the fallback icon.
class ProfileImage extends StatelessWidget {
  final Uint8List? avatarBytes;
  final bool? isSvg;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool isDashboard;
  final bool isProfile;

  const ProfileImage({
    super.key,
    this.avatarBytes,
    this.isSvg,
    this.size = 40,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.isDashboard = false,
    this.isProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool svg = isSvg ?? false;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: (avatarBytes != null)
            ? (svg
                  ? SvgPicture.memory(
                      avatarBytes!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : Image.memory(
                      avatarBytes!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackIcon(),
                    ))
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Center(
      child: HugeIcon(
        icon: isDashboard
            ? HugeIcons.strokeRoundedUserCircle
            : isProfile
            ? HugeIcons.strokeRoundedUser
            : HugeIcons.strokeRoundedUser03,
        size: isDashboard
            ? size * 0.9
            : isProfile
            ? size * 0.5
            : size * 0.6,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}
