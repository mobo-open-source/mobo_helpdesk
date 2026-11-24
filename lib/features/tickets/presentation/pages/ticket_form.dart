import '../../../../core/widgets/card_heading_divider.dart';
import '../../../../app/themes/app_colors.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/core/widgets/edit_controller_field.dart';
import 'package:mobo_helpdesk/core/widgets/edit_dropdown_field.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/pages/ticket_main_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../core/utils/odoo_colors.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/saving_overlay.dart';
import '../../../../core/widgets/custom_form_tile.dart';
import '../../../../core/widgets/edit_multi_dropdown_field.dart';
import '../../../../core/widgets/empty_lottie.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/full_card_shimmer.dart';
import '../../../../core/widgets/helpdesk_ribbon.dart';
import '../../../../core/widgets/ignore_tag.dart';
import '../../../../core/widgets/mobo/mobo_form_field.dart';
import '../../../../core/widgets/mobo/mobo_theme.dart';
import '../../../../core/widgets/priority_stars_widget.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../core/widgets/star_rating_widget.dart';
import '../../../../core/widgets/tag_chip_widget.dart';
import '../../../../core/widgets/view_buttons_style.dart';
import '../../../../di/injection_container.dart';
import '../bloc/ticket_bloc.dart';
import '../widgets/activity_widget.dart';
import '../widgets/covert_opportunity_dialog_widget.dart';
import '../widgets/deadline_format.dart';

/// A form screen used for creating, viewing, and editing tickets.
///
/// This widget supports three modes:
/// - **Create mode**: Create a new ticket
/// - **View mode**: View ticket details
/// - **Edit mode**: Edit existing ticket
///
/// It integrates with [TicketBloc] for state management and supports:
/// - Field editing (name, phone, email, description, etc.)
/// - Dropdown selections (team, user, partner, type, tags)
/// - Priority rating selection
/// - Unsaved changes detection
/// - Version-based field rendering (legacy support)
/// - Smart view navigation handling
class TicketForm extends StatefulWidget {
  final int? ticketId;
  final bool isCreate;
  final bool? isSmartView;
  final Map<String, dynamic>? defaultStage;

  const TicketForm({
    super.key,
    this.ticketId,
    this.isCreate = false,
    this.isSmartView = false,
    this.defaultStage,
  });

  @override
  State<TicketForm> createState() => _TicketFormState();
}

