import 'package:flutter/material.dart';

/// A reusable credential input field widget used for authentication forms.
///
/// This widget wraps a [TextFormField] and provides a standardized UI for
/// entering credentials such as username and password.
///
/// Features:
/// - Supports username and password input modes
/// - Optional password visibility toggle
/// - Built-in validation (required field check)
/// - Autofill support for username and password
/// - Custom leading icon support
/// - Styled input decoration consistent with authentication screens
///
/// When [isPasswordField] is true:
/// - The input is obscured by default
/// - A visibility toggle icon is shown in the suffix
/// - Autofill hint is set to [AutofillHints.password]
///
/// When false:
/// - Treated as a username/email field
/// - Autofill hint is set to [AutofillHints.username]
///
/// Example:
/// ```dart
/// CredentialFields(
///   controller: usernameController,
///   label: "Username",
///   icon: Icon(Icons.person),
/// )
/// ```
class CredentialFields extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? icon;
  final bool isPasswordField;
  final bool? isPasswordVisible;
  final VoidCallback? onVisibilityToggle;
  final Function(String)? onChanged;

  const CredentialFields({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.isPasswordField = false,
    this.isPasswordVisible,
    this.onVisibilityToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: TextFormField(
        controller: controller,
        obscureText: isPasswordField ? !(isPasswordVisible ?? false) : false,
        onChanged: onChanged,
        validator: (v) => v?.isEmpty ?? true ? '$label is required' : null,
        autofillHints: isPasswordField
            ? [AutofillHints.password]
            : [AutofillHints.username],
        style: TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withValues(alpha: .4),
          ),
          prefixIcon: icon,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 40,
          ),
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible == true
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: isPasswordVisible == true
                        ? Colors.black26
                        : Colors.black45,
                    size: 20,
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          errorStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
