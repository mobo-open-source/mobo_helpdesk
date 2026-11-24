import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../bloc/login_bloc.dart';

/// A dropdown widget for selecting an available database during login.
///
/// This widget listens to [LoginBloc] state and dynamically displays
/// the list of databases fetched from the server.
///
/// Features:
/// - Displays available databases from the login state
/// - Automatically hides when no databases are available
/// - Integrates with Bloc for state-driven updates
/// - Provides validation to ensure a database is selected
/// - Styled dropdown using `dropdown_button2`
/// - Includes a leading database icon for better UX
///
/// Behavior:
/// - The selected database is validated against the available list
/// - When a user selects a database, a [DatabaseSelected] event is
///   dispatched to the [LoginBloc]
///
/// Example:
/// ```dart
/// DatabaseDropdown()
/// ```
class DatabaseDropdown extends StatelessWidget {
  const DatabaseDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (p, c) =>
          p.databases != c.databases ||
          p.selectedDatabase != c.selectedDatabase,
      builder: (context, state) {
        if (state.databases.isEmpty) return const SizedBox.shrink();

        return DropdownButtonHideUnderline(
          child: DropdownButtonFormField2<String>(
            value: state.databases.contains(state.selectedDatabase)
                ? state.selectedDatabase
                : null,
            isExpanded: true,
            hint: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Database",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: .4),
                ),
              ),
            ),
            items: state.databases
                .map(
                  (db) => DropdownMenuItem(
                    value: db,
                    child: Text(
                      db,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                context.read<LoginBloc>().add(DatabaseSelected(v!)),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Transform.translate(
                  offset: const Offset(7, 0),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedDatabase,
                        size: 20,
                        color: Colors.black54,
                      ),
                      SizedBox(width: 0),
                    ],
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
                maxWidth: 30,
              ),
              contentPadding: const EdgeInsets.fromLTRB(-4, 14, 14, 14),
              isDense: true,
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
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return ('Please select a database');
              }
              return null;
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              offset: const Offset(0, -4),
            ),
            iconStyleData: const IconStyleData(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }
}
