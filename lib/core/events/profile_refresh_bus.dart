import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// What a saved profile changed on screen: the name, email and photo shown
/// around the app.
class ProfileUpdate {
  final String name;
  final String mail;

  /// Base64 photo as stored by Odoo; empty when the user has none.
  final String image;

  const ProfileUpdate({
    required this.name,
    required this.mail,
    required this.image,
  });

  /// [image] decoded, or null when there is no photo or it cannot be decoded.
  Uint8List? get imageBytes {
    if (image.isEmpty) return null;
    try {
      return base64Decode(image);
    } catch (_) {
      return null;
    }
  }
}

/// A simple event bus used to tell the rest of the app that the signed-in
/// user's profile was saved.
///
/// Screens that show the user's name or photo (the app bar avatar, dashboard
/// greeting, Configuration header, ticket avatars) hold their own copy, so
/// they listen here to redraw at once instead of waiting to be reopened.
///
/// Usage:
/// ```dart
/// // After the profile is saved
/// ProfileRefreshBus.notify(update);
///
/// // Listen for saved profiles
/// ProfileRefreshBus.stream.listen((update) {
///   // Redraw with update.name / update.imageBytes
/// });
/// ```
class ProfileRefreshBus {
  static final _controller = StreamController<ProfileUpdate>.broadcast();
  static int _avatarVersion = 0;

  static Stream<ProfileUpdate> get stream => _controller.stream;

  /// Counts saved profiles. Avatars fetched by URL (`/web/image/res.users/..`)
  /// keep the same URL when the photo changes, and a network image is cached
  /// and compared by URL, so the old picture would be drawn again. Adding this
  /// to the URL makes the next build fetch the new one.
  static int get avatarVersion => _avatarVersion;

  static void notify(ProfileUpdate update) {
    _avatarVersion++;
    _controller.add(update);
  }
}
