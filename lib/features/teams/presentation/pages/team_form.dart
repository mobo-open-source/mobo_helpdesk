import '../../../../core/widgets/card_heading_divider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/notice_dialog.dart';
import '../../../../core/widgets/saving_overlay.dart';
import '../../../../core/widgets/custom_form_tile.dart';
import '../../../../core/widgets/edit_controller_field.dart';
import '../../../../core/widgets/edit_dropdown_field.dart';
import '../../../../core/widgets/edit_multi_dropdown_field.dart';
import '../../../../core/widgets/empty_lottie.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/full_card_shimmer.dart';
import '../../../../core/widgets/form_view_shimmer.dart' show shimmerBox;
import '../../../../core/widgets/helpdesk_ribbon.dart';
import '../../../../core/widgets/ignore_tag.dart';
import '../../../../core/widgets/mobo_checkbox.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../core/widgets/tag_chip_widget.dart';
import '../../../../core/widgets/view_buttons_style.dart';
import '../../../../di/injection_container.dart';
import '../../domain/usecases/team_form_usecase.dart';
import '../../../sla_policy/presentation/bloc/sla_policy_bloc.dart';
import '../../../sla_policy/presentation/pages/sla_policy_list.dart';
import '../../../tickets/presentation/bloc/ticket_bloc.dart';
import '../../../tickets/presentation/pages/ticket_main_view.dart';
import '../bloc/team_bloc.dart';
import '../widgets/selection_text.dart';

/// A comprehensive form screen for creating or viewing/editing a Helpdesk Team.
///
/// This widget serves as the main UI for managing team configurations in a helpdesk
/// system. It supports both creation of new teams and detailed view/edit modes for
/// existing teams.
///
/// ## Features:
/// - **View Mode**: Displays team details including ticket count, SLA policies,
///   visibility settings, enabled modules, and configuration summaries.
/// - **Edit/Create Mode**: Provides interactive form fields to modify team properties.
/// - **Module Management**: Handles enabling/disabling of various features such as:
///   - Email alias, Live Chat, Website Form
///   - Knowledge Base, Community Forum, eLearning
///   - Timesheets, Time Billing
///   - SLA Policies, Customer Ratings
///   - Self-service options (customer ticket closure, auto-closing)
///   - After-sales features (refunds, coupons, returns, repairs, field service)
/// - **Unsaved Changes Protection**: Shows confirmation dialog when user tries to
///   leave with unsaved modifications.
/// - **Dynamic Loading**: Integrates with [TeamBloc] for loading, creating, and
///   updating team data, including related entities (members, followers, projects, etc.).
/// - **Module Installation**: Prompts and handles installation of dependent modules
///   (Website, Project) when enabling related features.
/// - **Navigation Shortcuts**: Allows quick access to related tickets and SLA policies
///   directly from the team details screen.
///
/// ## Parameters:
/// - [teamId]: The ID of the team to load and display (required for edit/view mode).
/// - [isCreate]: When `true`, the screen operates in create-new-team mode.
///
/// ## State Management:
/// Uses [flutter_bloc] with [TeamBloc] to manage team data, selections,
/// and loading states. Listens for success/error messages and handles navigation
/// accordingly.
///
/// ## UI Components:
/// - Custom app bar with edit and action menu
/// - Multiple collapsible-style form sections using [CustomFormTile]
/// - Rich form inputs: text fields, dropdowns, multi-select dropdowns, checkboxes
/// - Visual feedback using Lottie animations for loading, empty, and error states
///
/// This widget is heavily coupled with the helpdesk domain logic and assumes
/// the presence of various core widgets and services defined in the project.
class TeamForm extends StatefulWidget {
  final int? teamId;
  final bool isCreate;

  const TeamForm({super.key, this.teamId, this.isCreate = false});

  @override
  State<TeamForm> createState() => _TeamFormState();
}

class _TeamFormState extends State<TeamForm> {
  /// Space above every field nested under a toggle or under another field, so
  /// stacked fields are evenly spaced.
  static const double _nestedGap = 14;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController aliasNameController = TextEditingController();
  final TextEditingController inactiveDaysController = TextEditingController();
  final TextEditingController reminderDelayController = TextEditingController();

  bool isEdit = false;
  bool isInitialized = false;

  bool isAssignment = false;
  bool isEmailAlias = false;
  bool isLiveChat = false;
  bool isWebsiteForm = false;
  bool isKnowledge = false;
  bool isCommunityForum = false;
  bool isLearning = false;
  bool isTimesheet = false;
  bool isTimeBilling = false;
  bool isPolicy = false;
  bool isRating = false;
  bool isTicketClose = false;
  bool isAutoClosing = false;
  bool isRefund = false;
  bool isCoupon = false;
  bool isReturn = false;
  bool isRepair = false;
  bool isFieldService = false;
  bool isGiftcard = false;
  bool isReplacement = false;
  bool isPortalRating = false;
  bool isAutoReminder = true;

  /// The email template the auto-close reminder uses, and the ones to choose.
  Map<String, dynamic>? selectedReminderTemplate;
  List<Map<String, dynamic>> reminderTemplates = [];

  /// What Odoo fills in for a new team, used until the user says otherwise: the
  /// auto-close period and the reminder delay, in days.
  int defaultCloseDays = 7;
  int defaultReminderDelay = 2;

  bool isModuleCheck = false;
  bool hasChanges = false;
  bool isControllerInitialized = false;

  /// Which settings the server's teams have. They differ by version: Odoo 20
  /// moved ratings to the stages and added the auto-close reminder, Odoo 19 and
  /// 20 added gift cards and replacements, and only Odoo 17 can publish ratings
  /// on the website. A setting is shown only where it exists.
  bool supportsRating = true;
  bool supportsPortalRating = false;
  bool supportsGiftcards = false;
  bool supportsReplacements = false;
  bool supportsReminder = false;

  @override
  void initState() {
    super.initState();
    _addChangeListeners();
    _loadFieldSupport();
  }

  Future<void> _loadFieldSupport() async {
    final has = (await OdooFieldResolver.availableFields(
      'helpdesk.team',
      [
        'use_rating',
        'portal_show_rating',
        'use_giftcards',
        'use_product_replacements',
        'auto_close_ticket_reminder',
      ],
      whenUnknown: const ['use_rating'],
    )).toSet(); // only that one is older

    var templates = <Map<String, dynamic>>[];
    var defaults = <String, dynamic>{};
    if (has.contains('auto_close_ticket_reminder')) {
      final useCase = sl<TeamFormUseCase>();
      try {
        templates = await useCase.loadReminderTemplates();
      } catch (_) {
        // The reminder is still editable; only the template list is empty.
      }
      defaults = await useCase.loadTeamDefaults();
    }

    if (!mounted) return;
    setState(() {
      supportsRating = has.contains('use_rating');
      supportsPortalRating = has.contains('portal_show_rating');
      supportsGiftcards = has.contains('use_giftcards');
      supportsReplacements = has.contains('use_product_replacements');
      supportsReminder = has.contains('auto_close_ticket_reminder');
      reminderTemplates = templates;

      final days = defaults['auto_close_day'];
      if (days is int && days > 0) defaultCloseDays = days;
      final delay = defaults['auto_close_reminder_delay'];
      if (delay is int && delay >= 0) defaultReminderDelay = delay;

      // A new team starts with Odoo's reminder settings.
      if (widget.isCreate && !isEdit) {
        if (defaults['auto_close_ticket_reminder'] is bool) {
          isAutoReminder = defaults['auto_close_ticket_reminder'] as bool;
        }
        final template = defaults['reminder_email_template_id'];
        final match = templates.where((t) => t['id'] == template);
        if (match.isNotEmpty) selectedReminderTemplate = match.first;
      }
    });
  }

