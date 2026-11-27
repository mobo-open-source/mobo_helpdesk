import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Certificates the user has explicitly chosen to trust, one per server
/// (`host:port`), pinned by SHA-256 fingerprint.
///
/// This is how servers with a self-signed or private-CA certificate are
/// supported without turning certificate validation off: a certificate is
/// accepted only if the user approved *that exact certificate* for *that
/// server*. If the server later presents a different certificate, the
/// connection is refused until the user approves the new one.
class TrustedCertificates {
  TrustedCertificates._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _key = 'trusted_certificate_fingerprints';

  /// `host:port` -> SHA-256 fingerprint (lowercase hex). Kept in memory so the
  /// synchronous `badCertificateCallback` can consult it.
  static final Map<String, String> _pins = {};

  static String _id(String host, int port) => '${host.toLowerCase()}:$port';

  static Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _pins
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {
      // Unreadable store: start with no trusted certificates (fail closed).
    }
  }

  static Future<void> _persist() =>
      _storage.write(key: _key, value: jsonEncode(_pins));

  static String fingerprintOf(X509Certificate cert) =>
      sha256.convert(cert.der).toString();

  /// Fingerprint as shown to the user: `AB:CD:...`.
  static String format(String hex) => RegExp(
    r'.{2}',
  ).allMatches(hex.toUpperCase()).map((m) => m.group(0)).join(':');

  /// True only when [cert] is exactly the certificate pinned for host:port.
  static bool isTrusted(X509Certificate cert, String host, int port) {
    final pinned = _pins[_id(host, port)];
    return pinned != null && pinned == fingerprintOf(cert);
  }

  static bool hasPin(String host, int port) =>
      _pins.containsKey(_id(host, port));

  static Future<void> trust(String host, int port, X509Certificate cert) {
    _pins[_id(host, port)] = fingerprintOf(cert);
    return _persist();
  }

  static Future<void> forget(String host, int port) {
    _pins.remove(_id(host, port));
    return _persist();
  }
}

/// Makes every `dart:io` [HttpClient] in the app (including the ones created
/// by `package:http`, `odoo_rpc` and `Image.network`) reject bad certificates
/// unless they are pinned in [TrustedCertificates].
class TrustedCertificateOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) =>
          TrustedCertificates.isTrusted(cert, host, port);
  }
}

/// What a server presented when its certificate was not trusted by the system.
class UntrustedCertificate {
  UntrustedCertificate({
    required this.host,
    required this.port,
    required this.certificate,
    required this.changed,
  });

  final String host;
  final int port;
  final X509Certificate certificate;

  /// True when a different certificate was previously approved for this
  /// server, which can mean the server was reconfigured or that the
  /// connection is being intercepted.
  final bool changed;

  String get fingerprint => TrustedCertificates.format(
    TrustedCertificates.fingerprintOf(certificate),
  );
}

/// Connects to [host]:[port] and reports the certificate when it is not
/// acceptable. Returns null when the server's certificate is valid (system
/// trusted or already pinned) or when the server cannot be reached at all, so
/// that ordinary connection errors are reported by the normal request flow.
Future<UntrustedCertificate?> probeCertificate(String host, int port) async {
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
    );
    await socket.close();
    return null; // Trusted by the system.
  } on HandshakeException {
    // Certificate problem: fetch what the server presented.
  } on TlsException {
    // Same as above.
  } catch (_) {
    return null;
  }

  X509Certificate? presented;
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
      onBadCertificate: (cert) {
        presented = cert;
        return true;
      },
    );
    await socket.close();
  } catch (_) {
    return null;
  }

  final cert = presented;
  if (cert == null) return null;
  if (TrustedCertificates.isTrusted(cert, host, port)) return null;

  return UntrustedCertificate(
    host: host,
    port: port,
    certificate: cert,
    changed: TrustedCertificates.hasPin(host, port),
  );
}
