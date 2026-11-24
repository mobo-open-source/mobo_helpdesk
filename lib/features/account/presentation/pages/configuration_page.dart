import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/features/account/presentation/pages/profile_page.dart';

import '../../../../core/events/profile_refresh_bus.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../widgets/configuration_items.dart';
import '../widgets/profile_header.dart';

/// Configuration screen of the application.
///
/// Displays user account information and provides access to
/// various configuration options such as:
/// - Profile management
/// - Account settings
/// - Application settings navigation
///
/// Also handles navigation back to the main layout screen.
///
/// The name, email and photo arrive as they were when the page opened; a
/// profile saved from here is picked up through [ProfileRefreshBus], so the
/// header is current when the user comes back from Profile Details.
class ConfigurationPage extends StatefulWidget {
  /// Route name used to locate this page in the navigation stack, so flows
  /// started from here (such as "add account") can return to it.
  static const String routeName = '/configuration';

  final String userName;
  final int userId;
  final String mail;
  final Uint8List? profileImage;
  final bool isSvg;
  final String currentUrl;
  final String currentDatabase;

  const ConfigurationPage({
    super.key,
    required this.userName,
    required this.userId,
    required this.mail,
    required this.profileImage,
    required this.currentUrl,
    required this.currentDatabase,
    required this.isSvg,
  });

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  late String _userName = widget.userName;
  late String _mail = widget.mail;
  late Uint8List? _profileImage = widget.profileImage;
  late bool _isSvg = widget.isSvg;
  StreamSubscription<ProfileUpdate>? _profileSub;

  @override
  void initState() {
    super.initState();
    _profileSub = ProfileRefreshBus.stream.listen((update) {
      if (!mounted) return;
      final bytes = update.imageBytes;
      setState(() {
        if (update.name.isNotEmpty) _userName = update.name;
        _mail = update.mail;
        // No photo in the update leaves the current one, as the store does.
        if (bytes != null) {
          _profileImage = bytes;
          _isSvg = isSvgBytes(bytes);
        }
      });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBarWidget(
          title: "Configuration",
          isDark: isDark,
          onBack: () => Navigator.of(context).pop(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
                child: ProfileHeader(
                  userName: _userName,
                  mail: _mail,
                  profileImage: _profileImage,
                  isSvg: _isSvg,
                ),
              ),
              const SizedBox(height: 32),
              ConfigurationItems(
                userName: _userName,
                userId: widget.userId,
                currentUrl: widget.currentUrl,
                currentDatabase: widget.currentDatabase,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