  /// The auto-close period must be a positive whole number of days. A new team
  /// may leave it empty: Odoo's own default then applies.
  String? _daysError(String value) {
    if (!isAutoClosing) return null;
    final text = value.trim();
    if (text.isEmpty) return isEdit ? 'Enter the days of inactivity' : null;
    final days = int.tryParse(text);
    if (days == null || days < 1) {
      return 'Enter a whole number of days, at least 1';
    }
    return null;
  }

  /// Odoo 20 sends the reminder that many days before the ticket closes, so it
  /// has to be shorter than the auto-close period; the server refuses the team
  /// otherwise. Empty means Odoo's default delay.
  String? _reminderError(String value) {
    if (!isAutoClosing || !supportsReminder || !isAutoReminder) return null;
    final text = value.trim();
    final delay = text.isEmpty ? defaultReminderDelay : int.tryParse(text);
    if (delay == null || delay < 0) return 'Enter a whole number of days';
    final days =
        int.tryParse(inactiveDaysController.text.trim()) ?? defaultCloseDays;
    if (delay >= days) {
      return 'The reminder must be sent before the ticket closes: use fewer '
          'than $days days, or a longer inactive period.';
    }
    return null;
  }

  /// Why the auto-close settings cannot be saved yet, or null when they can.
  String? get _autoCloseError =>
      _daysError(inactiveDaysController.text) ??
      _reminderError(reminderDelayController.text);

  @override
  void dispose() {
    super.dispose();
    nameController.dispose();
    descriptionController.dispose();
    aliasNameController.dispose();
    inactiveDaysController.dispose();
    reminderDelayController.dispose();
  }

  void _addChangeListeners() {
    nameController.addListener(_markHasChanges);
    aliasNameController.addListener(_markHasChanges);
    inactiveDaysController.addListener(_markHasChanges);
    reminderDelayController.addListener(_markHasChanges);
    descriptionController.addListener(_markHasChanges);
  }

  void _removeChangeListeners() {
    nameController.removeListener(_markHasChanges);
    aliasNameController.removeListener(_markHasChanges);
    inactiveDaysController.removeListener(_markHasChanges);
    reminderDelayController.removeListener(_markHasChanges);
    descriptionController.removeListener(_markHasChanges);
  }

  void _markHasChanges() {
    if (!hasChanges) {
      setState(() {
        hasChanges = true;
      });
    }
  }

