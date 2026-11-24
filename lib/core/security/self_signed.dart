import 'dart:io';
import 'package:http/io_client.dart';

/// Creates and configures a custom [HttpClient] that bypasses SSL certificate validation.
///
/// This is primarily used to support self-signed certificates or corporate/internal
/// Odoo servers that use non-trusted certificates.
///
/// **Warning:** Setting `badCertificateCallback` to always return `true` disables
/// certificate validation, which reduces security. This should only be used in
/// controlled environments (development, internal company servers, etc.).
///
/// In production with public servers, proper certificate validation is strongly recommended.
HttpClient _getHttpClient() {
  final client = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return client;
}

/// Global [IOClient] instance used throughout the app for making HTTP requests.
///
/// This client is configured to accept self-signed certificates (see [_getHttpClient]).
/// It is used in services like [AuthService] for session-based calls and other
/// places where direct HTTP requests are needed alongside the `odoo_rpc` package.
final ioClient = IOClient(_getHttpClient());
