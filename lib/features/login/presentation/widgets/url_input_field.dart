import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../bloc/login_bloc.dart';
import '../../../../core/security/transport_policy.dart';

/// A URL input field with autocomplete support for server addresses.
///
/// This widget allows users to:
/// - Enter a server URL
/// - Select protocol (HTTP/HTTPS)
/// - View and select from previously used URLs (history/suggestions)
/// - Auto-fill related database if available
///
/// Features:
/// - RawAutocomplete for URL suggestions
/// - Protocol dropdown inside prefix icon
/// - Loading indicator when URL validation is in progress
/// - Integration with [LoginBloc] for state management
///
/// It automatically updates based on [LoginState.url], [protocol],
/// and suggestion/history changes.
class UrlInputField extends StatelessWidget {
  const UrlInputField({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (p, c) =>
          p.protocol != c.protocol ||
          p.url != c.url ||
          p.isLoading != c.isLoading ||
          p.urlSuggestions != c.urlSuggestions ||
          p.urlHistory != c.urlHistory,
      builder: (context, state) {
        return RawAutocomplete<String>(
          optionsBuilder: (value) {
            final input = value.text.trim().toLowerCase();
            if (input.isEmpty) return const Iterable<String>.empty();

            final matches = state.urlSuggestions.where((u) {
              final domain = LoginBloc.extractDomain(u).toLowerCase();
              return domain.contains(input) || u.toLowerCase().contains(input);
            });

            final isExactMatch = state.urlSuggestions.any((u) {
              final domain = LoginBloc.extractDomain(u).toLowerCase();
              return domain == input;
            });

            if (isExactMatch) {
              return const Iterable<String>.empty();
            }

            return matches;
          },

          onSelected: (selection) {
            final bloc = context.read<LoginBloc>();
            bloc.add(UrlChanged(selection));
            final domainKey = LoginBloc.extractDomain(selection);
            final entry =
                state.urlHistory[selection] ?? state.urlHistory[domainKey];
            if (entry != null && entry['db']?.isNotEmpty == true) {
              Future.delayed(const Duration(milliseconds: 900), () {
                if (entry['db'] != null) {
                  bloc.add(DatabaseSelected(entry['db']!));
                }
              });
            }
          },
          fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
            if (ctrl.text != state.url) {
              ctrl.value = TextEditingValue(
                text: state.url,
                selection: TextSelection.collapsed(offset: state.url.length),
              );
            }
            return TextFormField(
              controller: ctrl,
              focusNode: focusNode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return ('Server address is required');
                }
                return null;
              },
              onChanged: (v) => context.read<LoginBloc>().add(UrlChanged(v)),
              style: GoogleFonts.manrope(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Enter Server Address",
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: .4),
                ),
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),

                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedServerStack01,
                      size: 20,
                      color: Colors.black54,
                    ),

                    const SizedBox(width: 10),

                    DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        value: state.protocol,
                        items: [if (allowInsecureHttp) 'http://', 'https://']
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            context.read<LoginBloc>().add(ProtocolChanged(v!)),

                        buttonStyleData: const ButtonStyleData(
                          padding: EdgeInsets.zero,
                          height: 36,
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),

                        iconStyleData: const IconStyleData(
                          icon: SizedBox.shrink(),
                        ),

                        dropdownStyleData: DropdownStyleData(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.black54,
                    ),

                    SizedBox(width: 5),
                    const SizedBox(
                      height: 39,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.black12,
                      ),
                    ),
                    SizedBox(width: 5),
                  ],
                ),
                suffixIcon: state.isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            LoginBloc.extractDomain(option),
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
