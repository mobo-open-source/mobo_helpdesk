import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/login_bloc.dart';

/// A reusable widget for displaying authentication-related error messages.
///
/// This widget listens to the [LoginBloc] state and conditionally displays
/// error messages based on the provided [type].
///
/// Supported types:
/// - `url`: Displays URL-related errors (e.g., invalid server, database fetch failure)
/// - `credential`: Displays login credential errors (e.g., wrong username/password)
///
/// If no error is present, the error string is empty, or the error is one the
/// login screens show a dialog for, the widget returns an empty space
/// (`SizedBox.shrink()`).
///
/// Features:
/// - BlocSelector-based optimized rebuilds
/// - Type-based error filtering (URL vs credential errors)
/// - Clean UI with icon + message layout
///
/// Example:
/// ```dart
/// ErrorMessage(type: 'credential')
/// ```
class ErrorMessage extends StatelessWidget {
  /// Errors that the login screens raise a dialog for.
  ///
  /// These are sentinels, not messages: printing them under the fields as well
  /// would put a bare "Access Denied" next to a dialog that already explains
  /// the problem in full.
  static const Set<String> _dialogErrors = {
    'Access Denied',
    'Module Missing',
    'Portal Access',
  };

  final String type;

  const ErrorMessage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginBloc, LoginState, String?>(
      selector: (state) {
        if (type == 'url') return state.urlError;
        if (type == 'credential') return state.credentialError;
        return null;
      },
      builder: (context, error) {
        if (error == null || error.isEmpty || _dialogErrors.contains(error)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 18, left: 2, right: 2),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(error, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}
