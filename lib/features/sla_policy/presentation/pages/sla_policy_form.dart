import '../../../../core/widgets/card_heading_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/core/widgets/edit_controller_field.dart';
import 'package:mobo_helpdesk/core/widgets/edit_dropdown_field.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/saving_overlay.dart';
import '../../../../core/widgets/custom_form_tile.dart';
import '../../../../core/widgets/edit_multi_dropdown_field.dart';
import '../../../../core/widgets/empty_lottie.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/form_view_shimmer.dart';
import '../../../../core/widgets/helpdesk_ribbon.dart';
import '../../../../core/widgets/ignore_tag.dart';
import '../../../../core/widgets/priority_stars_widget.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../core/widgets/star_rating_widget.dart';
import '../../../../core/widgets/tag_chip_widget.dart';
import '../../../../core/widgets/view_buttons_style.dart';
import '../../../../di/injection_container.dart';
import '../../../tickets/presentation/bloc/ticket_bloc.dart';
import '../../../tickets/presentation/pages/ticket_main_view.dart';
import '../bloc/sla_policy_bloc.dart';

/// A form screen for creating, viewing, and editing SLA (Service Level Agreement)
/// policies in the helpdesk module.
///
/// This screen supports three modes:
/// - **Create mode**: Allows users to create a new SLA policy.
/// - **View mode**: Displays SLA policy details in a read-only format.
/// - **Edit mode**: Enables modification of an existing SLA policy.
///
/// The form handles:
/// - Basic policy information (name, description, time, priority)
/// - Helpdesk configuration (team, stages)
/// - Filtering criteria (types, customers, tags)
/// - Target configuration (reach stage, excluding stages)
///
/// It also tracks unsaved changes and prompts the user before discarding them.
class SlaPolicyForm extends StatefulWidget {
  final int? policyId;
  final bool isCreate;
  final bool? isSmartView;

  const SlaPolicyForm({
    super.key,
    this.policyId,
    this.isCreate = false,
    this.isSmartView = false,
  });

  @override
  State<SlaPolicyForm> createState() => _SlaPolicyFormState();
}

