import 'package:flutter/material.dart';

/// A small circular status indicator with an optional tooltip message.
///
/// This widget displays a colored dot (bullet) that visually represents
/// a status. When tapped (or long-pressed depending on platform),
/// it shows a tooltip containing the provided [message].
///
/// Commonly used for:
/// - Ticket status indicators
/// - Online/offline presence
/// - Priority or health signals
///
/// The bullet is rendered as a 10x10 circular dot.
///
/// Parameters:
/// - [color]: The color of the status indicator.
/// - [message]: The tooltip message shown when the bullet is tapped.
class StatusBullet extends StatelessWidget {
  final Color color;
  final String message;

  const StatusBullet({super.key, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
