import 'package:flutter/foundation.dart';

/// Whether plain `http://` servers may be used.
///
/// Only in debug builds, so developers can test against a local Odoo server.
/// Release builds are HTTPS-only (and Android blocks cleartext traffic there),
/// so credentials and session cookies never travel unencrypted in production.
const bool allowInsecureHttp = kDebugMode;
