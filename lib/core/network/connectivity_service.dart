import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A singleton service that monitors device network connectivity and server reachability.
///
/// This service provides real-time streams for:
/// - Internet connectivity status (`onInternetChanged`)
/// - Server reachability status (`onServerChanged`)
///
/// It performs periodic checks using `connectivity_plus` and direct DNS lookups
/// via `InternetAddress.lookup()`. The service is designed to be robust across
/// different network conditions (Wi-Fi, mobile data, captive portals, etc.).
///
/// Key Features:
/// - Distinguishes between "no network" and "network but no internet".
/// - Supports monitoring a specific Odoo/backend server URL.
/// - Throws custom exceptions for better error handling in the UI layer.
/// - Uses broadcast streams so multiple parts of the app can listen simultaneously.
///
/// Usage:
/// ```dart
/// // Start monitoring (usually called in main() or after login)
/// ConnectivityService.instance.startMonitoring();
///
/// // Listen to changes
/// ConnectivityService.instance.onInternetChanged.listen((hasInternet) {
///   if (!hasInternet) { /* show offline UI */ }
/// });
///
/// // Set the current server URL (e.g., after user logs in)
/// ConnectivityService.instance.setCurrentServerUrl('https://mycompany.odoo.com');
/// ```
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  final StreamController<bool> _internetController =
      StreamController<bool>.broadcast();

  final StreamController<bool> _serverController =
      StreamController<bool>.broadcast();
  bool _lastInternetReachable = false;
  bool _lastServerReachable = true;
  String? _currentServerUrl;

  Stream<bool> get onInternetChanged => _internetController.stream;

  Stream<bool> get onServerChanged => _serverController.stream;

  /// Starts monitoring network and server connectivity.
  ///
  /// Should be called once during app initialization (typically after setting
  /// the server URL).
  void startMonitoring() {
    _probeInternet();
    _probeServer();
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _probeInternet();
      await _probeServer();
    });
  }

  /// Probes internet connectivity using DNS lookup.
  Future<void> _probeInternet() async {
    final reachable = await hasInternetAccess();
    if (reachable != _lastInternetReachable) {
      _lastInternetReachable = reachable;
      _internetController.add(reachable);
    }
  }

  /// Probes whether the configured server is reachable.
  Future<void> _probeServer() async {
    final url = _currentServerUrl;
    if (url == null) return;

    if (!_lastInternetReachable) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
      return;
    }
    try {
      await ensureServerReachable(url);
      if (_lastServerReachable != true) {
        _lastServerReachable = true;
        _serverController.add(true);
      }
    } catch (_) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
    }
  }

  /// Checks if the device has any active network connection (Wi-Fi, mobile, etc.).
  Future<bool> isNetworkAvailable() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Checks if the device has actual internet access by performing a DNS lookup.
  ///
  /// Uses `example.com` by default. You can override the host for testing.
  Future<bool> hasInternetAccess({String host = 'example.com'}) async {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Ensures the device has both network and internet access.
  ///
  /// Throws [NoInternetException] if either check fails.
  /// Useful before making API calls.
  Future<void> ensureInternetOrThrow() async {
    final net = await isNetworkAvailable();
    if (!net) {
      throw NoInternetException(
        'No network connection. Please check Wi‑Fi or mobile data.',
      );
    }
    final online = await hasInternetAccess();
    if (!online) {
      throw NoInternetException(
        'Connected to a network but no internet access.',
      );
    }
  }

  /// Verifies that the given server URL/host is reachable via DNS lookup.
  ///
  /// Throws [ServerUnreachableException] if the server cannot be reached.
  Future<void> ensureServerReachable(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final host = uri.host.isNotEmpty ? uri.host : serverUrl;
      final res = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      if (res.isEmpty) {
        throw ServerUnreachableException('Unable to reach server host: $host');
      }
    } on Exception {
      throw ServerUnreachableException(
        'Unable to reach server. Please verify the URL and network.',
      );
    }
  }

  /// Sets the current backend server URL and immediately checks its reachability.
  ///
  /// Call this after user login or when the server URL changes.
  void setCurrentServerUrl(String? serverUrl) {
    _currentServerUrl = serverUrl;
    _probeServer();
  }

  bool get lastKnownServerReachable =>
      _currentServerUrl == null ? true : _lastServerReachable;
}

class NoInternetException implements Exception {
  final String message;

  NoInternetException(this.message);

  @override
  String toString() => 'NoInternetException: $message';
}

class ServerUnreachableException implements Exception {
  final String message;

  ServerUnreachableException(this.message);

  @override
  String toString() => 'ServerUnreachableException: $message';
}
