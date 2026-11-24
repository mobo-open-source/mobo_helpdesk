import 'package:flutter/material.dart';

class HelpdeskRibbon extends StatelessWidget {
  final String text;
  final Color color;

  const HelpdeskRibbon({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      right: -40,
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 200,
          height: 30,
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: color,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
