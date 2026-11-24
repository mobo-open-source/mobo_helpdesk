/// Formats raw exception or error messages into user-friendly login errors.
///
/// This utility class is used throughout the authentication flow to convert
/// low-level exceptions (network errors, server responses, authentication
/// failures, etc.) into readable messages that can be displayed in the UI.
///
/// It performs keyword-based matching on the error string to identify common
/// failure cases such as:
/// - Two-factor authentication requirements (2FA)
/// - Invalid credentials (username/password issues)
/// - Server configuration or Odoo-related errors
/// - Network and connectivity issues
/// - SSL and certificate problems
/// - Database-related failures
///
/// If no known pattern is matched, a generic network error message is returned.
///
/// Example:
/// ```dart
/// final message = LoginErrorFormatter.formatError(error);
/// ```
class LoginErrorFormatter {
  /// Formats an error raised while reaching a server on the URL screen.
  ///
  /// Half of these failures are simply the wrong scheme: an `https://` address
  /// on a server that only serves plain HTTP fails in the handshake, while an
  /// `http://` address on a server that redirects to HTTPS answers with
  /// something that is not an Odoo response. Those two are named as a protocol
  /// mismatch - the only case that suggests changing the scheme. The rest name
  /// the address that was tried, protocol included, so the message always
  /// refers to the attempt on screen.
  ///
  /// [fullUrl] is the address as tried, e.g. `https://example.odoo.com`.
  static String formatUrlError(dynamic error, String fullUrl) {
    final address = fullUrl.trim();
    final errorStr = error.toString().toLowerCase();

    // Only an HTTPS attempt can fail in the handshake, and plain HTTP is the fix.
    if (errorStr.contains('ssl') ||
        errorStr.contains('certificate') ||
        errorStr.contains('handshake')) {
      return 'Protocol mismatch. Try switching between HTTP and HTTPS.';
    }

    // A web page - or anything that is not JSON - where an Odoo response was
    // expected usually means the request landed on a redirect to the other
    // scheme.
    if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception') ||
        errorStr.contains('unexpected character')) {
      return 'Protocol mismatch. Try switching between HTTP and HTTPS.';
    }

    if (errorStr.contains('connection refused') ||
        errorStr.contains('connection failed') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('socket')) {
      return 'Could not reach $address. Please check the server address.';
    }

    if (errorStr.contains('timeout')) {
      return 'Connection to $address timed out. Please try again.';
    }

    if (errorStr.contains('db list failed')) {
      return 'Database listing is disabled (list_db=false). Cannot fetch '
          'databases automatically.';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access to $address was refused.';
    }

    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503')) {
      return '$address returned a server error. Please try again later.';
    }

    return 'Could not connect to $address. Please check the server address.';
  }

  static String formatError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('null') ||
        errorStr.contains('two factor') ||
        errorStr.contains('2fa')) {
      return '2FA Required';
    } else if (errorStr.contains('accessdenied') ||
        errorStr.contains('wrong login/password') ||
        errorStr.contains('invalid login') ||
        errorStr.contains('{code: 200') && errorStr.contains('accessdenied')) {
      return 'Incorrect username or password. Please check your login credentials.';
    } else if (errorStr.contains('accesserror') ||
        errorStr.contains('access denied') ||
        errorStr.contains('not allowed')) {
      return 'It looks like your account doesn’t have access to this app. Please reach out to your administrator for assistance.';
    } else if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') &&
        errorStr.contains('not found')) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else if (errorStr.contains('connection terminated during handshake')) {
      return 'Secure connection failed. The server may not support HTTPS or has an invalid SSL certificate. Try switching to HTTP or contact your administrator.';
    } else if (errorStr.contains('db list failed')) {
      return 'Database listing is disabled (list_db=false). Cannot fetch databases automatically.';
    } else {
      return 'Network error occurred. Please check your internet connection or server URL';
    }
  }
}
