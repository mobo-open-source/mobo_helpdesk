import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/input_validators.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/calendar_date_picker.dart';
import '../../../../core/widgets/dialog_button_style.dart';
import '../../../../core/widgets/edit_controller_field.dart';
import '../../../../core/widgets/edit_dropdown_field.dart';
import '../../../../core/widgets/ignore_tag.dart';
import '../../../../core/widgets/saving_overlay.dart';
import '../../../../di/injection_container.dart';
import '../../domain/usecases/ticket_list_usecase.dart';
import '../bloc/ticket_bloc.dart';

class ScheduleActivityDialog extends StatefulWidget {
  final int ticketId;
  final Map<String, dynamic>? activity;
  final bool isEdit;

  const ScheduleActivityDialog({
    super.key,
    required this.ticketId,
    this.activity,
    this.isEdit = false,
  });

  @override
  State<ScheduleActivityDialog> createState() => _ScheduleActivityDialogState();
}

/// The form Odoo 20 opens for "Schedule Activity", field for field: activity
/// type, summary, phone number (calls only), due date, assigned to, role and
/// note.
///
/// Choosing a type fills the rest the way Odoo does - summary, due date,
/// assignee and note come from the type - and a new activity opens with the type
/// Odoo would preselect. Phone and role exist from Odoo 20 only; on older
/// servers they are not shown.
class _ScheduleActivityDialogState extends State<ScheduleActivityDialog> {
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final TicketListUseCase _useCase = sl<TicketListUseCase>();

  DateTime? selectedDate;
  Map<String, dynamic>? selectedType;
  Map<String, dynamic>? selectedUser;
  Map<String, dynamic>? selectedRole;

  /// Roles an activity can go to. Empty where the server has none.
  List<Map<String, dynamic>> roles = [];

  /// Whether the server's activities have a role / a phone number. Both are
  /// hidden until the server says so: older servers have neither.
  bool supportsRole = false;
  bool supportsPhone = false;

  /// True while Odoo is being asked what to prefill, so the form is not saved
  /// from under the answer.
  bool _loadingDefaults = false;
  int _defaultsRequest = 0;

  // What the dialog opened with, so editing can tell whether anything changed.
  String _initialSummary = '';
  String _initialPhone = '';
  String _initialNote = '';
  DateTime? _initialDate;
  String? _initialTypeId;
  String? _initialUserId;
  String? _initialRoleId;

  /// Set when the user picks anything in a dropdown, even the value already
  /// shown: that counts as a change.
  bool _dropdownTouched = false;

  /// Records the form as it is now as the baseline [_hasChanges] compares to.
  void _snapshotInitial() {
    _initialSummary = summaryController.text;
    _initialPhone = phoneController.text;
    _initialNote = descriptionController.text;
    _initialDate = selectedDate;
    _initialTypeId = selectedType?['id']?.toString();
    _initialUserId = selectedUser?['id']?.toString();
    _initialRoleId = selectedRole?['id']?.toString();
  }

  static bool _sameDay(DateTime? a, DateTime? b) => a == null || b == null
      ? a == b
      : a.year == b.year && a.month == b.month && a.day == b.day;

  /// The category of the chosen type; `phonecall` asks for a phone number.
  String? _category;

  bool get _showPhone => supportsPhone && _category == 'phonecall';

  /// Whether any field differs from what the dialog opened with. Compared by
  /// value, so changing a field and changing it back turns Save off again.
  bool get _hasChanges =>
      _dropdownTouched ||
      summaryController.text != _initialSummary ||
      phoneController.text != _initialPhone ||
      descriptionController.text != _initialNote ||
      !_sameDay(selectedDate, _initialDate) ||
      selectedType?['id']?.toString() != _initialTypeId ||
      selectedUser?['id']?.toString() != _initialUserId ||
      selectedRole?['id']?.toString() != _initialRoleId;

  /// Odoo asks for someone to do the activity: a person or, where roles exist,
  /// a role. Which of the two is required depends on the other.
  bool get _hasAssignee =>
      selectedUser != null || (supportsRole && selectedRole != null);

