import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/dialog_button_style.dart';
import '../../../../core/widgets/edit_controller_field.dart';
import '../../../../core/widgets/edit_dropdown_field.dart';
import '../bloc/ticket_bloc.dart';

/// Displays a bottom sheet dialog for updating a ticket stage.
///
/// This dialog allows the user to edit:
/// - Stage name
/// - Email template
/// - SMS template
/// - Sequence order
///
/// It uses [TicketBloc] to:
/// - Load available email/SMS templates
/// - Submit stage updates via [UpdateStage] event
///
/// The dialog includes:
/// - Pre-filled values from current stage data
/// - Dropdown selection for templates
/// - Text input for name and sequence
/// - Loading overlay when state is processing
///
/// Parameters:
/// - [context]: Build context used to show the dialog
/// - [stageId]: Unique identifier of the stage being edited
/// - [currentStageName]: Current name displayed in the input field
/// - [defaultEmail]: Pre-selected email template (if any)
/// - [defaultSms]: Pre-selected SMS template (if any)
/// - [defaultSequence]: Current sequence/order value of the stage
void showStageUpdateBottomSheet(
  BuildContext context, {
  required dynamic stageId,
  required String currentStageName,
  dynamic defaultEmail,
  dynamic defaultSms,
  dynamic defaultSequence,
  required List<Map<String, dynamic>> emailTemplates,
  required List<Map<String, dynamic>> smsTemplates,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final TextEditingController nameController = TextEditingController(
    text: currentStageName,
  );
  final TextEditingController sequenceController = TextEditingController(
    text: defaultSequence?.toString() ?? '',
  );

  final Map<String, dynamic>? initialEmail =
      (defaultEmail != null && defaultEmail != false)
      ? {'id': defaultEmail[0], 'name': defaultEmail[1]}
      : null;

  final Map<String, dynamic>? initialSms =
      (defaultSms != null && defaultSms != false)
      ? {'id': defaultSms[0], 'name': defaultSms[1]}
      : null;

  Map<String, dynamic>? selectedEmail = initialEmail;
  Map<String, dynamic>? selectedSms = initialSms;
  bool hasChanges = false;
  void Function(void Function())? _setState;

  // Enabled only when the required Name is filled and something has changed.
  bool _computeChanged() =>
      nameController.text.trim().isNotEmpty &&
      (nameController.text != currentStageName ||
          sequenceController.text != (defaultSequence?.toString() ?? '') ||
          selectedEmail?['id'] != initialEmail?['id'] ||
          selectedSms?['id'] != initialSms?['id']);

  void onTextChanged() {
    final changed = _computeChanged();
    if (changed != hasChanges && _setState != null) {
      _setState!(() => hasChanges = changed);
    }
  }

  nameController.addListener(onTextChanged);
  sequenceController.addListener(onTextChanged);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          _setState = setDialogState;
          return AlertDialog(
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
                      Text(
                        'Edit: $currentStageName',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                      width: MediaQuery.of(context).size.width * 0.95,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EditControllerField(
                              fieldName: "Name",
                              controller: nameController,
                              isFieldEdit: true,
                              isRequired: true,
                            ),
                            const SizedBox(height: 12),
                            EditDropdownField(
                              fieldName: "Email Template",
                              items: emailTemplates,
                              value: selectedEmail,
                              isFieldEdit: true,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedEmail = value;
                                  hasChanges = _computeChanged();
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            EditDropdownField(
                              fieldName: "SMS Template",
                              items: smsTemplates,
                              value: selectedSms,
                              isFieldEdit: true,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedSms = value;
                                  hasChanges = _computeChanged();
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            EditControllerField(
                              fieldName: "Sequence",
                              controller: sequenceController,
                              isFieldEdit: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.isLoading)
                      Positioned.fill(
                        child: Center(
                          child: LoadingAnimationWidget.fourRotatingDots(
                            color: AppColors.primary,
                            size: 50,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            actions: [
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  return Row(
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
                      if (!state.isLoading) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: DialogButtonStyle.successButton(
                            onPressed: hasChanges
                                ? () {
                                    context.read<TicketBloc>().add(
                                      UpdateStage(
                                        stageId: stageId,
                                        newName: nameController.text,
                                        emailTemplate: selectedEmail,
                                        smsTemplate: selectedSms,
                                        sequence: int.tryParse(
                                          sequenceController.text,
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                : null,
                            title: "Save",
                            context: context,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}
