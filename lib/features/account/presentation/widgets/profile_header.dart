import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/profile_image.dart';

/// A UI component that displays the user's profile summary.
///
/// This header shows:
/// - User profile image (supports both image bytes and SVG)
/// - User name (with fallback to "No Name" if empty)
/// - User email (with fallback to "No Email" if empty)
/// - A trailing arrow indicating it is tappable or navigable
///
/// Typically used in profile or settings screens to provide
/// a quick overview of the signed-in user.
///
/// The widget uses a gradient background with the app's primary color
/// and supports custom styling for the profile avatar.
class ProfileHeader extends StatelessWidget {
  final String userName;
  final String mail;
  final Uint8List? profileImage;
  final bool isSvg;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.mail,
    required this.profileImage,
    required this.isSvg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileImage(
            avatarBytes: profileImage,
            isSvg: isSvg,
            size: 60,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            borderColor: Colors.white.withValues(alpha: 0.3),
            borderWidth: 2,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isNotEmpty ? userName : "No Name",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  mail.isNotEmpty ? mail : "No Email",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.7,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}