/// Internal state class for [TicketForm].
///
/// Handles:
/// - Text controllers lifecycle
/// - Edit mode toggle
/// - Change tracking (unsaved changes detection)
/// - Ticket data initialization
/// - Interaction with [TicketBloc]
class _TicketFormState extends State<TicketForm> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailCcController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  Map<String, dynamic> initialData = {};
  bool hasChanges = false;
  String stageName = '';

  int priority = 0;
  bool isEdit = false;

  int version = 0;
  bool isInitialized = false;

  /// Whether the server's tickets have an `Email cc` field. Odoo 20 dropped it,
  /// so the field is only shown, read and saved where it exists.
  bool supportsEmailCc = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadFieldSupport();
    _addChangeListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailCcController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;
    });
  }

  Future<void> _loadFieldSupport() async {
    final supported = await OdooFieldResolver.hasField(
      'helpdesk.ticket',
      'email_cc',
    );
    if (mounted && supported != supportsEmailCc) {
      setState(() {
        supportsEmailCc = supported;
        // The ticket may already be loaded; a value for a field the server does
        // not have must not read as an edit.
        if (!supported) initialData.remove('email_cc');
      });
    }
  }

  void _addChangeListeners() {
    nameController.addListener(_markHasChanges);
    phoneController.addListener(_markHasChanges);
    emailCcController.addListener(_markHasChanges);
    descriptionController.addListener(_markHasChanges);
  }

  void _markHasChanges() {
    // Rebuild on every change so the submit button re-evaluates
    // _checkIfHasChanges() — enabling when something differs and
    // disabling again when the field is reverted to its initial value.
    if (mounted) {
      setState(() => hasChanges = _checkIfHasChanges());
    }
  }

  bool _checkIfHasChanges() {
    if (!isEdit && !widget.isCreate) return false;

    final currentData = {
      'name': nameController.text.trim(),
      'partner_phone': phoneController.text.trim(),
      if (supportsEmailCc) 'email_cc': emailCcController.text.trim(),
      'description': descriptionController.text.trim(),
      'priority': priority,
      'team_id': context.read<TicketBloc>().state.selectedTeam?['id'],
      'user_id': context.read<TicketBloc>().state.selectedUser?['id'],
      'stage_id': context.read<TicketBloc>().state.selectedStage?['id'],
      if (version <= 17)
        'ticket_type_id': context.read<TicketBloc>().state.selectedType?['id'],
      'partner_id': context.read<TicketBloc>().state.selectedPartner?['id'],
      'tag_ids': (context.read<TicketBloc>().state.selectedTags ?? [])
          .map((e) => e['id'])
          .toList(),
    };

    if (widget.isCreate) {
      return currentData.values.any((value) {
        if (value is String) return value.isNotEmpty;
        if (value is List) return value.isNotEmpty;
        return value != null && value != 0;
      });
    }

    return initialData.toString() != currentData.toString();
  }

  /// Runs [check] on [value] unless it is the value the ticket already had.
  ///
  /// Odoo stores these fields as free text, so a ticket can carry a value this
  /// app would reject; leaving it alone must not block saving other changes.
  /// Only what the user types is held to the rules.
  String? _validated(String key, String value, String? Function(String) check) {
    if (isEdit && value.trim() == initialData[key]) return null;
    return check(value);
  }

  String? _phoneError(String value) =>
      _validated('partner_phone', value, InputValidators.phone);

  String? _emailCcError(String value) => supportsEmailCc
      ? _validated('email_cc', value, InputValidators.emailList)
      : null;

  bool _isSubmitEnabled() {
    if (!widget.isCreate && !isEdit) return false;

    // Name and Helpdesk Team are required in both create and edit mode.
    final team = context.read<TicketBloc>().state.selectedTeam;
    final requiredFilled =
        nameController.text.trim().isNotEmpty && team?['id'] != null;
    if (!requiredFilled) return false;

    // A phone or email that fails its check is shown in red under the field;
    // the ticket is not saved until it is fixed or cleared.
    if (_phoneError(phoneController.text) != null ||
        _emailCcError(emailCcController.text) != null) {
      return false;
    }

    return widget.isCreate || _checkIfHasChanges();
  }

  void _saveInitialData(TicketState state, Map<String, dynamic>? ticket) {
    if (ticket == null) return;

    initialData = {
      'name': safeUpdateText(ticket['name']).trim(),
      'partner_phone': safeUpdateText(ticket['partner_phone']).trim(),
      if (supportsEmailCc)
        'email_cc': safeUpdateText(ticket['email_cc']).trim(),
      'description': stripHtmlTags(ticket['description'] ?? '').trim(),
      'priority': int.tryParse(ticket['priority']?.toString() ?? '0') ?? 0,
      'team_id': state.selectedTeam?['id'],
      'user_id': state.selectedUser?['id'],
      'stage_id': state.selectedStage?['id'],
      if (version <= 17) 'ticket_type_id': state.selectedType?['id'],
      'partner_id': state.selectedPartner?['id'],
      'tag_ids': (state.selectedTags ?? []).map((e) => e['id']).toList(),
    };

    hasChanges = false;
  }

  /// The form, under an overlay that holds the screen while a create or update
  /// is being saved: the button cannot be pressed twice and nothing else can be
  /// tapped until the result is in.
  @override
  Widget build(BuildContext context) {
    return BlocSavingOverlay<TicketBloc, TicketState>(
      isSaving: (state) => state.isSaving,
      message: widget.isCreate ? 'Creating Ticket' : 'Saving Changes',
      hintOf: (_) => widget.isCreate
          ? 'Please wait while we create the ticket'
          : 'Please wait while we save the ticket',
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Leaving mid-save would drop its result, so back waits for it.
        if (didPop || context.read<TicketBloc>().state.isSaving) return;
        if ((isEdit || widget.isCreate) && _checkIfHasChanges()) {
          final shouldDiscard = await ConfirmationDialogWidget.show(
            context: context,
            title: 'Discard Changes?',
            subTitle: 'You have unsaved changes. Do you want to discard them?',
            negativeButtonText: 'Keep Editing',
            positiveButtonText: 'Discard',
          );
          if (shouldDiscard != true) return;
        }
        if (!context.mounted) return;

        if (widget.isCreate) {
          Navigator.pop(context);
        } else if (isEdit) {
          setState(() {
            isEdit = false;
            hasChanges = false;
          });
        } else {
          widget.isSmartView!
              ? Navigator.pop(context)
              : Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: widget.isCreate
              ? 'Create Ticket'
              : (isEdit ? "Edit Ticket" : "Ticket Details"),
          isDark: isDark,

          onBack: () async {
            if ((isEdit || widget.isCreate) && _checkIfHasChanges()) {
              final shouldDiscard = await ConfirmationDialogWidget.show(
                context: context,
                title: 'Discard Changes?',
                subTitle:
                    'You have unsaved changes. Do you want to discard them?',
                negativeButtonText: 'Keep Editing',
                positiveButtonText: 'Discard',
              );
              if (shouldDiscard != true) return;
            }
            if (!context.mounted) return;

            if (widget.isCreate) {
              Navigator.pop(context);
            } else if (isEdit) {
              setState(() {
                isEdit = false;
                hasChanges = false;
              });
            } else {
              widget.isSmartView!
                  ? Navigator.pop(context)
                  : Navigator.pop(context, true);
            }
          },
          actions: [
            !isEdit && !widget.isCreate
                ? BlocBuilder<TicketBloc, TicketState>(
                    builder: (context, state) {
                      if (state.isLoading || state.error != null) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        children: [
                          IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedPencilEdit02,
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[800]!,
                            ),
                            onPressed: () {
                              final state = context.read<TicketBloc>().state;
                              _saveInitialData(state, state.selectedTicket);

                              setState(() {
                                isEdit = true;
                                priority =
                                    int.tryParse(
                                      state.selectedTicket?['priority']
                                              ?.toString() ??
                                          '',
                                    ) ??
                                    0;

                                nameController.text = safeUpdateText(
                                  state.selectedTicket?['name'],
                                );
                                phoneController.text = safeUpdateText(
                                  state.selectedTicket?['partner_phone'],
                                );
                                emailCcController.text = safeUpdateText(
                                  state.selectedTicket?['email_cc'],
                                );
                                descriptionController.text = stripHtmlTags(
                                  state.selectedTicket?['description'] ?? '',
                                );
                              });
                            },
                          ),
                          BlocBuilder<TicketBloc, TicketState>(
                            builder: (context, state) {
                              final isCrm =
                                  state.selectedTicket?['is_crm'] ?? false;
                              return PopupMenuButton<String>(
                                position: PopupMenuPosition.under,
                                icon: Icon(
                                  Icons.more_vert,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                                color: isDark ? Colors.grey[900] : Colors.white,
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                itemBuilder: (context) {
                                  return [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedDelete02,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Delete",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value:
                                          state.selectedTicket!['active'] ==
                                              false
                                          ? 'unarchive'
                                          : 'archive',
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon:
                                                state.selectedTicket!['active'] ==
                                                    false
                                                ? HugeIcons
                                                      .strokeRoundedRestoreBin
                                                : HugeIcons
                                                      .strokeRoundedArchive,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            state.selectedTicket!['active'] ==
                                                    false
                                                ? 'Unarchive'
                                                : 'Archive',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCrm)
                                      PopupMenuItem(
                                        value: 'covert_opportunity',
                                        child: Row(
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedExchange01,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Convert to Opportunity",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ];
                                },
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'covert_opportunity':
                                      final bloc = context.read<TicketBloc>();
                                      await showDialog(
                                        context: context,
                                        builder: (dialogContext) {
                                          return BlocProvider.value(
                                            value: bloc,
                                            child:
                                                CovertOpportunityDialogWidget(
                                                  context: dialogContext,
                                                  ticketId: widget.ticketId!,
                                                  onSuccess: () {
                                                    if (!context.mounted)
                                                      return;

                                                    if (widget.isSmartView ==
                                                        true) {
                                                      Navigator.pop(context);
                                                    } else {
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      );
                                                    }
                                                  },
                                                ),
                                          );
                                        },
                                      );
                                      break;
                                    case 'delete':
                                      final confirm =
                                          await ConfirmationDialogWidget.show(
                                            context: context,
                                            title: 'Delete ticket',
                                            subTitle:
                                                'Are you sure you want to delete this ticket?',
                                            negativeButtonText: 'Cancel',
                                            positiveButtonText: 'Delete',
                                          );
                                      if (!context.mounted) return;
                                      if (confirm == true) {
                                        context.read<TicketBloc>().add(
                                          DeleteTicket(widget.ticketId!),
                                        );
                                      }
                                      break;
                                    case 'archive':
                                      final confirm =
                                          await ConfirmationDialogWidget.show(
                                            context: context,
                                            title: 'Archive ticket',
                                            subTitle:
                                                'Are you sure you want to archive this ticket?',
                                            negativeButtonText: 'Cancel',
                                            positiveButtonText: 'Archive',
                                          );
                                      if (!context.mounted) return;
                                      if (confirm == true) {
                                        context.read<TicketBloc>().add(
                                          ArchiveTicket(widget.ticketId!),
                                        );
                                      }
                                      break;
                                    case 'unarchive':
                                      final confirm =
                                          await ConfirmationDialogWidget.show(
                                            context: context,
                                            title: 'Unarchive Ticket',
                                            subTitle:
                                                'Are you sure you want to unarchive this ticket?',
                                            negativeButtonText: 'Cancel',
                                            positiveButtonText: 'Unarchive',
                                          );
                                      if (!context.mounted) return;
                                      if (confirm == true) {
                                        context.read<TicketBloc>().add(
                                          UnArchiveTicket(widget.ticketId!),
                                        );
                                      }
                                      break;
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  )
                : SizedBox.shrink(),
          ],
        ),
        body: BlocListener<TicketBloc, TicketState>(
          listenWhen: (prev, curr) =>
              curr.message != null && curr.message != prev.message,
          listener: (context, state) {
            if (state.message != null) {
              if (!state.isError) {
                CustomSnackBar.showSuccess(context, state.message!);
                if (state.message!.toLowerCase().contains('delete') ||
                    state.message!.toLowerCase().contains('deleted')) {
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (!context.mounted) return;

                    if (widget.isSmartView == true) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context, true);
                    }
                  });
                  return;
                }
                if (state.message!.toLowerCase().contains("opportunity") ||
                    state.message!.toLowerCase().contains("converted")) {
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (!context.mounted) return;

                    if (widget.isSmartView == true) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context, true);
                    }
                  });
                }
                Future.delayed(const Duration(seconds: 3), () {
                  if (!context.mounted) return;
                  checkRating(context);
                });
                if (widget.isCreate) {
                  Navigator.pop(context, true);
                } else {
                  setState(() {
                    isEdit = false;
                  });
                  context.read<TicketBloc>().add(
                    LoadSingleTicket(widget.ticketId!),
                  );
                }
              } else {
                CustomSnackBar.showError(context, state.message!);
              }
              context.read<TicketBloc>().add(ClearTicketMessage());
            }
          },
          child: BlocBuilder<TicketBloc, TicketState>(
            builder: (context, state) {
              final ticket = state.selectedTicket;

              if (!widget.isCreate && state.error != null) {
                final error = state.error!;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: ErrorLottie(
                        title: error['title'] ?? 'Error',
                        subTitle:
                            error['description'] ?? 'Something went wrong.',
                        onPressed: () async {
                          if (widget.ticketId != null) {
                            context.read<TicketBloc>().add(
                              LoadSingleTicket(widget.ticketId!),
                            );
                          }
                          AppBootstrapper.reloadAppBlocs(context);
                          await context.read<CompanyProvider>().initialize();
                        },
                      ),
                    ),
                  ],
                );
              }
              // Opening an existing ticket waits on the ticket; opening a new
              // one waits on the teams, users, partners... its dropdowns offer.
              // Either way the form's skeleton stands in, rather than a form
              // with empty dropdowns that fill in a moment later.
              if (widget.isCreate
                  ? state.isCreateDataLoading
                  : state.isLoading) {
                return const DetailCardsShimmer();
              }

              if (!widget.isCreate && ticket == null) {
                return EmptyLottie(title: "No ticket found");
              }
              if (isEdit && !isInitialized && ticket != null) {
                priority =
                    int.tryParse(ticket['priority']?.toString() ?? '') ?? 0;
                nameController.text = safeUpdateText(ticket['name']);
                phoneController.text = safeUpdateText(ticket['partner_phone']);
                emailCcController.text = safeUpdateText(ticket['email_cc']);
                descriptionController.text = stripHtmlTags(
                  ticket['description'],
                );
                isInitialized = true;
              }
              if (ticket != null) {
                final stage = ticket['stage_id'];
                stageName = (stage is List && stage.length > 1) ? stage[1] : '';
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      // Reloading would discard unsaved edits, and a new record has nothing to reload.
                      if (isEdit || widget.isCreate || widget.ticketId == null)
                        return;
                      final bloc = context.read<TicketBloc>();
                      bloc.add(LoadSingleTicket(widget.ticketId!));
                      await bloc.stream
                          .firstWhere((s) => !s.isLoading)
                          .timeout(
                            const Duration(seconds: 30),
                            onTimeout: () => bloc.state,
                          );
                    },
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          // Room for the floating Update/Create bar only while it shows.
                          bottom: (isEdit || widget.isCreate) ? 100 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomFormTile.tileStyle(
                              bottomMargin: 12,
                              isDark: isDark,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  (isEdit || widget.isCreate) ? 24 : 18,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          EditControllerField(
                                            fieldName: 'Name',
                                            controller: nameController,
                                            isFieldEdit: true,
                                            isRequired: true,
                                            onChanged: (_) {
                                              setState(() {});
                                            },
                                          ),
                                          SizedBox(height: 20),
                                          EditDropdownField(
                                            fieldName: "Helpdesk Team",
                                            items: state.helpdeskTeam ?? [],
                                            value: state.selectedTeam,
                                            isFieldEdit: true,
                                            isRequired: true,
                                            onChanged: (value) {
                                              context.read<TicketBloc>().add(
                                                UpdateSelectedTeam(value),
                                              );
                                              _markHasChanges();
                                            },
                                          ),
                                          SizedBox(height: 20),
                                          EditDropdownField(
                                            fieldName: "Assigned to",
                                            items: state.users ?? [],
                                            value: state.selectedUser,
                                            isFieldEdit: true,
                                            onChanged: (value) {
                                              context.read<TicketBloc>().add(
                                                UpdateSelectedUser(value),
                                              );
                                              _markHasChanges();
                                            },
                                          ),
                                          SizedBox(height: 20),

                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Label, same as the other fields
                                              const MoboFieldLabel('Status'),

                                              // Dropdown
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: AppTheme.inputFill(
                                                    isDark,
                                                  ),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton2<int>(
                                                    value: state
                                                        .selectedStage?['id'],
                                                    isExpanded: true,
                                                    customButton: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          // Chip-style selected value
                                                          Expanded(
                                                            child: Align(
                                                              alignment: Alignment
                                                                  .centerLeft,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF3A3A3A,
                                                                        )
                                                                      : getTicketStatusColor(
                                                                          state.selectedStage?['name'] ??
                                                                              widget.defaultStage?['name'] ??
                                                                              '',
                                                                        ).withAlpha(
                                                                          40,
                                                                        ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        20,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  state.selectedStage?['name'] ??
                                                                      (widget.defaultStage?['name'] ??
                                                                          "Select Stage"),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    color:
                                                                        isDark
                                                                        ? Colors
                                                                              .white
                                                                        : getTicketStatusColor(
                                                                            state.selectedStage?['name'] ??
                                                                                widget.defaultStage?['name'] ??
                                                                                '',
                                                                          ),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),

                                                          Icon(
                                                            HugeIcons
                                                                .strokeRoundedArrowDown01,
                                                            size: 22,
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors
                                                                      .grey[700],
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    onChanged: (id) {
                                                      if (id != null) {
                                                        final selected = state
                                                            .stages
                                                            ?.firstWhere(
                                                              (e) =>
                                                                  e['id'] == id,
                                                            );
                                                        context
                                                            .read<TicketBloc>()
                                                            .add(
                                                              UpdateSelectedStage(
                                                                selected,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      }
                                                    },

                                                    dropdownStyleData:
                                                        DropdownStyleData(
                                                          maxHeight: 250,
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[900]
                                                                : Colors.white,
                                                          ),
                                                          elevation: 8,
                                                          offset: const Offset(
                                                            0,
                                                            -4,
                                                          ),
                                                        ),

                                                    menuItemStyleData:
                                                        const MenuItemStyleData(
                                                          height: 48,
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                              ),
                                                        ),

                                                    items: (state.stages ?? []).map((
                                                      stage,
                                                    ) {
                                                      return DropdownMenuItem<
                                                        int
                                                      >(
                                                        value: stage['id'],
                                                        child: Text(
                                                          stage['name'] ?? '',
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors
                                                                      .black87,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (ticket!.isNotEmpty) ...[
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        (ticket['name'] !=
                                                                    null &&
                                                                ticket['name']
                                                                    .toString()
                                                                    .isNotEmpty)
                                                            ? ticket['name']
                                                            : 'N/A',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF1A1A1A,
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (stageName.isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isDark
                                                              ? getTicketStatusColor(
                                                                  stageName,
                                                                ).withValues(
                                                                  alpha: 0.6,
                                                                )
                                                              : getTicketStatusColor(
                                                                  stageName,
                                                                ).withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          stageName,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isDark
                                                                ? Colors.white
                                                                : getTicketStatusColor(
                                                                    stageName,
                                                                  ),
                                                            letterSpacing: 0.1,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (ticket['sla_status_ids'] !=
                                                        null &&
                                                    ticket['sla_status_ids']
                                                        is List &&
                                                    ticket['sla_status_ids']
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children:
                                                        (ticket['sla_statuses']
                                                                as List<
                                                                  Map<
                                                                    String,
                                                                    dynamic
                                                                  >
                                                                >)
                                                            .map((tag) {
                                                              final name =
                                                                  tag['name'] ??
                                                                  tag['display_name'] ??
                                                                  '';
                                                              final colorIndex =
                                                                  tag['color'] ??
                                                                  0;
                                                              final hasColor =
                                                                  tag.containsKey(
                                                                    'color',
                                                                  ) &&
                                                                  tag['color'] !=
                                                                      false;
                                                              final color =
                                                                  hasColor
                                                                  ? odooColor(
                                                                      colorIndex,
                                                                    )
                                                                  : getTicketStatusColor(
                                                                      name,
                                                                    );

                                                              return Text(
                                                                name,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: isDark
                                                                      ? color.withValues(
                                                                          alpha:
                                                                              0.9,
                                                                        )
                                                                      : color,
                                                                ),
                                                              );
                                                            })
                                                            .toList(),
                                                  ),
                                                ],
                                                if (ticket['sla_deadline']
                                                        is String &&
                                                    ticket['sla_deadline']
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      HugeIcon(
                                                        icon: HugeIcons
                                                            .strokeRoundedTime02,
                                                        color: isDark
                                                            ? Colors.grey[400]!
                                                            : DateTime.tryParse(
                                                                    ticket['sla_deadline'],
                                                                  )?.isBefore(
                                                                    DateTime.now(),
                                                                  ) ==
                                                                  true
                                                            ? (isDark
                                                                  ? Colors
                                                                        .white70
                                                                  : Colors.red)
                                                            : (isDark
                                                                  ? Colors
                                                                        .white70
                                                                  : Colors
                                                                        .green),
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        formatDeadline(
                                                          ticket['sla_deadline'],
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              DateTime.tryParse(
                                                                    ticket['sla_deadline'],
                                                                  )?.isBefore(
                                                                    DateTime.now(),
                                                                  ) ==
                                                                  true
                                                              ? (isDark
                                                                    ? Colors
                                                                          .white70
                                                                    : Colors
                                                                          .red)
                                                              : (isDark
                                                                    ? Colors
                                                                          .white70
                                                                    : Colors
                                                                          .green),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Helpdesk Team",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  (ticket['team_id'] is List &&
                                                          ticket['team_id']
                                                                  .length >
                                                              1)
                                                      ? ticket['team_id'][1]
                                                      : null,
                                                ),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Assigned to",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  (ticket['user_id'] is List &&
                                                          ticket['user_id']
                                                                  .length >
                                                              1)
                                                      ? ticket['user_id'][1]
                                                      : null,
                                                ),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Number of tickets",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value:
                                                    (ticket['partner_ticket_count'] ??
                                                            0)
                                                        .toString(),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Number of open tickets",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value:
                                                    (ticket['partner_open_ticket_count'] ??
                                                            0)
                                                        .toString(),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: ViewButtonsStyle.addViewButtonStyle(
                                                  context: context,
                                                  onPressed: () {
                                                    final partnerTicketIds =
                                                        (ticket['partner_ticket_ids']
                                                            is List)
                                                        ? List<dynamic>.from(
                                                            ticket['partner_ticket_ids'],
                                                          )
                                                        : <dynamic>[];
                                                    List<dynamic> domain = [
                                                      [
                                                        'id',
                                                        '!=',
                                                        ticket['id'],
                                                      ],
                                                      [
                                                        'id',
                                                        'in',
                                                        partnerTicketIds,
                                                      ],
                                                    ];
                                                    final defaultFilters = [
                                                      'open_stage',
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => BlocProvider(
                                                          create: (context) =>
                                                              sl<TicketBloc>()..add(
                                                                TicketsLoad(
                                                                  1,
                                                                  customDomain:
                                                                      domain,
                                                                  filters:
                                                                      defaultFilters,
                                                                  groupBy: null,
                                                                  dateUnit:
                                                                      null,
                                                                  selectedDates:
                                                                      null,
                                                                ),
                                                              ),
                                                          child: TicketMainView(
                                                            isSmartView: true,
                                                            customDomain:
                                                                domain,
                                                            bloc: null,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  title: "View Tickets",
                                                  icon: HugeIcons
                                                      .strokeRoundedBookOpen02,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Optical balance: buttons have no font leading, unlike the heading above.
                                          const SizedBox(height: 7),
                                        ],
                                      ),
                              ),
                            ),
                            CustomFormTile.tileStyle(
                              bottomMargin: 12,
                              isDark: isDark,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  (isEdit || widget.isCreate) ? 24 : 18,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18.0,
                                            ),
                                            child: Text(
                                              'Information',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          CardHeadingDivider(isDark: isDark),
                                          SizedBox(height: 20),
                                          Text(
                                            'Priority',
                                            style: TextStyle(
                                              fontFamily: TextStyle(
                                                fontWeight: FontWeight.w400,
                                              ).fontFamily,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xff7F7F7F),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          StarRating(
                                            rating: priority,
                                            maxRating: 3,
                                            unfilledColor: Colors.amber,
                                            onRatingChanged: (value) {
                                              setState(() {
                                                priority = value;
                                                _markHasChanges();
                                              });
                                            },
                                          ),
                                          SizedBox(height: 20),
                                          if (version <= 17) ...[
                                            EditDropdownField(
                                              fieldName: "Type",
                                              items: state.types ?? [],
                                              value: state.selectedType,
                                              isFieldEdit: true,
                                              onChanged: (value) {
                                                context.read<TicketBloc>().add(
                                                  UpdateSelectedType(value),
                                                );
                                                _markHasChanges();
                                              },
                                            ),
                                            SizedBox(height: 20),
                                          ],
                                          EditDropdownField(
                                            fieldName: "Partner",
                                            items: state.partners ?? [],
                                            value: state.selectedPartner,
                                            isFieldEdit: true,
                                            onChanged: (value) {
                                              context.read<TicketBloc>().add(
                                                UpdateSelectedPartner(value),
                                              );
                                              _markHasChanges();
                                            },
                                          ),
                                          SizedBox(height: 20),
                                          EditControllerField(
                                            fieldName: 'Partner Phone',
                                            controller: phoneController,
                                            isFieldEdit: true,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              InputValidators
                                                  .phoneInputFormatter,
                                            ],
                                            validator: _phoneError,
                                            onChanged: (_) {
                                              setState(() {});
                                            },
                                          ),
                                          SizedBox(height: 20),
                                          if (supportsEmailCc) ...[
                                            EditControllerField(
                                              fieldName: 'Email cc',
                                              controller: emailCcController,
                                              isFieldEdit: true,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              validator: _emailCcError,
                                              onChanged: (_) {
                                                setState(() {});
                                              },
                                            ),
                                            SizedBox(height: 20),
                                          ],
                                          EditMultiDropdownField(
                                            fieldName: "Tags",
                                            items: state.tags ?? [],
                                            selectedItems:
                                                state.selectedTags ?? [],
                                            isFieldEdit: true,
                                            onChanged: (values) {
                                              context.read<TicketBloc>().add(
                                                UpdateTags(values),
                                              );
                                              _markHasChanges();
                                            },
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18.0,
                                            ),
                                            child: Text(
                                              'Information',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Priority",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),
                                              PriorityStarsWidget(
                                                priority: ticket!['priority'],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          if (version <= 17) ...[
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                CustomFormTile.tileTitleText(
                                                  title: "Type",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(height: 10),
                                                CustomFormTile.tileValueText(
                                                  value: safeViewText(
                                                    (ticket['ticket_type_id']
                                                                is List &&
                                                            ticket['ticket_type_id']
                                                                    .length >
                                                                1)
                                                        ? ticket['ticket_type_id'][1]
                                                        : null,
                                                  ),
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                          ],
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Partner",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),
                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  (ticket['partner_id']
                                                              is List &&
                                                          ticket['partner_id']
                                                                  .length >
                                                              1)
                                                      ? ticket['partner_id'][1]
                                                      : null,
                                                ),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Phone",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  ticket['partner_phone'],
                                                ),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          if (supportsEmailCc) ...[
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CustomFormTile.tileTitleText(
                                                  title: "Email cc",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(width: 10),
                                                CustomFormTile.tileValueText(
                                                  value: safeViewText(
                                                    ticket['email_cc'],
                                                  ),
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                          ],
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Tags",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              ticket['tags'].isEmpty
                                                  ? buildChips(
                                                      ticket['tags'],
                                                      isDark,
                                                    )
                                                  : Expanded(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildChips(
                                                          ticket['tags'],
                                                          isDark,
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            CustomFormTile.tileStyle(
                              bottomMargin: 12,
                              isDark: isDark,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  (isEdit || widget.isCreate) ? 24 : 20,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18.0,
                                            ),
                                            child: Text(
                                              'Description',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          EditControllerField(
                                            fieldName: 'Description',
                                            controller: descriptionController,
                                            isFieldEdit: true,
                                            isDescription: true,
                                            onChanged: (_) {
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18.0,
                                            ),
                                            child: Text(
                                              'Description',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          Text(
                                            stripHtmlTags(
                                              ticket!['description'],
                                            ),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            if (!isEdit &&
                                !widget.isCreate &&
                                ticket != null) ...[
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    // The empty message is a lone line of text; give it the bottom gap its heading has above.
                                    ((ticket['activities'] as List?)?.isEmpty ??
                                            true)
                                        ? 23
                                        : 18,
                                  ),
                                  child: TicketActivitiesCard(
                                    ticketId: widget.ticketId!,
                                    rawActivities:
                                        (ticket['activities'] as List?) ??
                                        const [],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isEdit || widget.isCreate) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          16 + MediaQuery.of(context).padding.bottom,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: ViewButtonsStyle.createUpdateButtonStyle(
                          context: context,
                          onPressed: _isSubmitEnabled()
                              ? () {
                                  if (state.selectedTeam == null ||
                                      state.selectedTeam?['id'] == null) {
                                    CustomSnackBar.showError(
                                      context,
                                      "Please select a helpdesk team",
                                    );
                                    return;
                                  }
                                  final bloc = context.read<TicketBloc>();

                                  final data = {
                                    'name': nameController.text,
                                    'partner_phone': phoneController.text
                                        .trim(),
                                    if (supportsEmailCc)
                                      'email_cc': emailCcController.text.trim(),
                                    'description': descriptionController.text,
                                    'priority': priority.toString(),

                                    'team_id': state.selectedTeam?['id'],
                                    'user_id': state.selectedUser?['id'],
                                    if (version <= 17 &&
                                        state.selectedType != null)
                                      'ticket_type_id':
                                          state.selectedType?['id'],
                                    'partner_id': state.selectedPartner?['id'],
                                    'stage_id': state.selectedStage?['id'],

                                    'tag_ids': (state.selectedTags ?? [])
                                        .map((e) => e['id'])
                                        .toList(),
                                  };

                                  if (isEdit) {
                                    bloc.add(
                                      UpdateTicket(widget.ticketId!, data),
                                    );
                                  } else {
                                    bloc.add(CreateTicket(data));
                                  }
                                }
                              : null,
                          title: isEdit ? "Update Ticket" : "Create Ticket",
                          icon: isEdit
                              ? HugeIcons.strokeRoundedTaskEdit01
                              : HugeIcons.strokeRoundedNoteAdd,
                        ),
                      ),
                    ),
                  ],
                  if (!widget.isCreate && ticket!['active'] == false)
                    HelpdeskRibbon(text: "Archived", color: Colors.red),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