class _SlaPolicyFormState extends State<SlaPolicyForm> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  bool hasInitializedEditControllers = false;

  Map<String, dynamic> initialData = {};
  bool hasChanges = false;

  int priority = 0;
  bool isEdit = false;

  int version = 0;

  bool _hasSetDefaultTeam = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _addChangeListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    timeController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;
    });
  }

  /// Initializes text controllers with existing SLA policy data
  /// when entering edit mode.
  ///
  /// This ensures form fields are populated only once and avoids
  /// overwriting user changes during rebuilds.
  void initializeEditControllers(SlaPolicyState state) {
    if (hasInitializedEditControllers || !isEdit) return;

    final policy = state.selectedPolicy;
    if (policy == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        priority = int.tryParse(policy['priority']?.toString() ?? '0') ?? 0;

        nameController.text = safeUpdateText(policy['name']);
        descriptionController.text = stripHtmlTags(policy['description'] ?? '');
        final timeValue = policy['time'];

        timeController.text = (timeValue == null || timeValue == false)
            ? ''
            : timeValue.toString();

        hasInitializedEditControllers = true;
      });
    });
  }

  /// Exits edit mode and resets change tracking state.
  ///
  /// Clears edit flags and restores the form to read-only mode.
  void exitEditMode() {
    setState(() {
      isEdit = false;
      hasChanges = false;
      hasInitializedEditControllers = false;
    });
  }

  void _addChangeListeners() {
    nameController.addListener(_markHasChanges);
    descriptionController.addListener(_markHasChanges);
    timeController.addListener(_markHasChanges);
  }

  void _markHasChanges() {
    if (mounted && !hasChanges) {
      setState(() => hasChanges = true);
    }
  }

  /// Checks whether the current form state has unsaved changes.
  ///
  /// Compares the current input values with the initial loaded data.
  /// Returns `true` if any field has been modified.
  bool _checkIfHasChanges() {
    if (!isEdit && !widget.isCreate) return false;

    // Name is the only required field; never enable the button without it.
    if (nameController.text.trim().isEmpty) return false;

    final blocState = context.read<SlaPolicyBloc>().state;

    final currentData = {
      'name': nameController.text.trim(),
      'description': descriptionController.text.trim(),
      'time': timeController.text.trim(),
      'priority': priority,
      'team_id': blocState.selectedTeam?['id'],
      'stage_id': blocState.selectedReachStage?['id'],
      'ticket_type_ids': (blocState.selectedTypes ?? [])
          .map((e) => e['id'])
          .toList(),
      'partner_ids': (blocState.selectedCustomers ?? [])
          .map((e) => e['id'])
          .toList(),
      'tag_ids': (blocState.selectedTags ?? []).map((e) => e['id']).toList(),
      'exclude_stage_ids': (blocState.selectedExcludingStages ?? [])
          .map((e) => e['id'])
          .toList(),
    };

    if (widget.isCreate) {
      // The helpdesk team is auto-populated with a default on entry, so it
      // must not count as a user-made change for activating the button.
      final createData = Map<String, dynamic>.from(currentData)
        ..remove('team_id');

      return createData.values.any((value) {
        if (value is String) return value.isNotEmpty;
        if (value is List) return value.isNotEmpty;
        return value != null && value != 0;
      });
    }

    return initialData.toString() != currentData.toString();
  }

  /// Saves the initial SLA policy data into a local snapshot.
  ///
  /// This snapshot is used later to detect changes when editing
  /// an existing SLA policy.
  void _saveInitialData(SlaPolicyState state, Map<String, dynamic>? policy) {
    if (policy == null) return;

    final timeValue = policy['time'];

    initialData = {
      'name': safeUpdateText(policy['name']).trim(),
      'description': stripHtmlTags(policy['description'] ?? '').trim(),
      'time': (timeValue == null || timeValue == false)
          ? ''
          : timeValue.toString().trim(),
      'priority': int.tryParse(policy['priority']?.toString() ?? '0') ?? 0,
      'team_id': state.selectedTeam?['id'],
      'stage_id': state.selectedReachStage?['id'],
      'ticket_type_ids': (state.selectedTypes ?? [])
          .map((e) => e['id'])
          .toList(),
      'partner_ids': (state.selectedCustomers ?? [])
          .map((e) => e['id'])
          .toList(),
      'tag_ids': (state.selectedTags ?? []).map((e) => e['id']).toList(),
      'exclude_stage_ids': (state.selectedExcludingStages ?? [])
          .map((e) => e['id'])
          .toList(),
    };

    hasChanges = false;
  }

  Widget _buildSectionShimmer(bool isDark, String title, {int rowCount = 4}) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 20,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.grey[700] : Colors.grey[200]),
          const SizedBox(height: 16),
          ...List.generate(
            rowCount,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 13,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The form, under an overlay that holds the screen while a create or update
  /// is being saved: the button cannot be pressed twice and nothing else can be
  /// tapped until the result is in.
  @override
  Widget build(BuildContext context) {
    return BlocSavingOverlay<SlaPolicyBloc, SlaPolicyState>(
      isSaving: (state) => state.isSaving,
      message: widget.isCreate ? 'Creating SLA Policy' : 'Saving Changes',
      hintOf: (_) => widget.isCreate
          ? 'Please wait while we create the SLA policy'
          : 'Please wait while we save the SLA policy',
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Leaving mid-save would drop its result, so back waits for it.
        if (didPop || context.read<SlaPolicyBloc>().state.isSaving) return;
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
          exitEditMode();
        } else {
          widget.isSmartView!
              ? Navigator.pop(context)
              : Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: widget.isCreate
              ? 'Create SLA Policy'
              : (isEdit ? "Edit SLA Policy" : "SLA Policy Details"),
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
              exitEditMode();
            } else {
              widget.isSmartView!
                  ? Navigator.pop(context)
                  : Navigator.pop(context, true);
            }
          },
          actions: [
            !isEdit && !widget.isCreate
                ? BlocBuilder<SlaPolicyBloc, SlaPolicyState>(
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
                              final state = context.read<SlaPolicyBloc>().state;
                              _saveInitialData(state, state.selectedPolicy);

                              setState(() {
                                isEdit = true;
                                hasInitializedEditControllers = false;
                                priority =
                                    int.tryParse(
                                      state.selectedPolicy?['priority']
                                              ?.toString() ??
                                          '',
                                    ) ??
                                    0;

                                nameController.text = safeUpdateText(
                                  state.selectedPolicy?['name'],
                                );
                                descriptionController.text = stripHtmlTags(
                                  state.selectedPolicy?['description'] ?? '',
                                );
                                timeController.text = safeUpdateText(
                                  state.selectedPolicy?['time'],
                                );
                              });
                            },
                          ),
                          PopupMenuButton<String>(
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
                                        icon: HugeIcons.strokeRoundedDelete02,
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
                                      state.selectedPolicy!['active'] == false
                                      ? 'unarchive'
                                      : 'archive',
                                  child: Row(
                                    children: [
                                      HugeIcon(
                                        icon:
                                            state.selectedPolicy!['active'] ==
                                                false
                                            ? HugeIcons.strokeRoundedRestoreBin
                                            : HugeIcons.strokeRoundedArchive,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        state.selectedPolicy!['active'] == false
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
                              ];
                            },
                            onSelected: (value) async {
                              switch (value) {
                                case 'delete':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Delete SLA policy',
                                        subTitle:
                                            'Are you sure you want to delete this SLA policy?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Delete',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<SlaPolicyBloc>().add(
                                      DeleteSlaPolicy(widget.policyId!),
                                    );
                                  }
                                  break;
                                case 'archive':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Archive SLA policy',
                                        subTitle:
                                            'Are you sure you want to archive this SLA policy?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Archive',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<SlaPolicyBloc>().add(
                                      ArchiveSlaPolicy(widget.policyId!),
                                    );
                                  }
                                  break;
                                case 'unarchive':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Unarchive SLA policy',
                                        subTitle:
                                            'Are you sure you want to unarchive this SLA policy?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Unarchive',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<SlaPolicyBloc>().add(
                                      UnArchiveSlaPolicy(widget.policyId!),
                                    );
                                  }
                                  break;
                              }
                            },
                          ),
                        ],
                      );
                    },
                  )
                : SizedBox.shrink(),
          ],
        ),
        body: BlocListener<SlaPolicyBloc, SlaPolicyState>(
          listenWhen: (prev, curr) =>
              curr.message != null && curr.message != prev.message,
          listener: (context, state) {
            if (state.message != null) {
              if (!state.isError) {
                CustomSnackBar.showSuccess(context, state.message!);
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
                  context.read<SlaPolicyBloc>().add(
                    LoadSinglePolicy(widget.policyId!),
                  );
                }
              } else {
                CustomSnackBar.showError(context, state.message!);
              }
              context.read<SlaPolicyBloc>().add(ClearSlaMessage());
            }
          },
          child: BlocBuilder<SlaPolicyBloc, SlaPolicyState>(
            builder: (context, state) {
              final policy = state.selectedPolicy;

              if (!widget.isCreate) {
                if (state.isLoading) {
                  return const Center(child: FormViewShimmer());
                }
              }

              if (state.error != null) {
                final error = state.error!;

                return ErrorLottie(
                  title: error['title'] ?? 'Error',
                  subTitle: error['description'] ?? 'Something went wrong.',
                  onPressed: () async {
                    context.read<SlaPolicyBloc>().add(
                      LoadSinglePolicy(widget.policyId!),
                    );
                    AppBootstrapper.reloadAppBlocs(context);
                    await context.read<CompanyProvider>().initialize();
                  },
                );
              }

              if (!widget.isCreate && policy == null) {
                return EmptyLottie(title: "No SLA policy found");
              }

              if (widget.isCreate &&
                  !_hasSetDefaultTeam &&
                  state.helpdeskTeam != null &&
                  state.helpdeskTeam!.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _hasSetDefaultTeam) return;

                  final defaultTeam = state.helpdeskTeam!.first;

                  context.read<SlaPolicyBloc>().add(
                    UpdateSlaSelectedTeam(defaultTeam),
                  );

                  if (defaultTeam['id'] != null) {
                    context.read<SlaPolicyBloc>().add(
                      LoadStagesByTeam(defaultTeam['id']),
                    );
                  }

                  setState(() {
                    _hasSetDefaultTeam = true;
                  });
                });
              }

              if (isEdit && !hasInitializedEditControllers) {
                initializeEditControllers(state);
              }
              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      // Reloading would discard unsaved edits, and a new record has nothing to reload.
                      if (isEdit || widget.isCreate || widget.policyId == null)
                        return;
                      final bloc = context.read<SlaPolicyBloc>();
                      bloc.add(LoadSinglePolicy(widget.policyId!));
                      await bloc.stream
                          .firstWhere((s) => !s.isLoading)
                          .timeout(
                            const Duration(seconds: 30),
                            onTimeout: () => bloc.state,
                          );
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomFormTile.tileStyle(
                              isDark: isDark,
                              bottomMargin: 16,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  (isEdit || widget.isCreate) ? 22 : 16,
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
                                          EditControllerField(
                                            fieldName: 'Description',
                                            controller: descriptionController,
                                            isFieldEdit: true,
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
                                          if (policy!.isNotEmpty) ...[
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (policy['name'] != null &&
                                                          policy['name']
                                                              .toString()
                                                              .isNotEmpty)
                                                      ? policy['name']
                                                      : 'N/A',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A1A1A,
                                                          ),
                                                  ),
                                                ),
                                                if (policy['description'] !=
                                                        null &&
                                                    policy['description'] !=
                                                        false &&
                                                    policy['description']
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                  SizedBox(height: 10),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.all(10),
                                                    constraints: BoxConstraints(
                                                      minHeight: 100,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withAlpha(20),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      stripHtmlTags(
                                                        policy['description'],
                                                      ),
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 10),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Number of tickets",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value:
                                                    (policy['ticket_count'] ??
                                                            0)
                                                        .toString(),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 30),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: ViewButtonsStyle.addViewButtonStyle(
                                                  context: context,
                                                  onPressed: () {
                                                    List<dynamic> domain = [
                                                      [
                                                        'sla_ids',
                                                        'in',
                                                        policy['id'],
                                                      ],
                                                      [
                                                        'stage_id.fold',
                                                        '=',
                                                        false,
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
                              isDark: isDark,
                              bottomMargin: 16,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  (isEdit || widget.isCreate) ? 22 : 18,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? state.isFormLoading
                                          ? _buildSectionShimmer(
                                              isDark,
                                              'Criteria',
                                              rowCount: 4,
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 16,
                                                      ),
                                                  child: Text(
                                                    'Criteria',
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
                                                CardHeadingDivider(
                                                  isDark: isDark,
                                                  inset: 16,
                                                ),
                                                const SizedBox(height: 16),
                                                Container(
                                                  padding: EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withAlpha(20),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.orange,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      HugeIcon(
                                                        icon: HugeIcons
                                                            .strokeRoundedInformationCircle,
                                                        color: Colors.orange,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          'This SLA Policy will apply to tickets matching all of the following criteria',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                SizedBox(height: 20),
                                                EditDropdownField(
                                                  fieldName: "Helpdesk Team",
                                                  items:
                                                      state.helpdeskTeam ?? [],
                                                  value: state.selectedTeam,
                                                  isFieldEdit: true,
                                                  onChanged: (value) async {
                                                    context
                                                        .read<SlaPolicyBloc>()
                                                        .add(
                                                          UpdateSlaSelectedTeam(
                                                            value,
                                                          ),
                                                        );

                                                    if (value != null &&
                                                        value['id'] != null) {
                                                      context
                                                          .read<SlaPolicyBloc>()
                                                          .add(
                                                            LoadStagesByTeam(
                                                              value['id'],
                                                            ),
                                                          );
                                                    }
                                                    _markHasChanges();
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                Text(
                                                  'Priority',
                                                  style: TextStyle(
                                                    fontFamily: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ).fontFamily,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xff7F7F7F,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                StarRating(
                                                  rating: priority,
                                                  maxRating: 3,
                                                  onRatingChanged: (value) {
                                                    setState(() {
                                                      priority = value;
                                                      _markHasChanges();
                                                    });
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                if (version <= 17) ...[
                                                  EditMultiDropdownField(
                                                    fieldName: "Type",
                                                    items: state.types ?? [],
                                                    selectedItems:
                                                        state.selectedTypes ??
                                                        [],
                                                    isFieldEdit: true,
                                                    onChanged: (values) {
                                                      context
                                                          .read<SlaPolicyBloc>()
                                                          .add(
                                                            UpdateSlaSelectedType(
                                                              values,
                                                            ),
                                                          );
                                                      _markHasChanges();
                                                    },
                                                  ),
                                                  SizedBox(height: 20),
                                                ],
                                                EditMultiDropdownField(
                                                  fieldName: "Customers",
                                                  items: state.customers ?? [],
                                                  selectedItems:
                                                      state.selectedCustomers ??
                                                      [],
                                                  isFieldEdit: true,
                                                  onChanged: (values) {
                                                    context
                                                        .read<SlaPolicyBloc>()
                                                        .add(
                                                          UpdateSelectedCustomer(
                                                            values,
                                                          ),
                                                        );
                                                    _markHasChanges();
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                EditMultiDropdownField(
                                                  fieldName: "Tags",
                                                  items: state.tags ?? [],
                                                  selectedItems:
                                                      state.selectedTags ?? [],
                                                  isFieldEdit: true,
                                                  onChanged: (values) {
                                                    context
                                                        .read<SlaPolicyBloc>()
                                                        .add(
                                                          UpdateSlaTags(values),
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
                                          Text(
                                            'Criteria',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          CardHeadingDivider(
                                            isDark: isDark,
                                            inset: 16,
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withAlpha(
                                                20,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.orange,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedInformationCircle,
                                                  color: Colors.orange,
                                                ),
                                                SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    'This SLA Policy will apply to tickets matching all of the following criteria',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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
                                              SizedBox(height: 10),
                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  (policy!['team_id'] is List &&
                                                          policy['team_id']
                                                                  .length >
                                                              1)
                                                      ? policy['team_id'][1]
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
                                                title: "Priority",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),
                                              PriorityStarsWidget(
                                                priority: policy['priority'],
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
                                                  title: "Types",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(width: 10),
                                                policy['types'].isEmpty
                                                    ? buildTagChips(
                                                        policy['types'],
                                                        isDark,
                                                      )
                                                    : Expanded(
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: buildTagChips(
                                                            policy['types'],
                                                            isDark,
                                                          ),
                                                        ),
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
                                              SizedBox(width: 10),
                                              policy['tags'].isEmpty
                                                  ? buildChips(
                                                      policy['tags'],
                                                      isDark,
                                                    )
                                                  : Expanded(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildChips(
                                                          policy['tags'],
                                                          isDark,
                                                        ),
                                                      ),
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
                                                title: "Customers",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              policy['customers'].isEmpty
                                                  ? buildText(
                                                      policy['customers'],
                                                      isDark,
                                                    )
                                                  : Expanded(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildText(
                                                          policy['customers'],
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
                              isDark: isDark,
                              bottomMargin: 16,
                              child: Padding(
                                // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  (isEdit || widget.isCreate) ? 22 : 10,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? state.isFormLoading
                                          ? _buildSectionShimmer(
                                              isDark,
                                              'Target',
                                              rowCount: 3,
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 16,
                                                      ),
                                                  child: Text(
                                                    'Target',
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
                                                CardHeadingDivider(
                                                  isDark: isDark,
                                                  inset: 16,
                                                ),
                                                const SizedBox(height: 16),
                                                EditDropdownField(
                                                  fieldName: "Reach Stage",
                                                  items: state.reachStage ?? [],
                                                  value:
                                                      state.selectedReachStage,
                                                  isFieldEdit: true,
                                                  onChanged: (value) {
                                                    context
                                                        .read<SlaPolicyBloc>()
                                                        .add(
                                                          UpdateReachStage(
                                                            value,
                                                          ),
                                                        );
                                                    _markHasChanges();
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                EditControllerField(
                                                  fieldName: 'Within',
                                                  controller: timeController,
                                                  isFieldEdit: true,
                                                  onChanged: (_) {
                                                    setState(() {});
                                                  },
                                                ),
                                                const SizedBox(height: 20),
                                                EditMultiDropdownField(
                                                  fieldName: "Excluding Stages",
                                                  items:
                                                      state.excludingStages ??
                                                      [],
                                                  selectedItems:
                                                      state
                                                          .selectedExcludingStages ??
                                                      [],
                                                  isFieldEdit: true,
                                                  onChanged: (value) {
                                                    context
                                                        .read<SlaPolicyBloc>()
                                                        .add(
                                                          UpdateExcludingStages(
                                                            value,
                                                          ),
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
                                          Text(
                                            'Target',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          CardHeadingDivider(
                                            isDark: isDark,
                                            inset: 16,
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Reach Stage",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),

                                              CustomFormTile.tileValueText(
                                                value: safeViewText(
                                                  (policy!['stage_id']
                                                              is List &&
                                                          policy['stage_id']
                                                                  .length >
                                                              1)
                                                      ? policy['stage_id'][1]
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
                                                title: "Within",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  CustomFormTile.tileTimeValueText(
                                                    value: safeViewText(
                                                      policy['time'],
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                  Text(
                                                    " h",
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                ],
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
                                                title: "Excluding Stages",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              policy['excludeStages'].isEmpty
                                                  ? buildTagChips(
                                                      policy['excludeStages'],
                                                      isDark,
                                                    )
                                                  : Expanded(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildTagChips(
                                                          policy['excludeStages'],
                                                          isDark,
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isCreate && policy!['active'] == false)
                    HelpdeskRibbon(text: "Archived", color: Colors.red),
                  if (isEdit || widget.isCreate)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        // Same bar as Mobo Events' Create Event: 20/12/20/16.
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
                        child: SizedBox(
                          height: 48,
                          child: ViewButtonsStyle.createUpdateButtonStyle(
                            context: context,
                            onPressed: _checkIfHasChanges()
                                ? () {
                                    final bloc = context.read<SlaPolicyBloc>();

                                    final data = {
                                      'name': nameController.text,
                                      'description': descriptionController.text,
                                      'time': timeController.text,
                                      'priority': priority.toString(),

                                      'team_id': state.selectedTeam?['id'],
                                      'stage_id':
                                          state.selectedReachStage?['id'],

                                      if (version <= 17)
                                        'ticket_type_ids':
                                            (state.selectedTypes ?? [])
                                                .map((e) => e['id'])
                                                .toList(),
                                      'partner_ids':
                                          (state.selectedCustomers ?? [])
                                              .map((e) => e['id'])
                                              .toList(),

                                      'tag_ids': (state.selectedTags ?? [])
                                          .map((e) => e['id'])
                                          .toList(),

                                      'exclude_stage_ids':
                                          (state.selectedExcludingStages ?? [])
                                              .map((e) => e['id'])
                                              .toList(),
                                    };

                                    if (isEdit) {
                                      bloc.add(
                                        UpdatePolicy(widget.policyId!, data),
                                      );
                                    } else {
                                      bloc.add(CreatePolicy(data));
                                    }
                                  }
                                : null,
                            title: isEdit
                                ? "Update SLA Policy"
                                : "Create SLA Policy",
                            icon: isEdit
                                ? HugeIcons.strokeRoundedTaskEdit01
                                : HugeIcons.strokeRoundedNoteAdd,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
