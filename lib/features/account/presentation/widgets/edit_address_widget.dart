import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/mobo/custom_text_field.dart';
import '../../../../core/widgets/mobo/mobo_button.dart';
import '../../../../core/widgets/mobo/mobo_select_field.dart';
import '../../../../core/widgets/mobo/mobo_theme.dart';
import '../bloc/account_bloc.dart';

/// Edit Address dialog: street, street 2, city, ZIP, and searchable Country /
/// State pickers.
///
/// Save stays disabled until the address differs from what was loaded and the
/// required street is filled in. Country and state are held locally (the state
/// list follows the chosen country), and the whole address is sent as one
/// [UpdateProfile] when saved.
class EditAddressWidget extends StatefulWidget {
  final TextEditingController street1Controller;
  final TextEditingController street2Controller;
  final TextEditingController cityController;
  final TextEditingController zipController;
  final int? initialCountryId;
  final int? initialStateId;

  const EditAddressWidget({
    super.key,
    required this.street1Controller,
    required this.street2Controller,
    required this.cityController,
    required this.zipController,
    this.initialCountryId,
    this.initialStateId,
  });

  @override
  State<EditAddressWidget> createState() => _EditAddressWidgetState();
}

class _EditAddressWidgetState extends State<EditAddressWidget> {
  int? _countryId;
  int? _stateId;
  List<Map<String, dynamic>> _states = [];
  bool _isLoadingStates = false;
  late final Map<String, Object?> _initialAddress;

  Map<String, Object?> _addressValues() => {
    'street': widget.street1Controller.text.trim(),
    'street2': widget.street2Controller.text.trim(),
    'city': widget.cityController.text.trim(),
    'zip': widget.zipController.text.trim(),
    'country': _countryId,
    'state': _stateId,
  };

  bool get _canSave =>
      widget.street1Controller.text.trim().isNotEmpty &&
      !mapEquals(_addressValues(), _initialAddress);

  @override
  void initState() {
    super.initState();
    _countryId = widget.initialCountryId;
    _stateId = widget.initialStateId;
    _initialAddress = _addressValues();
    // Started before the first frame is built on, not from inside a build.
    if (_countryId != null) _loadStates(_countryId!);
  }

  Future<void> _loadStates(int countryId) async {
    setState(() => _isLoadingStates = true);
    try {
      final states = await context.read<AccountBloc>().profileUseCase.loadState(
        countryId,
      );
      if (!mounted || _countryId != countryId) return;
      setState(() => _states = states);
    } catch (_) {
      if (mounted && _countryId == countryId) setState(() => _states = []);
    } finally {
      if (mounted && _countryId == countryId) {
        setState(() => _isLoadingStates = false);
      }
    }
  }

  Widget _label(String text, bool isDark) => Text(
    text,
    style: TextStyle(
      fontFamily: GoogleFonts.manrope(fontWeight: FontWeight.w400).fontFamily,
      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
    ),
  );

  Widget _countryDropdown(List<Map<String, dynamic>> countries, bool isDark) {
    final validIds = countries.map((c) => c['id']).toSet();
    final selected = _countryId != null && validIds.contains(_countryId)
        ? _countryId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Country', isDark),
        const SizedBox(height: 8),
        MoboSingleSelectField<int>(
          selected: selected,
          options: countries
              .map(
                (c) => MoboSelectOption<int>(
                  value: c['id'] as int,
                  label: '${c['name']}',
                ),
              )
              .toList(),
          onChanged: (countryId) {
            setState(() {
              _countryId = countryId;
              _stateId = null;
              _states = [];
            });
            if (countryId != null) _loadStates(countryId);
          },
          searchable: true,
          enabled: countries.isNotEmpty,
          hintText: countries.isEmpty ? 'Loading...' : 'Select country',
          panelTitle: 'Select Country',
        ),
      ],
    );
  }

  Widget _stateDropdown(bool isDark) {
    final enabled = _countryId != null;
    final validIds = _states.map((s) => s['id']).toSet();
    final selected = _stateId != null && validIds.contains(_stateId)
        ? _stateId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('State/Province', isDark),
        const SizedBox(height: 8),
        MoboSingleSelectField<int>(
          selected: selected,
          options: _states
              .map(
                (s) => MoboSelectOption<int>(
                  value: s['id'] as int,
                  label: '${s['name']}',
                ),
              )
              .toList(),
          onChanged: (stateId) => setState(() => _stateId = stateId),
          searchable: true,
          enabled: enabled && !_isLoadingStates,
          hintText: enabled
              ? (_isLoadingStates ? 'Loading...' : 'Select state')
              : 'Select country first',
          panelTitle: 'Select State',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final countries = context.select<AccountBloc, List<Map<String, dynamic>>>(
      (bloc) => bloc.state.countries,
    );

    return AlertDialog(
      backgroundColor: AppTheme.surface(isDark),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Edit Address',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: widget.street1Controller,
                labelText: 'Street Address',
                hintText: 'Enter street address',
                isDark: isDark,
                onChanged: (_) => setState(() {}),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'This field is required'
                    : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: widget.street2Controller,
                labelText: 'Street Address 2',
                hintText: 'Apartment, suite, etc. (optional)',
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: widget.cityController,
                labelText: 'City',
                hintText: 'Enter city',
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: widget.zipController,
                labelText: 'ZIP Code',
                hintText: 'Enter ZIP code',
                isDark: isDark,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _countryDropdown(countries, isDark),
              const SizedBox(height: 16),
              _stateDropdown(isDark),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        MoboButtonRow(
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.pop(context),
          primaryLabel: 'Save',
          onPrimary: !_canSave
              ? null
              : () {
                  context.read<AccountBloc>().add(
                    UpdateProfile(
                      isAddress: true,
                      street1: widget.street1Controller.text.trim(),
                      street2: widget.street2Controller.text.trim(),
                      city: widget.cityController.text.trim(),
                      zip: widget.zipController.text.trim(),
                      countryId: _countryId,
                      stateId: _stateId,
                    ),
                  );
                  Navigator.pop(context);
                },
        ),
      ],
    );
  }
}
