import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../app/themes/app_colors.dart';

/// The "Saving..." card: a spinner, the [message] and a wait note.
///
/// The one look every blocking write in the app uses; [SavingOverlay] and the
/// profile screen's dialog both draw it.
class SavingCard extends StatelessWidget {
  final String message;

  /// The line under the message; the usual wait note when not given.
  final String? hint;

  const SavingCard({super.key, required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The Mobo Events "Creating Event" dialog: a brand-tinted circle holding
    // the rotating dots, a bold title and a one-line subtitle.
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 60,
            width: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: LoadingAnimationWidget.fourRotatingDots(
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint ?? 'Please wait while we process your request',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Covers [child] with a blocking [SavingCard] while [isSaving].
///
/// Sits over the whole screen it wraps, app bar included, so a create or
/// update cannot be submitted a second time and nothing else can be tapped
/// until the write finishes. [child] stays mounted underneath, keeping what
/// the user typed.
class SavingOverlay extends StatelessWidget {
  final bool isSaving;
  final String message;
  final String? hint;
  final Widget child;

  const SavingOverlay({
    super.key,
    required this.isSaving,
    required this.message,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isSaving) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
              child: Material(
                color: isDark ? Colors.grey[900] : Colors.white,
                elevation: 24,
                borderRadius: BorderRadius.circular(16),
                child: SavingCard(message: message, hint: hint),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// [SavingOverlay] driven by a bloc: shown while [isSaving] is true for the
/// bloc's current state, so a screen needs one widget and no listener.
///
/// ```dart
/// BlocSavingOverlay<TicketBloc, TicketState>(
///   isSaving: (state) => state.isSaving,
///   message: 'Saving Changes',
///   child: Scaffold(...),
/// )
/// ```
class BlocSavingOverlay<B extends StateStreamable<S>, S>
    extends StatelessWidget {
  final bool Function(S state) isSaving;
  final String message;
  final Widget child;

  /// Replace [message] / the wait note while saving, from the state. An empty
  /// or null answer keeps the defaults. A save that installs apps says so, and
  /// says that it takes a while, instead of the plain "Saving".
  final String? Function(S state)? messageOf;
  final String? Function(S state)? hintOf;

  const BlocSavingOverlay({
    super.key,
    required this.isSaving,
    required this.message,
    required this.child,
    this.messageOf,
    this.hintOf,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<B, S, (bool, String?, String?)>(
      selector: (state) =>
          (isSaving(state), messageOf?.call(state), hintOf?.call(state)),
      builder: (context, shown) {
        final (saving, customMessage, customHint) = shown;
        return SavingOverlay(
          isSaving: saving,
          message: (customMessage?.isNotEmpty ?? false)
              ? customMessage!
              : message,
          hint: (customHint?.isNotEmpty ?? false) ? customHint : null,
          child: child,
        );
      },
    );
  }
}
