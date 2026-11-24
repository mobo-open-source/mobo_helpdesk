import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobo_helpdesk/core/widgets/empty_lottie.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/profile_image.dart';
import '../../../../di/injection_container.dart';
import '../bloc/account_bloc.dart';
import '../widgets/edit_address_widget.dart';
import '../widgets/profile_field.dart';
import '../widgets/profile_shimmer.dart';

/// Profile screen of the application.
///
/// Displays and manages user profile information including:
/// - Personal details (name, email, phone, mobile)
/// - Profile image update
/// - Address management
/// - Profile editing and saving
///
/// Also integrates with [AccountBloc] for state management and
/// handles profile update, image selection, and navigation to
/// configuration screen.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountBloc>(
      create: (_) => sl<AccountBloc>()..add(ProfileDataLoad()),
      child: const ProfileInitializer(),
    );
  }
}

class ProfileInitializer extends StatefulWidget {
  const ProfileInitializer({super.key});

  @override
  State<ProfileInitializer> createState() => _ProfileInitializerState();
}

class _ProfileInitializerState extends State<ProfileInitializer> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _websiteController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _street1Controller = TextEditingController();
  final _street2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  int? partnerId;
  bool isInitialized = false;
  bool isEditing = false;
  bool _savingDialogOpen = false;
  Uint8List? imageBytes;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _jobTitleController.dispose();
    _street1Controller.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- validation

  String? _nameError(String value) =>
      value.trim().isEmpty ? 'Name is required' : null;

  String? _emailError(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(v)
        ? null
        : 'Please enter a valid email address';
  }

  String? _websiteError(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return RegExp(
          r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:\d+)?(\/\S*)?$',
        ).hasMatch(v)
        ? null
        : 'Please enter a valid website URL';
  }

  // ---------------------------------------------------------------- changes

  Uint8List? _savedImage(dynamic profile) {
    final String raw = profile.image;
    final cleaned = raw.contains(',') ? raw.split(',').last : raw;
    return cleaned.isNotEmpty ? base64Decode(cleaned) : null;
  }

  bool _compareImages(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The text fields that differ from the loaded profile, by event key.
  Map<String, String> _changedText(dynamic profile) {
    final current = {
      'name': (_nameController.text, profile.name as String),
      'mail': (_emailController.text, profile.mail as String),
      'phone': (_phoneController.text, profile.phone as String),
      'mobile': (_mobileController.text, profile.mobile as String),
      'website': (_websiteController.text, profile.website as String),
      'function': (_jobTitleController.text, profile.function as String),
    };
    return {
      for (final e in current.entries)
        if (e.value.$1.trim() != e.value.$2.trim()) e.key: e.value.$1.trim(),
    };
  }

  /// A photo picked this session that differs from the saved one.
  bool _imageChanged(AccountState state) =>
      state.data != null &&
      state.profileImageBytes != null &&
      !_compareImages(_savedImage(state.data), state.profileImageBytes);

  bool _hasChanges(AccountState state) =>
      state.data != null &&
      (_changedText(state.data).isNotEmpty || _imageChanged(state));

  /// Save is offered only once something differs from the loaded profile and
  /// every field passes its validator.
  bool _canSave(AccountState state) =>
      _hasChanges(state) &&
      _nameError(_nameController.text) == null &&
      _emailError(_emailController.text) == null &&
      _websiteError(_websiteController.text) == null;

  void _seedControllers(dynamic profile) {
    _nameController.text = profile.name;
    _emailController.text = profile.mail;
    _phoneController.text = profile.phone;
    _mobileController.text = profile.mobile;
    _websiteController.text = profile.website;
    _jobTitleController.text = profile.function;
    partnerId = profile.partnerId;
  }

  void _cancelEdit() {
    final bloc = context.read<AccountBloc>();
    final profile = bloc.state.data;
    if (profile != null) _seedControllers(profile);
    bloc.add(const ClearPickedImage());
    setState(() => isEditing = false);
  }

  void _save() {
    final bloc = context.read<AccountBloc>();
    final profile = bloc.state.data;
    if (profile == null) return;
    final changed = _changedText(profile);
    // Stay in edit mode until the server accepts the write, so a failed save
    // keeps the user's input instead of showing it as if it were saved.
    bloc.add(
      UpdateProfile(
        partnerId: partnerId,
        name: changed['name'],
        mail: changed['mail'],
        phone: changed['phone'],
        mobile: changed['mobile'],
        website: changed['website'],
        function: changed['function'],
        image: _imageChanged(bloc.state)
            ? base64Encode(bloc.state.profileImageBytes!)
            : null,
      ),
    );
  }

  Future<void> _handleBack() async {
    final navigator = Navigator.of(context);
    if (isEditing && _hasChanges(context.read<AccountBloc>().state)) {
      final shouldLeave = await ConfirmationDialogWidget.show(
        context: context,
        title: 'Discard Changes?',
        subTitle: 'You have unsaved changes. Do you want to discard them?',
        negativeButtonText: 'Keep Editing',
        positiveButtonText: 'Discard',
      );
      if (shouldLeave != true) return;
    }
    // Configuration is the page underneath, so leaving is a plain pop.
    navigator.pop();
  }

  // ---------------------------------------------------------------- dialogs

  void _showImageSourceActionSheet() {
    final parentContext = context;
    final bloc = context.read<AccountBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(parentContext).scaffoldBackgroundColor,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            InkWell(
              onTap: () {
                Navigator.pop(bottomSheetContext);
                bloc.add(const PickImageEvent(ImageSource.camera));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCamera02,
                      size: 24,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Take Photo",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(),

            InkWell(
              onTap: () {
                Navigator.pop(bottomSheetContext);
                bloc.add(const PickImageEvent(ImageSource.gallery));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedImageCrop,
                      size: 24,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Choose from Gallery",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  int? _idOf(dynamic many2one) =>
      many2one is List && many2one.isNotEmpty ? many2one[0] as int? : null;

  String? _nameOf(dynamic many2one) =>
      many2one is List && many2one.length > 1 && many2one[1] != null
      ? many2one[1].toString()
      : null;

  /// Street, street 2, city, state, ZIP, country - whatever is set.
  String _formatAddress(dynamic p) {
    final parts = <String>[
      if ((p.street as String).isNotEmpty) p.street,
      if ((p.street2 as String).isNotEmpty) p.street2,
      if ((p.city as String).isNotEmpty) p.city,
      ?_nameOf(p.stateId),
      if ((p.zip as String).isNotEmpty) p.zip,
      ?_nameOf(p.countryId),
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address set';
  }

  Future<void> _showEditPopup() async {
    final bloc = context.read<AccountBloc>();
    final profile = bloc.state.data;
    if (profile == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: EditAddressWidget(
            street1Controller: _street1Controller,
            street2Controller: _street2Controller,
            cityController: _cityController,
            zipController: _zipController,
            initialCountryId: _idOf(profile.countryId),
            initialStateId: _idOf(profile.stateId),
          ),
        );
      },
    );
  }

  Future<void> _showRelatedCompanyPicker() async {
    final bloc = context.read<AccountBloc>();
    final profile = bloc.state.data;
    if (profile == null) return;
    final picked = await showRelatedCompanyPicker(
      context,
      search: bloc.profileUseCase.searchCompanies,
      selectedId: _idOf(profile.parentId),
    );
    if (picked == null) return;
    bloc.add(
      UpdateRelatedCompany(
        partnerId: partnerId,
        companyId: picked['id'] as int?,
      ),
    );
  }

  // ------------------------------------------------------------------ build

  Widget _profilePhoto(bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              ProfileImage(
                avatarBytes: imageBytes,
                isSvg: imageBytes != null && isSvgBytes(imageBytes!),
                size: 100,
                isProfile: true,
                backgroundColor: AppColors.primary,
              ),
              if (isEditing)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: InkWell(
                    onTap: _showImageSourceActionSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[900]! : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera02,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          BlocBuilder<AccountBloc, AccountState>(
            buildWhen: (a, b) => a.data?.name != b.data?.name,
            builder: (context, state) {
              final name = state.data?.name ?? '';
              if (name.isEmpty) return const SizedBox.shrink();
              return Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.grey[400] : Colors.grey[800],
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? Colors.grey[900]! : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: barColor,
        appBar: AppBar(
          title: Text(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            onPressed: _handleBack,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: barColor,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _cancelEdit,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            // Rebuilt on every keystroke, so Save lights up as soon as a field
            // differs from the loaded profile and dims again when the edit is
            // undone or a required field is emptied.
            ListenableBuilder(
              listenable: Listenable.merge([
                _nameController,
                _emailController,
                _phoneController,
                _mobileController,
                _websiteController,
                _jobTitleController,
              ]),
              builder: (context, _) {
                final state = context.watch<AccountBloc>().state;
                final canSave = !isEditing || _canSave(state);
                return TextButton(
                  onPressed: state.data == null || !canSave
                      ? null
                      : () => isEditing
                            ? _save()
                            : setState(() => isEditing = true),
                  child: Text(
                    isEditing ? 'Save' : 'Edit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: !canSave || state.data == null
                          ? (isDark ? Colors.grey[600] : Colors.grey[400])
                          : AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: MultiBlocListener(
          listeners: [
            // Message snackbars.
            BlocListener<AccountBloc, AccountState>(
              listenWhen: (prev, curr) =>
                  curr.message != null && curr.message != prev.message,
              listener: (context, state) {
                if (state.isError == true) {
                  CustomSnackBar.showError(context, state.message!);
                }
                if (state.isSuccess == true) {
                  CustomSnackBar.showSuccess(context, state.message!);
                  setState(() {
                    isInitialized = false;
                    isEditing = false;
                  });
                }
                if (state.isInfo == true) {
                  CustomSnackBar.showInfo(context, state.message!);
                }
                context.read<AccountBloc>().add(ClearAccountMessage());
              },
            ),
            // The blocking dialog for a write in flight.
            BlocListener<AccountBloc, AccountState>(
              listenWhen: (prev, curr) => prev.isSaving != curr.isSaving,
              listener: (context, state) {
                if (state.isSaving && !_savingDialogOpen) {
                  _savingDialogOpen = true;
                  showProfileLoadingDialog(context, state.savingLabel);
                } else if (!state.isSaving && _savingDialogOpen) {
                  _savingDialogOpen = false;
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
            ),
          ],
          child: BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const ProfileShimmer();
              }
              if (state.error != null) {
                final error = state.error!;
                return ErrorLottie(
                  title: error['title'] ?? 'Error',
                  subTitle:
                      error['description'] ??
                      'Something went wrong. Please try again later',
                  onPressed: () async {
                    context.read<AccountBloc>().add(ProfileDataLoad());
                    AppBootstrapper.reloadAppBlocs(context);
                    await context.read<CompanyProvider>().initialize();
                  },
                );
              }
              if (state.data == null) {
                return const EmptyLottie(title: "No profile data available");
              }

              final profile = state.data!;
              imageBytes = state.profileImageBytes ?? _savedImage(profile);

              if (!isInitialized) {
                _seedControllers(profile);
                isInitialized = true;
              }
              _street1Controller.text = profile.street;
              _street2Controller.text = profile.street2;
              _cityController.text = profile.city;
              _zipController.text = profile.zip;

              return RefreshIndicator(
                onRefresh: () async {
                  isInitialized = false;
                  context.read<AccountBloc>().add(ProfileDataLoad());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profilePhoto(isDark),
                      const SizedBox(height: 32),
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ProfileField(
                        label: 'Full Name',
                        value: _nameController.text,
                        icon: HugeIcons.strokeRoundedUserAccount,
                        isEditing: isEditing,
                        controller: _nameController,
                        validator: _nameError,
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Email',
                        value: _emailController.text,
                        icon: HugeIcons.strokeRoundedMail01,
                        isEditing: isEditing,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailError,
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Phone',
                        value: _phoneController.text,
                        icon: HugeIcons.strokeRoundedCall02,
                        isEditing: isEditing,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Mobile',
                        value: _mobileController.text,
                        icon: HugeIcons.strokeRoundedSmartPhone01,
                        isEditing: isEditing,
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Website',
                        value: _websiteController.text,
                        icon: HugeIcons.strokeRoundedWebDesign02,
                        isEditing: isEditing,
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                        validator: _websiteError,
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Job Title',
                        value: _jobTitleController.text,
                        icon: HugeIcons.strokeRoundedWorkHistory,
                        isEditing: isEditing,
                        controller: _jobTitleController,
                      ),
                      const SizedBox(height: 16),
                      // Read-only: tapping explains why, as in the reference.
                      ProfileField(
                        label: 'Company',
                        value: _nameOf(profile.companyId) ?? '',
                        icon: HugeIcons.strokeRoundedBuilding05,
                        isEditing: isEditing,
                        onNonEditableTap: () => CustomSnackBar.showInfo(
                          context,
                          'Company cannot be modified from this screen',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ProfileField(
                        label: 'Related Company',
                        value: _nameOf(profile.parentId) ?? '',
                        icon: HugeIcons.strokeRoundedBuilding01,
                        isEditing: isEditing,
                        onEdit: isEditing ? _showRelatedCompanyPicker : null,
                      ),
                      const SizedBox(height: 20),
                      ProfileField(
                        label: 'Address',
                        value: _formatAddress(profile),
                        icon: HugeIcons.strokeRoundedLocation05,
                        isEditing: isEditing,
                        onEdit: isEditing ? _showEditPopup : null,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