  /// The phone number is checked only when it was changed: Odoo keeps it as
  /// free text, so one it already holds is not held to this app's rules.
  String? _phoneError(String value) =>
      value.trim() == _initialPhone ? null : InputValidators.phone(value);

  /// Activity type and due date are required, and so is an assignee (see
  /// [_hasAssignee]); summary, phone and note are optional. Schedule stays
  /// disabled until they are set. When editing, it also waits for something to
  /// have changed from what the dialog opened with.
  bool get _canSubmit =>
      selectedType != null &&
      selectedDate != null &&
      _hasAssignee &&
      (!_showPhone || _phoneError(phoneController.text) == null) &&
      !_loadingDefaults &&
      (!widget.isEdit || _hasChanges);

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    summaryController.removeListener(_onFieldChanged);
    phoneController.removeListener(_onFieldChanged);
    descriptionController.removeListener(_onFieldChanged);
    summaryController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    selectedDate = DateTime.now();

    if (widget.activity != null) {
      final summary = widget.activity!['summary'];
      summaryController.text = summary is String ? summary : '';

      final phone = widget.activity!['phone'];
      phoneController.text = phone is String ? phone : '';

      descriptionController.text = stripHtmlTags(widget.activity!['note']);

      final date =
          widget.activity!['date_deadline'] ?? widget.activity!['end_date'];
      selectedDate = date is String ? DateTime.tryParse(date) : date;

      final user = widget.activity!['user_id'];
      if (user is List && user.length >= 2) {
        selectedUser = {'id': user[0], 'name': user[1]};
      }

      final role = widget.activity!['role_id'];
      if (role is List && role.length >= 2) {
        selectedRole = {'id': role[0], 'name': role[1]};
      }

      final type = widget.activity!['activity_type_id'];
      if (type is List && type.length >= 2) {
        // The list carries the category the activity was read with; the type
        // as loaded for the form is the fallback.
        final loaded = (context.read<TicketBloc>().state.activityTypes ?? [])
            .where((t) => t['id'] == type[0]);
        selectedType = loaded.isNotEmpty
            ? loaded.first
            : {'id': type[0], 'name': type[1]};
        _category =
            widget.activity!['activity_category']?.toString() ??
            selectedType?['category']?.toString();
      }
    }

    _snapshotInitial();

    // Typing changes neither a dropdown nor the date, so the buttons need to
    // hear about it from the controllers.
    summaryController.addListener(_onFieldChanged);
    phoneController.addListener(_onFieldChanged);
    descriptionController.addListener(_onFieldChanged);