  Widget _buildSectionShimmer(bool isDark, {int rowCount = 4}) {
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

  Widget _buildVisibilityShimmer(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shimmerBox(width: 200, height: 20),
          const SizedBox(height: 20),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
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

  /// What to send for a many2one the user may have cleared.
  ///
  /// A null is dropped before the request is made, so while editing a cleared
  /// field has to go as `false` or the server keeps the old value. A new team
  /// leaves an empty one out, so the server's own default still applies.
  dynamic _relationValue(Map<String, dynamic>? selected) =>
      selected?['id'] ?? (isEdit ? false : null);

  /// The options whose Odoo apps may have to be installed, with the name the
  /// form shows for each.
  static const Map<String, String> _appOptions = {
    'use_website_helpdesk_form': 'Website Form',
    'use_website_helpdesk_livechat': 'Live Chat',
    'use_website_helpdesk_forum': 'Community Forum',
    'use_website_helpdesk_slides': 'eLearning',
    'use_website_helpdesk_knowledge': 'Knowledge',
    'use_helpdesk_timesheet': 'Timesheets',
    'use_helpdesk_sale_timesheet': 'Time Billing',
    'use_credit_notes': 'Refunds',
    'use_coupons': 'Coupons',
    'use_giftcards': 'Gift Cards',
    'use_product_returns': 'Returns',
    'use_product_replacements': 'Replacements',
    'use_product_repairs': 'Repairs',
    'use_fsm': 'Field Service',
  };

  /// Which of those options are switched on in the form now.
  List<String> get _optionsSwitchedOn {
    final on = <String, bool>{
      'use_website_helpdesk_form': isWebsiteForm,
      'use_website_helpdesk_livechat': isLiveChat,
      'use_website_helpdesk_forum': isCommunityForum,
      'use_website_helpdesk_slides': isLearning,
      'use_website_helpdesk_knowledge': isKnowledge,
      'use_helpdesk_timesheet': isTimesheet,
      'use_helpdesk_sale_timesheet': isTimeBilling,
      'use_credit_notes': isRefund,
      'use_coupons': isCoupon,
      'use_giftcards': isGiftcard,
      'use_product_returns': isReturn,
      'use_product_replacements': isReplacement,
      'use_product_repairs': isRepair,
      'use_fsm': isFieldService,
    };
    return [
      for (final option in on.entries)
        if (option.value) option.key,
    ];
  }

  /// True while the server is being asked whether saving installs an app. The
  /// loading screen is already up then: tapping Create must answer at once, not
  /// after the server has replied.
  bool _preparingSave = false;

  /// What the form holds, as the values to save.
  Map<String, dynamic> _teamData(TeamState state) => {
    'name': nameController.text,
    'description': descriptionController.text,
    'alias_name': aliasNameController.text,
    'auto_close_day': inactiveDaysController.text,

    'privacy_visibility': state.selectedVisibility,
    // The followers the team form shows are partners.
    'message_partner_ids': (state.selectedPartners ?? [])
        .map((e) => e['id'])
        .toList(),
    'auto_assignment': isAssignment,
    'assign_method': state.selectedAssignment,
    'member_ids': (state.selectedMembers ?? []).map((e) => e['id']).toList(),
    'use_alias': isEmailAlias,
    'alias_domain_id': _relationValue(state.selectedAlias),
    'alias_contact': state.selectedAliasFrom,
    'use_website_helpdesk_livechat': isLiveChat,
    'use_website_helpdesk_form': isWebsiteForm,
    'use_website_helpdesk_knowledge': isKnowledge,
    'use_website_helpdesk_forum': isCommunityForum,
    'use_website_helpdesk_slides': isLearning,
    'use_helpdesk_timesheet': isTimesheet,
    if (state.isWebsiteInstalled)
      'website_id': _relationValue(state.selectedWebsite),

    if (state.isProjectInstalled == true)
      'project_id': _relationValue(state.selectedProject),
    'use_helpdesk_sale_timesheet': isTimeBilling,
    'use_sla': isPolicy,
    'resource_calendar_id': _relationValue(state.selectedResource),
    'use_rating': isRating,
    'allow_portal_ticket_closing': isTicketClose,
    'auto_close_ticket': isAutoClosing,
    'to_stage_id': _relationValue(state.selectedStage),
    'from_stage_ids': (state.selectedInStages ?? [])
        .map((e) => e['id'])
        .toList(),
    'use_credit_notes': isRefund,
    'use_giftcards': isGiftcard,
    'use_coupons': isCoupon,
    'use_product_returns': isReturn,
    'use_product_replacements': isReplacement,
    'use_product_repairs': isRepair,
    'use_fsm': isFieldService,
    'portal_show_rating': isPortalRating,
    // Odoo 20: remind the customer before a
    // ticket is closed for inactivity.
    'auto_close_ticket_reminder': isAutoReminder,
    'auto_close_reminder_delay': reminderDelayController.text,
    'reminder_email_template_id': _relationValue(selectedReminderTemplate),
  };

  /// Saves the team.
  ///
  /// Switching on an option such as Timesheets makes Odoo install the matching
  /// app on the server while the team is saved, which takes a while and reloads
  /// the server. Like Odoo's own form, this asks the server first whether that
  /// will happen; if it will, the user is told which options need it and agrees
  /// before anything is sent, and the save then runs under an "Installing apps"
  /// screen instead of the plain "Saving".
  Future<void> _save(BuildContext context, TeamState state) async {
    final bloc = context.read<TeamBloc>();

    if (!isEdit && nameController.text.isEmpty) {
      CustomSnackBar.showInfo(context, "Name is mandatory");
      return;
    }
    final data = _teamData(state);

    // A field that keeps focus keeps the keyboard: it would come back when the
    // dialog below closes and show through the "Installing apps" screen.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _preparingSave = true);
    var needInstall = <String>[];
    try {
      needInstall = await sl<TeamFormUseCase>().optionsNeedingInstall(
        _optionsSwitchedOn,
      );
    } catch (_) {
      // Not knowing is no reason to stop the save.
    } finally {
      if (mounted) setState(() => _preparingSave = false);
    }
    if (!mounted || !context.mounted) return;

    var installs = false;
    if (needInstall.isNotEmpty) {
      final names = [
        for (final field in needInstall) _appOptions[field] ?? field,
      ];
      final agreed = await ConfirmationDialogWidget.show(
        context: context,
        title: 'Install required apps?',
        subTitle:
            '${_joinNames(names)} need${names.length == 1 ? 's' : ''} more Odoo '
            'apps that are not installed on your server yet. Saving installs '
            'them now. This can take a few minutes and the server reloads when '
            'it is done. Keep the app open until it finishes.',
        negativeButtonText: 'Cancel',
        // Short on purpose: with Cancel it stays on one row.
        positiveButtonText: 'Install',
      );
      if (agreed != true || !mounted || !context.mounted) return;
      installs = true;
      // After installing, stay in the form with the new apps' fields loaded,
      // as Odoo's own form reloads.
      if (isEdit) isModuleCheck = true;
    }

    if (isEdit) {
      bloc.add(UpdateTeam(widget.teamId!, data, installs: installs));
    } else {
      bloc.add(CreateTeam(data, installs: installs));
    }
  }

  /// The server kept the team although installing its apps failed: say what
  /// happened, then leave the form the way a successful save does. A new team
  /// goes back to the list (which reloads and shows it); sending the form again
  /// would only create it a second time.
  Future<void> _showSavedWithoutApps(
    BuildContext context,
    String message,
  ) async {
    final bloc = context.read<TeamBloc>();
    // The message reads: what happened, what the server said, what to do.
    final parts = message.split('\n\n');
    await NoticeDialog.show(
      context: context,
      title: 'Apps not installed',
      message: parts.first,
      detail: parts.length > 2 ? parts[1] : null,
      hint: parts.length > 1 ? parts.last : null,
    );
    if (!mounted || !context.mounted) return;
    if (widget.isCreate) {
      Navigator.pop(context, true);
    } else {
      setState(() => isEdit = false);
      bloc.add(LoadSingleTeam(widget.teamId!));
    }
  }

  /// "A", "A and B", "A, B and C".
  String _joinNames(List<String> names) => names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

  bool _checkIfHasChanges() {
    if (!isEdit && !widget.isCreate) return false;

    final team = context.read<TeamBloc>().state.selectedTeam;

    if (widget.isCreate) {
      return nameController.text.trim().isNotEmpty &&
          (nameController.text.trim().isNotEmpty ||
              descriptionController.text.trim().isNotEmpty ||
              aliasNameController.text.trim().isNotEmpty ||
              inactiveDaysController.text.trim().isNotEmpty ||
              isAssignment != true ||
              isEmailAlias != true ||
              isLiveChat ||
              isWebsiteForm ||
              isKnowledge ||
              isCommunityForum ||
              isLearning ||
              isTimesheet ||
              isTimeBilling ||
              isPolicy ||
              isRating ||
              isTicketClose ||
              isAutoClosing ||
              isRefund ||
              isCoupon ||
              isReturn ||
              isRepair ||
              isGiftcard ||
              isReplacement ||
              isFieldService);
    } else {
      if (team == null) return false;

      // Name is required; never enable the button without it.
      if (nameController.text.trim().isEmpty) return false;

      final blocState = context.read<TeamBloc>().state;

      final initialMemberIds = (team['members'] is List)
          ? (team['members'] as List).map((m) => m['id']).toSet()
          : <dynamic>{};
      final currentMemberIds = (blocState.selectedMembers ?? [])
          .map((m) => m['id'])
          .toSet();

      final initialPartnerIds = (team['messagePartners'] is List)
          ? (team['messagePartners'] as List).map((p) => p['id']).toSet()
          : <dynamic>{};
      final currentPartnerIds = (blocState.selectedPartners ?? [])
          .map((p) => p['id'])
          .toSet();

      // A many2one as the server returns it is `[id, name]`, or false/null
      // when empty.
      dynamic relationId(dynamic value) =>
          value is List && value.isNotEmpty ? value[0] : null;

      final initialStageId = relationId(team['to_stage_id']);

      final initialInStageIds = (team['stages'] is List)
          ? (team['stages'] as List).map((s) => s['id']).toSet()
          : <dynamic>{};
      final currentInStageIds = (blocState.selectedInStages ?? [])
          .map((s) => s['id'])
          .toSet();

      return nameController.text.trim() !=
              safeUpdateText(team['name']).trim() ||
          descriptionController.text.trim() !=
              stripHtmlTags(team['description'] ?? '').trim() ||
          aliasNameController.text.trim() !=
              safeUpdateText(team['alias_name']).trim() ||
          inactiveDaysController.text.trim() !=
              (team['auto_close_day']?.toString() ?? '') ||
          isAssignment != (team['auto_assignment'] ?? false) ||
          isEmailAlias != (team['use_alias'] ?? false) ||
          isLiveChat != (team['use_website_helpdesk_livechat'] ?? false) ||
          isWebsiteForm != (team['use_website_helpdesk_form'] ?? false) ||
          isKnowledge != (team['use_website_helpdesk_knowledge'] ?? false) ||
          isCommunityForum != (team['use_website_helpdesk_forum'] ?? false) ||
          isLearning != (team['use_website_helpdesk_slides'] ?? false) ||
          isTimesheet != (team['use_helpdesk_timesheet'] ?? false) ||
          isTimeBilling != (team['use_helpdesk_sale_timesheet'] ?? false) ||
          isPolicy != (team['use_sla'] ?? false) ||
          isRating != (team['use_rating'] ?? false) ||
          isTicketClose != (team['allow_portal_ticket_closing'] ?? false) ||
          isAutoClosing != (team['auto_close_ticket'] ?? false) ||
          isRefund != (team['use_credit_notes'] ?? false) ||
          isCoupon != (team['use_coupons'] ?? false) ||
          isReturn != (team['use_product_returns'] ?? false) ||
          isRepair != (team['use_product_repairs'] ?? false) ||
          isFieldService != (team['use_fsm'] ?? false) ||
          isGiftcard != (team['use_giftcards'] ?? false) ||
          isReplacement != (team['use_product_replacements'] ?? false) ||
          isPortalRating != (team['portal_show_rating'] ?? false) ||
          isAutoReminder != (team['auto_close_ticket_reminder'] ?? true) ||
          reminderDelayController.text.trim() !=
              (team['auto_close_reminder_delay']?.toString() ?? '') ||
          selectedReminderTemplate?['id'] !=
              relationId(team['reminder_email_template_id']) ||
          blocState.selectedVisibility != team['privacy_visibility'] ||
          blocState.selectedAssignment != team['assign_method'] ||
          blocState.selectedAliasFrom != team['alias_contact'] ||
          blocState.selectedStage?['id'] != initialStageId ||
          blocState.selectedAlias?['id'] !=
              relationId(team['alias_domain_id']) ||
          blocState.selectedWebsite?['id'] != relationId(team['website_id']) ||
          blocState.selectedProject?['id'] != relationId(team['project_id']) ||
          blocState.selectedResource?['id'] !=
              relationId(team['resource_calendar_id']) ||
          !initialMemberIds.containsAll(currentMemberIds) ||
          !currentMemberIds.containsAll(initialMemberIds) ||
          !initialPartnerIds.containsAll(currentPartnerIds) ||
          !currentPartnerIds.containsAll(initialPartnerIds) ||
          !initialInStageIds.containsAll(currentInStageIds) ||
          !currentInStageIds.containsAll(initialInStageIds);
    }
  }

  /// The form, under an overlay that holds the screen while a create or update
  /// is being saved: the button cannot be pressed twice and nothing else can be
  /// tapped until the result is in.
  @override
  Widget build(BuildContext context) {
    final message = widget.isCreate ? 'Creating Team' : 'Saving Changes';
    return SavingOverlay(
      // From the tap until the bloc takes over below.
      isSaving: _preparingSave,
      message: message,
      hint: widget.isCreate
          ? 'Please wait while we create the team'
          : 'Please wait while we save the team',
      child: BlocSavingOverlay<TeamBloc, TeamState>(
        isSaving: (state) => state.isSaving,
        message: message,
        // A save that installs apps says so, and that it takes a while.
        messageOf: (state) => state.savingMessage,
        hintOf: (state) => (state.savingHint.isNotEmpty)
            ? state.savingHint
            : (widget.isCreate
                  ? 'Please wait while we create the team'
                  : 'Please wait while we save the team'),
        child: _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Leaving mid-save would drop its result, so back waits for it.
        if (didPop ||
            _preparingSave ||
            context.read<TeamBloc>().state.isSaving) {
          return;
        }
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
            isControllerInitialized = false;
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: widget.isCreate
              ? 'Create Team'
              : (isEdit ? "Edit Team" : "Team Details"),
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
                isControllerInitialized = false;
              });
            } else {
              Navigator.pop(context, true);
            }
          },
          actions: [
            !isEdit && !widget.isCreate
                ? BlocBuilder<TeamBloc, TeamState>(
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
                              setState(() {
                                isEdit = true;
                                isModuleCheck = false;
                                isInitialized = false;
                                isControllerInitialized = false;
                                hasChanges = false;
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
                                  value: state.selectedTeam!['active'] == false
                                      ? 'unarchive'
                                      : 'archive',
                                  child: Row(
                                    children: [
                                      HugeIcon(
                                        icon:
                                            state.selectedTeam!['active'] ==
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
                                        state.selectedTeam!['active'] == false
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
                                if (state.selectedTeam!['open_ticket_count'] >
                                    0)
                                  PopupMenuItem(
                                    value: 'view_ticket',
                                    child: Row(
                                      children: [
                                        HugeIcon(
                                          icon:
                                              HugeIcons.strokeRoundedBookOpen02,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "View Ticket",
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
                                if (state.selectedTeam!['sla_policy_count'] > 0)
                                  PopupMenuItem(
                                    value: 'view_policy',
                                    child: Row(
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons.strokeRoundedPolicy,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "View SLA Policy",
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
                              final teamId = state.selectedTeam!['id'];

                              switch (value) {
                                case 'view_ticket':
                                  List<dynamic> domain = [
                                    ['team_id', '=', teamId],
                                    ['stage_id.fold', '=', false],
                                  ];
                                  final groupBy = 'stage';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) =>
                                            sl<TicketBloc>()..add(
                                              TicketsLoad(
                                                1,
                                                customDomain: domain,
                                                filters: null,
                                                groupBy: groupBy,
                                                dateUnit: null,
                                                selectedDates: null,
                                              ),
                                            ),
                                        child: TicketMainView(
                                          isSmartView: true,
                                          customDomain: domain,
                                          bloc: null,
                                        ),
                                      ),
                                    ),
                                  );
                                  break;

                                case 'view_policy':
                                  List<dynamic> domain = [
                                    ['team_id', '=', teamId],
                                  ];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) =>
                                            sl<SlaPolicyBloc>()..add(
                                              SlaPolicyLoad(
                                                1,
                                                customDomain: domain,
                                                filters: null,
                                                groupBy: null,
                                              ),
                                            ),
                                        child: SlaPolicyList(
                                          isSmartView: true,
                                          customDomain: domain,
                                          bloc: null,
                                        ),
                                      ),
                                    ),
                                  );
                                  break;
                                case 'delete':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Delete team',
                                        subTitle:
                                            'Are you sure you want to delete this team?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Delete',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<TeamBloc>().add(
                                      DeleteTeam(widget.teamId!),
                                    );
                                  }
                                  break;
                                case 'archive':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Archive team',
                                        subTitle:
                                            'Are you sure you want to archive this team?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Archive',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<TeamBloc>().add(
                                      ArchiveTeam(widget.teamId!),
                                    );
                                  }
                                  break;
                                case 'unarchive':
                                  final confirm =
                                      await ConfirmationDialogWidget.show(
                                        context: context,
                                        title: 'Unarchive Team',
                                        subTitle:
                                            'Are you sure you want to unarchive this team?',
                                        negativeButtonText: 'Cancel',
                                        positiveButtonText: 'Unarchive',
                                      );
                                  if (!context.mounted) return;
                                  if (confirm == true) {
                                    context.read<TeamBloc>().add(
                                      UnarchiveTeam(widget.teamId!),
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
        body: BlocListener<TeamBloc, TeamState>(
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
                    Navigator.pop(context, true);
                  });
                  return;
                }
                Future.delayed(const Duration(seconds: 3), () {
                  if (!context.mounted) return;
                  checkRating(context);
                });
                if (widget.isCreate) {
                  Navigator.pop(context, true);
                } else if (isModuleCheck) {
                  setState(() {
                    isEdit = true;
                    isInitialized = false;
                    isModuleCheck = false;
                  });
                  context.read<TeamBloc>().add(LoadSingleTeam(widget.teamId!));
                } else {
                  setState(() {
                    isEdit = false;
                  });
                  context.read<TeamBloc>().add(LoadSingleTeam(widget.teamId!));
                }
              } else {
                isModuleCheck = false; // the install did not happen
                if (state.serverSaved) {
                  _showSavedWithoutApps(context, state.message!);
                } else {
                  CustomSnackBar.showError(context, state.message!);
                }
              }
              context.read<TeamBloc>().add(ClearTeamMessage());
            }
          },
          child: BlocBuilder<TeamBloc, TeamState>(
            builder: (context, state) {
              final team = state.selectedTeam;

              if (!widget.isCreate) {
                if (state.isLoading) {
                  return const DetailCardsShimmer();
                }
              }
              if (state.error != null) {
                final error = state.error!;

                return ErrorLottie(
                  title: error['title'] ?? 'Error',
                  subTitle: error['description'] ?? 'Something went wrong.',
                  onPressed: () async {
                    context.read<TeamBloc>().add(
                      LoadSingleTeam(widget.teamId!),
                    );
                    AppBootstrapper.reloadAppBlocs(context);
                    await context.read<CompanyProvider>().initialize();
                  },
                );
              }
              if (!widget.isCreate && team == null) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [EmptyLottie(title: "No team found")],
                );
              }
              if (!widget.isCreate) {
                if (!isInitialized) {
                  isAssignment = team!['auto_assignment'] ?? false;
                  isEmailAlias = team['use_alias'] ?? false;
                  isLiveChat = team['use_website_helpdesk_livechat'] ?? false;
                  isWebsiteForm = team['use_website_helpdesk_form'] ?? false;
                  isKnowledge = team['use_website_helpdesk_knowledge'] ?? false;
                  isCommunityForum =
                      team['use_website_helpdesk_forum'] ?? false;
                  isLearning = team['use_website_helpdesk_slides'] ?? false;
                  isTimesheet = team['use_helpdesk_timesheet'] ?? false;
                  isTimeBilling = team['use_helpdesk_sale_timesheet'] ?? false;
                  isPolicy = team['use_sla'] ?? false;
                  isRating = team['use_rating'] ?? false;
                  isTicketClose = team['allow_portal_ticket_closing'] ?? false;
                  isAutoClosing = team['auto_close_ticket'] ?? false;
                  isRefund = team['use_credit_notes'] ?? false;
                  isCoupon = team['use_coupons'] ?? false;
                  isReturn = team['use_product_returns'] ?? false;
                  isRepair = team['use_product_repairs'] ?? false;
                  isFieldService = team['use_fsm'] ?? false;
                  isGiftcard = team['use_giftcards'] ?? false;
                  isReplacement = team['use_product_replacements'] ?? false;
                  isPortalRating = team['portal_show_rating'] ?? false;
                  isAutoReminder = team['auto_close_ticket_reminder'] ?? true;
                  final reminderTemplate = team['reminder_email_template_id'];
                  selectedReminderTemplate =
                      reminderTemplate is List && reminderTemplate.length >= 2
                      ? {'id': reminderTemplate[0], 'name': reminderTemplate[1]}
                      : null;
                  isInitialized = true;
                }
              } else {
                if (!isInitialized) {
                  isAssignment = true;
                  isEmailAlias = true;
                  isInitialized = true;
                }
              }

              if (isEdit && !isControllerInitialized) {
                _removeChangeListeners();
                nameController.text = safeUpdateText(team!['name'] ?? '');
                descriptionController.text = stripHtmlTags(
                  team['description'] ?? '',
                );
                aliasNameController.text = safeUpdateText(
                  team['alias_name'] ?? '',
                );
                inactiveDaysController.text =
                    team['auto_close_day']?.toString() ?? '';
                reminderDelayController.text =
                    team['auto_close_reminder_delay']?.toString() ?? '';
                _addChangeListeners();
                isControllerInitialized = true;
              }
              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      // Reloading would discard unsaved edits, and a new record has nothing to reload.
                      if (isEdit || widget.isCreate || widget.teamId == null)
                        return;
                      final bloc = context.read<TeamBloc>();
                      bloc.add(LoadSingleTeam(widget.teamId!));
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
                                // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  (isEdit || widget.isCreate) ? 24 : 11,
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
                                          if (team!.isNotEmpty) ...[
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (team['name'] != null &&
                                                          team['name']
                                                              .toString()
                                                              .isNotEmpty)
                                                      ? team['name']
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
                                                const SizedBox(height: 18),
                                                CardHeadingDivider(
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 16),
                                                if (team['description'] !=
                                                        null &&
                                                    team['description'] !=
                                                        false &&
                                                    team['description']
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                  SizedBox(height: 20),

                                                  if (stripHtmlTags(
                                                    team['description'],
                                                  ).trim().isNotEmpty)
                                                    Container(
                                                      width: double.infinity,
                                                      constraints:
                                                          BoxConstraints(
                                                            minHeight: 100,
                                                          ),
                                                      padding: EdgeInsets.all(
                                                        10,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue
                                                            .withAlpha(20),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: _CollapsibleText(
                                                        text: stripHtmlTags(
                                                          team['description'],
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
                                          const SizedBox(height: 20),

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
                                                    (team['open_ticket_count'] ??
                                                            0)
                                                        .toString(),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Number of SLA Policy",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 10),
                                              CustomFormTile.tileValueText(
                                                value:
                                                    (team['sla_policy_count'] ??
                                                            0)
                                                        .toString(),
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
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
                                  (isEdit || widget.isCreate)
                                      ? (isAssignment ? 24 : 18)
                                      : 20,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? state.isFormLoading
                                          ? _buildSectionShimmer(
                                              isDark,
                                              rowCount: 4,
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 18.0,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Visibility & Assignment',
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
                                                    ],
                                                  ),
                                                ),
                                                CardHeadingDivider(
                                                  isDark: isDark,
                                                ),
                                                SizedBox(height: 20),
                                                EditDropdownField(
                                                  fieldName: "Visibility",
                                                  items: [
                                                    {
                                                      "id": "invited_internal",
                                                      "label":
                                                          "Invited internal users (private)",
                                                    },
                                                    {
                                                      "id": "internal",
                                                      "label":
                                                          "All internal users (company)",
                                                    },
                                                    {
                                                      "id": "portal",
                                                      "label":
                                                          "Invited portal users and all internal users (public)",
                                                    },
                                                  ],
                                                  selectionValue:
                                                      state.selectedVisibility,
                                                  isFieldEdit: true,
                                                  isSelection: true,
                                                  onSelectionChanged: (value) async {
                                                    context.read<TeamBloc>().add(
                                                      UpdateSelectedVisibility(
                                                        value,
                                                      ),
                                                    );
                                                    _markHasChanges();
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                Text(
                                                  "Follow All Team's Tickets",
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                SizedBox(height: 5),
                                                CustomFormTile.tileBoolSubTitleText(
                                                  title:
                                                      "Receive notifications whenever tickets are created, rated or discussed on in this team",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(height: _nestedGap),
                                                EditMultiDropdownField(
                                                  fieldName: "Followers",
                                                  items: state.partners ?? [],
                                                  selectedItems:
                                                      state.selectedPartners ??
                                                      [],
                                                  isFieldEdit: true,
                                                  isNotNameShow: true,
                                                  onChanged: (values) {
                                                    context.read<TeamBloc>().add(
                                                      UpdateSelectedPartners(
                                                        values,
                                                      ),
                                                    );
                                                    _markHasChanges();
                                                  },
                                                ),
                                                SizedBox(height: 20),
                                                Row(
                                                  children: [
                                                    MoboCheckbox(
                                                      value: isAssignment,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          isAssignment = value;
                                                        });
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                    SizedBox(width: 10),
                                                    Flexible(
                                                      child: Text(
                                                        "Automatic Assignment",
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600],
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 32,
                                                      ),
                                                  child: CustomFormTile.tileBoolSubTitleText(
                                                    title:
                                                        "Automate the assignment of new tickets to the right people, and make sure all tickets are being handled",
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                if (isAssignment) ...[
                                                  SizedBox(height: _nestedGap),
                                                  EditDropdownField(
                                                    fieldName:
                                                        "Assignment Method",
                                                    items: [
                                                      {
                                                        "id": "balanced",
                                                        "label":
                                                            "Each user has an equal number of open tickets",
                                                      },
                                                      {
                                                        "id": "randomly",
                                                        "label":
                                                            "Each user is assigned an equal number of tickets",
                                                      },
                                                    ],
                                                    selectionValue: state
                                                        .selectedAssignment,
                                                    isFieldEdit: true,
                                                    isSelection: true,
                                                    onSelectionChanged: (value) {
                                                      context.read<TeamBloc>().add(
                                                        UpdateSelectedAssignment(
                                                          value,
                                                        ),
                                                      );
                                                      _markHasChanges();
                                                    },
                                                  ),
                                                  SizedBox(height: _nestedGap),
                                                  EditMultiDropdownField(
                                                    fieldName: "Team Members",
                                                    items: state.members ?? [],
                                                    selectedItems:
                                                        state.selectedMembers ??
                                                        [],
                                                    isFieldEdit: true,
                                                    onChanged: (values) {
                                                      context
                                                          .read<TeamBloc>()
                                                          .add(
                                                            UpdateSelectedMembers(
                                                              values,
                                                            ),
                                                          );
                                                      _markHasChanges();
                                                    },
                                                  ),
                                                ],
                                              ],
                                            )
                                    : (state.partners == null ||
                                          state.members == null)
                                    ? _buildVisibilityShimmer(isDark)
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Visibility & Assignment',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomFormTile.tileTitleText(
                                                title: "Visibility",
                                                isDark: isDark,
                                              ),
                                              SizedBox(height: 10),
                                              CustomFormTile.tileValueText(
                                                value: getVisibilityText(
                                                  team!['privacy_visibility'],
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
                                                title: "Followers",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              team['messagePartners'].isEmpty
                                                  ? buildTagChips(
                                                      team['messagePartners'],
                                                      isDark,
                                                    )
                                                  : Flexible(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildTagChips(
                                                          team['messagePartners'],
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
                                                title: "Assign Method",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              CustomFormTile.tileValueText(
                                                value: getAssignmentMethodText(
                                                  team['assign_method'],
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
                                                title: "Team Members",
                                                isDark: isDark,
                                              ),
                                              SizedBox(width: 40),
                                              team['members'].isEmpty
                                                  ? buildTagChips(
                                                      team['members'],
                                                      isDark,
                                                    )
                                                  : Flexible(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: buildText(
                                                          team['members'],
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
                                // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  (isEdit || widget.isCreate) ? 22 : 11,
                                ),
                                child: (isEdit || widget.isCreate)
                                    ? state.isFormLoading
                                          ? _buildSectionShimmer(
                                              isDark,
                                              rowCount: 3,
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 18.0,
                                                      ),
                                                  child: Text(
                                                    'Channels',
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
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    MoboCheckbox(
                                                      value: isEmailAlias,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          isEmailAlias = value;
                                                        });
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                    SizedBox(width: 10),
                                                    CustomFormTile.tileBoolTitleText(
                                                      title: "Email Alias",
                                                      isDark: isDark,
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 32,
                                                      ),
                                                  child: CustomFormTile.tileBoolSubTitleText(
                                                    title:
                                                        "Create tickets by sending an email to an alias",
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                if (isEmailAlias) ...[
                                                  SizedBox(height: _nestedGap),
                                                  EditControllerField(
                                                    fieldName: 'Alias Name',
                                                    controller:
                                                        aliasNameController,
                                                    isFieldEdit: true,
                                                    onChanged: (_) {
                                                      setState(() {});
                                                    },
                                                  ),
                                                  SizedBox(height: _nestedGap),
                                                  EditDropdownField(
                                                    fieldName: "Alias Domain",
                                                    items:
                                                        state.aliasDomains ??
                                                        [],
                                                    value: state.selectedAlias,
                                                    isFieldEdit: true,
                                                    onChanged: (value) {
                                                      context
                                                          .read<TeamBloc>()
                                                          .add(
                                                            UpdateSelectedAlias(
                                                              value,
                                                            ),
                                                          );
                                                      _markHasChanges();
                                                    },
                                                  ),
                                                  SizedBox(height: _nestedGap),
                                                  EditDropdownField(
                                                    fieldName:
                                                        "Accept Emails From",
                                                    items: [
                                                      {
                                                        "id": "everyone",
                                                        "label": "Everyone",
                                                      },
                                                      {
                                                        "id": "partners",
                                                        "label":
                                                            "Authenticated Partners",
                                                      },
                                                      {
                                                        "id": "followers",
                                                        "label":
                                                            "Followers only",
                                                      },
                                                    ],
                                                    selectionValue:
                                                        state.selectedAliasFrom,
                                                    isFieldEdit: true,
                                                    isSelection: true,
                                                    hintRemove: true,
                                                    onSelectionChanged: (value) {
                                                      context.read<TeamBloc>().add(
                                                        UpdateSelectedAliasFrom(
                                                          value,
                                                        ),
                                                      );
                                                      _markHasChanges();
                                                    },
                                                  ),
                                                ],
                                                const SizedBox(height: 20),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    MoboCheckbox(
                                                      value: isLiveChat,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          isLiveChat = value;
                                                        });
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                    SizedBox(width: 10),
                                                    Flexible(
                                                      child: Text(
                                                        "Live Chat",
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600],
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 32,
                                                      ),
                                                  child: CustomFormTile.tileBoolSubTitleText(
                                                    title:
                                                        "Get in touch with your website visitors. Create and search tickets from your conversations. Answer in an instant by using canned responses.",
                                                    isDark: isDark,
                                                  ),
                                                ),
                                              ],
                                            )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Channels',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          CardHeadingDivider(isDark: isDark),
                                          const SizedBox(height: 20),
                                          if (team!['use_alias'] == true) ...[
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CustomFormTile.tileTitleText(
                                                  title: "Alias",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(height: 10),
                                                CustomFormTile.tileValueText(
                                                  value: getAliasText(
                                                    team['alias_name'],
                                                    team['alias_domain'],
                                                  ),
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CustomFormTile.tileTitleText(
                                                  title: "Accept Emails From",
                                                  isDark: isDark,
                                                ),
                                                SizedBox(height: 10),
                                                CustomFormTile.tileValueText(
                                                  value: getEmailFromText(
                                                    team['alias_contact'],
                                                  ),
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                          ],
                                          if (team['use_website_helpdesk_livechat'] ==
                                              true) ...[
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                CustomFormTile.tileTitleText(
                                                  title: "Live Chat",
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                            if (isEdit ||
                                widget.isCreate ||
                                !(!team!['use_website_helpdesk_form'] &&
                                    !team['use_website_helpdesk_knowledge'] &&
                                    !team['use_website_helpdesk_forum'] &&
                                    !team['use_website_helpdesk_slides']))
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    (isEdit || widget.isCreate) ? 22 : 11,
                                  ),
                                  child: (isEdit || widget.isCreate)
                                      ? state.isFormLoading
                                            ? _buildSectionShimmer(
                                                isDark,
                                                rowCount: 4,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 18.0,
                                                        ),
                                                    child: Text(
                                                      'Help Center',
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
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isWebsiteForm,
                                                        onChanged: (value) {
                                                          // Whatever app the option needs is installed when the team is
                                                          // saved, after asking, as Odoo's own form does.
                                                          setState(() {
                                                            isWebsiteForm =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Website Form",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Get tickets through an online form",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (isWebsiteForm &&
                                                      state
                                                          .isWebsiteInstalled) ...[
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditDropdownField(
                                                      fieldName: "Website",
                                                      items:
                                                          state.website ?? [],
                                                      value:
                                                          state.selectedWebsite,
                                                      isFieldEdit: true,
                                                      onChanged: (value) {
                                                        context
                                                            .read<TeamBloc>()
                                                            .add(
                                                              UpdateSelectedWebsite(
                                                                value,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                  ],
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isKnowledge,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isKnowledge = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Knowledge",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Centralize, manage, share and grow your knowledge library. Allow customers to search your articles in the help center for answers to their questions.",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isCommunityForum,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isCommunityForum =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Community Forum",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Let your customers answer each other's questions on a forum. Allow customers to search your forum posts in the help center for answers to their questions.",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isLearning,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isLearning = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "eLearning",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Share presentations and videos, and organize them into courses. Allow customers to search your eLearning courses in the help center for answers to their questions.",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                ],
                                              )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Help Center',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            CardHeadingDivider(isDark: isDark),
                                            const SizedBox(height: 20),

                                            if (team!['use_website_helpdesk_form'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Website",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(height: 10),
                                                  CustomFormTile.tileValueText(
                                                    value: safeViewText(
                                                      (team['website_id']
                                                                  is List &&
                                                              team['website_id']
                                                                      .length >
                                                                  1)
                                                          ? team['website_id'][1]
                                                          : null,
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_website_helpdesk_knowledge'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Knowledge",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_website_helpdesk_forum'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Community Forum",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_website_helpdesk_slides'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "eLearning",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                            if ((isEdit || widget.isCreate) ||
                                !(!team!['use_helpdesk_timesheet'] &&
                                    !team['use_helpdesk_sale_timesheet']))
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    (isEdit || widget.isCreate) ? 22 : 11,
                                  ),
                                  child: (isEdit || widget.isCreate)
                                      ? state.isFormLoading
                                            ? _buildSectionShimmer(
                                                isDark,
                                                rowCount: 2,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 18.0,
                                                        ),
                                                    child: Text(
                                                      'Track & Bill Time',
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
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isTimesheet,
                                                        onChanged: (value) {
                                                          // Whatever app the option needs is installed when the team is
                                                          // saved, after asking, as Odoo's own form does.
                                                          setState(() {
                                                            isTimesheet = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Timesheets",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Track the time spent on tickets",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (isTimesheet &&
                                                      state
                                                          .isProjectInstalled) ...[
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditDropdownField(
                                                      fieldName: "Project",
                                                      items:
                                                          state.projects ?? [],
                                                      value:
                                                          state.selectedProject,
                                                      isFieldEdit: true,
                                                      onChanged: (value) {
                                                        context
                                                            .read<TeamBloc>()
                                                            .add(
                                                              UpdateSelectedProject(
                                                                value,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                  ],
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isTimeBilling,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isTimeBilling =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Time Billing",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Bill the time spent on your tickets to your customers",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                ],
                                              )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Track & Bill Time',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            CardHeadingDivider(isDark: isDark),
                                            const SizedBox(height: 20),
                                            if (team!['use_helpdesk_timesheet'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Timesheets",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Project",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(height: 10),
                                                  CustomFormTile.tileValueText(
                                                    value: safeViewText(
                                                      (team['project_id']
                                                                  is List &&
                                                              team['project_id']
                                                                      .length >
                                                                  1)
                                                          ? team['project_id'][1]
                                                          : null,
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_helpdesk_sale_timesheet'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Time Billing",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                            if ((isEdit || widget.isCreate) ||
                                !(!team!['use_sla'] == true &&
                                    !team['use_rating']))
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    (isEdit || widget.isCreate) ? 22 : 11,
                                  ),
                                  child: (isEdit || widget.isCreate)
                                      ? state.isFormLoading
                                            ? _buildSectionShimmer(
                                                isDark,
                                                rowCount: 2,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 18.0,
                                                        ),
                                                    child: Text(
                                                      'Performance',
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
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isPolicy,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isPolicy = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "SLA Policies",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Make sure tickets are handled on time",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (isPolicy) ...[
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditDropdownField(
                                                      fieldName:
                                                          "Working Hours",
                                                      items:
                                                          state.resources ?? [],
                                                      value: state
                                                          .selectedResource,
                                                      isFieldEdit: true,
                                                      onChanged: (value) {
                                                        context
                                                            .read<TeamBloc>()
                                                            .add(
                                                              UpdateSelectedResource(
                                                                value,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                  ],
                                                  if (supportsRating) ...[
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        MoboCheckbox(
                                                          value: isRating,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              isRating = value;
                                                            });
                                                            _markHasChanges();
                                                          },
                                                        ),
                                                        SizedBox(width: 10),
                                                        Flexible(
                                                          child: Text(
                                                            "Customer Ratings",
                                                            style: TextStyle(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[400]
                                                                  : Colors
                                                                        .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 32,
                                                          ),
                                                      child: CustomFormTile.tileBoolSubTitleText(
                                                        title:
                                                            "Track customer satisfaction on tickets",
                                                        isDark: isDark,
                                                      ),
                                                    ),
                                                    if (supportsPortalRating &&
                                                        isRating) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          MoboCheckbox(
                                                            value:
                                                                isPortalRating,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                isPortalRating =
                                                                    value;
                                                              });
                                                              _markHasChanges();
                                                            },
                                                          ),
                                                          SizedBox(width: 10),
                                                          Flexible(
                                                            child: Text(
                                                              "Publish this team's ratings on your website",
                                                              style: TextStyle(
                                                                color: isDark
                                                                    ? Colors
                                                                          .grey[400]
                                                                    : Colors
                                                                          .grey[600],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ],
                                              )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Performance',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            CardHeadingDivider(isDark: isDark),
                                            const SizedBox(height: 20),
                                            if (team!['use_sla'] == true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "SLA Policies",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Working Hours",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(height: 10),
                                                  CustomFormTile.tileValueText(
                                                    value: safeViewText(
                                                      (team['resource_calendar_id']
                                                                  is List &&
                                                              team['resource_calendar_id']
                                                                      .length >
                                                                  1)
                                                          ? team['resource_calendar_id'][1]
                                                          : null,
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_rating'] == true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Customer Ratings",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                ),
                              ),

                            if ((isEdit || widget.isCreate) ||
                                !(!team!['allow_portal_ticket_closing'] &&
                                    !team['auto_close_ticket'] == true))
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    (isEdit || widget.isCreate)
                                        ? ((isAutoClosing &&
                                                  supportsReminder &&
                                                  isAutoReminder)
                                              ? 24
                                              : 22) // ends with a field
                                        : 11,
                                  ),
                                  child: (isEdit || widget.isCreate)
                                      ? state.isFormLoading
                                            ? _buildSectionShimmer(
                                                isDark,
                                                rowCount: 2,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 18.0,
                                                        ),
                                                    child: Text(
                                                      'Self-Service',
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
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isTicketClose,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isTicketClose =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Closure by Customers",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Allow your customers to close their own tickets",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isAutoClosing,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isAutoClosing =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      CustomFormTile.tileBoolTitleText(
                                                        title:
                                                            "Automatic Closing",
                                                        isDark: isDark,
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Close inactive tickets automatically",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (isAutoClosing) ...[
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditDropdownField(
                                                      fieldName:
                                                          "Move to Stage",
                                                      items: state.stages ?? [],
                                                      value:
                                                          state.selectedStage,
                                                      isFieldEdit: true,
                                                      onChanged: (value) {
                                                        context
                                                            .read<TeamBloc>()
                                                            .add(
                                                              UpdateSelectedMoveStage(
                                                                value,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditControllerField(
                                                      fieldName:
                                                          'Inactive Period (days)',
                                                      controller:
                                                          inactiveDaysController,
                                                      isFieldEdit: true,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      validator: _daysError,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                      ],
                                                      onChanged: (_) {
                                                        setState(() {});
                                                      },
                                                    ),
                                                    SizedBox(
                                                      height: _nestedGap,
                                                    ),
                                                    EditMultiDropdownField(
                                                      fieldName: "In Stages",
                                                      items: state.stages ?? [],
                                                      selectedItems:
                                                          state
                                                              .selectedInStages ??
                                                          [],
                                                      isFieldEdit: true,
                                                      onChanged: (values) {
                                                        context
                                                            .read<TeamBloc>()
                                                            .add(
                                                              UpdateInStages(
                                                                values,
                                                              ),
                                                            );
                                                        _markHasChanges();
                                                      },
                                                    ),
                                                    // Odoo 20: remind the customer before
                                                    // an inactive ticket is closed.
                                                    if (supportsReminder) ...[
                                                      const SizedBox(
                                                        height: _nestedGap,
                                                      ),
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          MoboCheckbox(
                                                            value:
                                                                isAutoReminder,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                isAutoReminder =
                                                                    value;
                                                              });
                                                              _markHasChanges();
                                                            },
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          CustomFormTile.tileBoolTitleText(
                                                            title:
                                                                "Auto-Close Reminder",
                                                            isDark: isDark,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 32,
                                                            ),
                                                        child: CustomFormTile.tileBoolSubTitleText(
                                                          title:
                                                              "Email customers before their ticket is closed due to inactivity",
                                                          isDark: isDark,
                                                        ),
                                                      ),
                                                      if (isAutoReminder) ...[
                                                        const SizedBox(
                                                          height: _nestedGap,
                                                        ),
                                                        EditControllerField(
                                                          fieldName:
                                                              'Send reminder (days before closure)',
                                                          controller:
                                                              reminderDelayController,
                                                          isFieldEdit: true,
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          validator:
                                                              _reminderError,
                                                          onChanged: (_) {
                                                            setState(() {});
                                                          },
                                                        ),
                                                        const SizedBox(
                                                          height: _nestedGap,
                                                        ),
                                                        EditDropdownField(
                                                          fieldName:
                                                              "Email Template",
                                                          items:
                                                              reminderTemplates,
                                                          value:
                                                              selectedReminderTemplate,
                                                          isFieldEdit: true,
                                                          isRequired: true,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedReminderTemplate =
                                                                  value;
                                                            });
                                                            _markHasChanges();
                                                          },
                                                        ),
                                                      ],
                                                    ],
                                                  ],
                                                ],
                                              )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Self-Service',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            CardHeadingDivider(isDark: isDark),
                                            const SizedBox(height: 20),
                                            if (team!['allow_portal_ticket_closing'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title:
                                                        "Closure by Customers",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['auto_close_ticket'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Automatic Closing",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Move to Stage",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(height: 10),
                                                  CustomFormTile.tileValueText(
                                                    value: safeViewText(
                                                      (team['to_stage_id']
                                                                  is List &&
                                                              team['to_stage_id']
                                                                      .length >
                                                                  1)
                                                          ? team['to_stage_id'][1]
                                                          : null,
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "After",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(width: 40),
                                                  CustomFormTile.tileValueText(
                                                    value:
                                                        '${safeViewText(team['auto_close_day'])} days of inactivity',
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              if (team['auto_close_ticket_reminder'] ==
                                                  true) ...[
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    CustomFormTile.tileTitleText(
                                                      title: "Reminder",
                                                      isDark: isDark,
                                                    ),
                                                    SizedBox(width: 40),
                                                    CustomFormTile.tileValueText(
                                                      value:
                                                          '${safeViewText(team['auto_close_reminder_delay'])} days before closure',
                                                      isDark: isDark,
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    CustomFormTile.tileTitleText(
                                                      title: "Email Template",
                                                      isDark: isDark,
                                                    ),
                                                    SizedBox(width: 40),
                                                    CustomFormTile.tileValueText(
                                                      value: safeViewText(
                                                        (team['reminder_email_template_id']
                                                                    is List &&
                                                                team['reminder_email_template_id']
                                                                        .length >
                                                                    1)
                                                            ? team['reminder_email_template_id'][1]
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "In Stages",
                                                    isDark: isDark,
                                                  ),
                                                  SizedBox(width: 40),
                                                  team['stages'].isEmpty
                                                      ? buildTagChips(
                                                          team['stages'],
                                                          isDark,
                                                        )
                                                      : Flexible(
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: buildTagChips(
                                                              team['stages'],
                                                              isDark,
                                                            ),
                                                          ),
                                                        ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                ),
                              ),

                            if ((isEdit || widget.isCreate) ||
                                !(!team!['use_credit_notes'] == true &&
                                    !team['use_coupons'] == true &&
                                    !team['use_product_returns'] == true &&
                                    !team['use_product_repairs'] == true &&
                                    !team['use_fsm'] == true &&
                                    team['use_giftcards'] != true &&
                                    team['use_product_replacements'] != true))
                              CustomFormTile.tileStyle(
                                bottomMargin: 12,
                                isDark: isDark,
                                child: Padding(
                                  // View mode ends with a trailing 12px row spacer; trim it so top and bottom gaps match.
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    (isEdit || widget.isCreate) ? 22 : 11,
                                  ),
                                  child: (isEdit || widget.isCreate)
                                      ? state.isFormLoading
                                            ? _buildSectionShimmer(
                                                isDark,
                                                rowCount: 5,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 18.0,
                                                        ),
                                                    child: Text(
                                                      'After-Sales',
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
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isRefund,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isRefund = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Refunds",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Issue credits notes",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isCoupon,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isCoupon = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Coupons",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Grant discounts, free products or free shipping",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (supportsGiftcards) ...[
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        MoboCheckbox(
                                                          value: isGiftcard,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              isGiftcard =
                                                                  value;
                                                            });
                                                            _markHasChanges();
                                                          },
                                                        ),
                                                        SizedBox(width: 10),
                                                        Flexible(
                                                          child: Text(
                                                            "Gift Cards",
                                                            style: TextStyle(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[400]
                                                                  : Colors
                                                                        .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 32,
                                                          ),
                                                      child: CustomFormTile.tileBoolSubTitleText(
                                                        title:
                                                            "Reimburse customers with a voucher code for future purchases",
                                                        isDark: isDark,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isReturn,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isReturn = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Returns",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Return faulty products",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  if (supportsReplacements) ...[
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        MoboCheckbox(
                                                          value: isReplacement,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              isReplacement =
                                                                  value;
                                                            });
                                                            _markHasChanges();
                                                          },
                                                        ),
                                                        SizedBox(width: 10),
                                                        Flexible(
                                                          child: Text(
                                                            "Replacements",
                                                            style: TextStyle(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[400]
                                                                  : Colors
                                                                        .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 32,
                                                          ),
                                                      child: CustomFormTile.tileBoolSubTitleText(
                                                        title:
                                                            "Send customers a replacement for a lost, damaged, or returned item",
                                                        isDark: isDark,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isRepair,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isRepair = value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Repairs",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Send broken products for repair",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MoboCheckbox(
                                                        value: isFieldService,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isFieldService =
                                                                value;
                                                          });
                                                          _markHasChanges();
                                                        },
                                                      ),
                                                      SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          "Field Service",
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 32,
                                                        ),
                                                    child: CustomFormTile.tileBoolSubTitleText(
                                                      title:
                                                          "Plan onsite interventions",
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                ],
                                              )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'After-Sales',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            CardHeadingDivider(isDark: isDark),
                                            const SizedBox(height: 20),
                                            if (team!['use_credit_notes'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Refunds",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_coupons'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Coupons",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_giftcards'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Gift Cards",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_product_returns'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Returns",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_product_replacements'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Replacements",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_product_repairs'] ==
                                                true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Repairs",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                            if (team['use_fsm'] == true) ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  CustomFormTile.tileTitleText(
                                                    title: "Field Service",
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isEdit || widget.isCreate)
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
                          onPressed:
                              _checkIfHasChanges() &&
                                  _autoCloseError == null &&
                                  !_preparingSave
                              ? () => _save(context, state)
                              : null,
                          title: isEdit ? "Update Team" : "Create Team",
                          icon: isEdit
                              ? HugeIcons.strokeRoundedTaskEdit01
                              : HugeIcons.strokeRoundedNoteAdd,
                        ),
                      ),
                    ),
                  if (state.isModuleInstallLoading)
                    Center(
                      child: LoadingAnimationWidget.fourRotatingDots(
                        color: AppColors.primary,
                        size: 60,
                      ),
                    ),
                  if (!widget.isCreate && team!['active'] == false)
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

/// Shows [text] clamped to [maxLines] with a "Show more" toggle, but only when
/// it actually overflows, so short descriptions look unchanged.
class _CollapsibleText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const _CollapsibleText({
    required this.text,
    required this.style,
    this.maxLines = 5,
  });

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