    _loadServerFeatures();
    if (!widget.isEdit) _preselectType();
  }

  /// Finds out whether the server has a role and a phone number on activities,
  /// and loads the roles when it has.
  Future<void> _loadServerFeatures() async {
    // Both are Odoo 20 features: shown only when the server says it has them.
    final hasRole = await OdooFieldResolver.hasField(
      'mail.activity',
      'role_id',
      assumeIfUnknown: false,
    );
    final hasPhone = await OdooFieldResolver.hasField(
      'mail.activity',
      'phone',
      assumeIfUnknown: false,
    );

    var loadedRoles = <Map<String, dynamic>>[];
    if (hasRole) {
      try {
        loadedRoles = await _useCase.loadActivityRoles();
      } catch (_) {
        // The role field still shows, with whatever the activity already has.
      }
    }

    if (!mounted) return;
    setState(() {
      supportsRole = hasRole;
      supportsPhone = hasPhone;
      roles = loadedRoles;
    });
  }

  /// What the form holds now, in the terms Odoo's onchange takes.
  Map<String, dynamic> _currentValues() => {
    'summary': summaryController.text.isEmpty ? false : summaryController.text,
    'date_deadline': selectedDate == null ? false : formatDate(selectedDate!),
    'user_id': selectedUser?['id'] ?? false,
    'role_id': selectedRole?['id'] ?? false,
    'note': descriptionController.text.isEmpty
        ? false
        : descriptionController.text,
    'phone': phoneController.text.isEmpty ? false : phoneController.text,
  };

  /// A new activity opens on the type Odoo would preselect, prefilled. Called
  /// from [initState], so the loading flag is set before the first build rather
  /// than through `setState`.
  Future<void> _preselectType() async {
    final request = ++_defaultsRequest;
    _loadingDefaults = true;

    final defaults = await _useCase.loadActivityDefaults(
      ticketId: widget.ticketId,
      current: _currentValues(),
    );
    if (!mounted || request != _defaultsRequest) return;

    final types = context.read<TicketBloc>().state.activityTypes ?? [];
    final matching = types.where(
      (t) => t['id'] == defaults['activity_type_id'],
    );
    setState(() {
      _loadingDefaults = false;
      if (matching.isEmpty) {
        _snapshotInitial();
        return; // a type this list does not offer
      }
      selectedType = matching.first;
      _category = matching.first['category']?.toString();
      _applyDefaults(defaults);
      // The prefilled form is the starting point, not a change by the user.
      _snapshotInitial();
    });
  }

  /// A type was chosen: Odoo fills in the rest from it.
  Future<void> _onTypeChanged(Map<String, dynamic>? type) async {
    setState(() {
      _dropdownTouched = true;
      selectedType = type;
      _category = type?['category']?.toString();
    });
    if (type == null) return;

    final request = ++_defaultsRequest;
    setState(() => _loadingDefaults = true);
    final defaults = await _useCase.loadActivityDefaults(
      ticketId: widget.ticketId,
      activityTypeId: type['id'] as int,
      current: _currentValues(),
    );
    if (!mounted || request != _defaultsRequest) return;
    setState(() {
      _loadingDefaults = false;
      _applyDefaults(defaults);
    });
  }

  /// Puts what Odoo answered into the form. Only fields in the answer change:
  /// Odoo leaves out those the type does not touch.
  void _applyDefaults(Map<String, dynamic> defaults) {
    if (defaults['summary'] is String) {
      summaryController.text = defaults['summary'] as String;
    }
    final deadline = defaults['date_deadline'];
    if (deadline is String && DateTime.tryParse(deadline) != null) {
      selectedDate = DateTime.parse(deadline);
    }
    if (defaults.containsKey('user_id')) {
      selectedUser = defaults['user_id'] as Map<String, dynamic>?;
    }
    if (supportsRole && defaults.containsKey('role_id')) {
      selectedRole = defaults['role_id'] as Map<String, dynamic>?;
    }
    if (defaults['note'] is String) {
      descriptionController.text = stripHtmlTags(defaults['note']);
    }
    if (supportsPhone && defaults['phone'] is String) {
      phoneController.text = defaults['phone'] as String;
    }
  }

  /// The values to save. Phone only goes with a call; an empty one is left out
  /// of a new activity so Odoo fills it from the ticket's customer.
  Map<String, dynamic> _payload() {
    final phone = phoneController.text.trim();
    return {
      'res_id': widget.ticketId,
      'activity_type_id': selectedType!['id'],
      'summary': summaryController.text,
      'date_deadline': formatDate(selectedDate!),
      'user_id': selectedUser?['id'] ?? false,
      if (supportsRole) 'role_id': selectedRole?['id'] ?? false,
      if (_showPhone && (phone.isNotEmpty || widget.isEdit)) 'phone': phone,
      'note': descriptionController.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<TicketBloc, TicketState>(
      listenWhen: (previous, current) =>
          previous.isScheduleLoading != current.isScheduleLoading ||
          previous.message != current.message,
      listener: (context, state) {
        if (!state.isScheduleLoading && state.message != null) {
          Navigator.pop(context, true);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AlertDialog(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              titlePadding: EdgeInsets.zero,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Schedule Activity',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
                  ),
                ],
              ),

              content: BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  return Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        width: MediaQuery.of(context).size.width * 0.95,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EditDropdownField(
                                fieldName: "Activity Type",
                                items: state.activityTypes ?? [],
                                value: selectedType,
                                isFieldEdit: true,
                                isRequired: true,
                                onChanged: _onTypeChanged,
                              ),
                              const SizedBox(height: 12),

                              EditControllerField(
                                fieldName: "Summary",
                                controller: summaryController,
                                isFieldEdit: true,
                              ),
                              const SizedBox(height: 12),

                              // Only for a call, and only where the server has it.
                              if (_showPhone) ...[
                                EditControllerField(
                                  fieldName: "Phone number",
                                  controller: phoneController,
                                  isFieldEdit: true,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    InputValidators.phoneInputFormatter,
                                  ],
                                  validator: _phoneError,
                                ),
                                const SizedBox(height: 12),
                              ],

                              GestureDetector(
                                onTap: () async {
                                  final picked = await CustomDatePicker.show(
                                    context: context,
                                    isDark: isDark,
                                    initialDate: selectedDate,
                                  );

                                  if (picked != null) {
                                    setState(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        text: 'Due Date',
                                        style: TextStyle(
                                          fontFamily: TextStyle(
                                            fontWeight: FontWeight.w400,
                                          ).fontFamily,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: ' *',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: isDark
                                              ? const Color(0xFF2A2A2A)
                                              : const Color(0xFFF8F9FA),
                                          border: Border.all(
                                            color: Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            selectedDate == null
                                                ? "Select Date"
                                                : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                                            style: selectedDate == null
                                                ? TextStyle(
                                                    color: isDark
                                                        ? Colors.grey[500]
                                                        : Colors.grey[500],
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 14,
                                                    height: 1.0,
                                                    fontWeight: FontWeight.w600,
                                                  )
                                                : TextStyle(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black87,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: FontStyle.normal,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // A person, a role, or both; Odoo wants at least one.
                              // Each is required only while the other is empty, so
                              // one can be cleared once the other is chosen.
                              EditDropdownField(
                                fieldName: "Assigned to",
                                items: state.users ?? [],
                                value: selectedUser,
                                isFieldEdit: true,
                                isRequired:
                                    !supportsRole || selectedRole == null,
                                onChanged: (value) {
                                  setState(() {
                                    _dropdownTouched = true;
                                    selectedUser = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),

                              if (supportsRole) ...[
                                EditDropdownField(
                                  fieldName: "Role",
                                  items: roles,
                                  value: selectedRole,
                                  isFieldEdit: true,
                                  isRequired: selectedUser == null,
                                  onChanged: (value) {
                                    setState(() {
                                      _dropdownTouched = true;
                                      selectedRole = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              EditControllerField(
                                fieldName: "Log a note",
                                controller: descriptionController,
                                isFieldEdit: true,
                                isDescription: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              actions: [
                Row(
                  children: [
                    Expanded(
                      child: DialogButtonStyle.negativeButton(
                        context: context,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        title: 'Cancel',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BlocBuilder<TicketBloc, TicketState>(
                        buildWhen: (previous, current) =>
                            previous.isScheduleLoading !=
                            current.isScheduleLoading,
                        builder: (context, state) {
                          return DialogButtonStyle.successButton(
                            context: context,
                            // Disabled until every required field is set, and while
                            // a save is running so a second tap cannot send it twice.
                            onPressed: _canSubmit && !state.isScheduleLoading
                                ? () {
                                    final bloc = context.read<TicketBloc>();

                                    widget.isEdit
                                        ? bloc.add(
                                            UpdateActivity(
                                              widget.activity!['id'],
                                              _payload(),
                                            ),
                                          )
                                        : bloc.add(
                                            ScheduleActivity(_payload()),
                                          );
                                  }
                                : null,
                            title: widget.isEdit ? "Save" : "Schedule",
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // The popup card shown while the activity is being saved.
          BlocBuilder<TicketBloc, TicketState>(
            buildWhen: (previous, current) =>
                previous.isScheduleLoading != current.isScheduleLoading,
            builder: (context, state) {
              if (!state.isScheduleLoading) return const SizedBox.shrink();
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ModalBarrier(dismissible: false, color: Colors.black38),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 320,
                      ),
                      child: Material(
                        color: isDark ? const Color(0xFF212121) : Colors.white,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: SavingCard(
                          message: widget.isEdit
                              ? 'Saving Activity'
                              : 'Creating Activity',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
