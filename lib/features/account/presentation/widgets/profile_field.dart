import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/mobo/mobo_theme.dart';
import '../../../../core/widgets/saving_overlay.dart';
import '../../../../core/widgets/skeleton.dart';

/// One labelled row of the profile screen, in the reference app's look.
///
/// A grey label above a filled, rounded field. In edit mode a row that has a
/// [controller] becomes a text input (2px brand ring on focus, its validator's
/// message in red beneath); otherwise it shows [value], or "Not set". A
/// read-only row can explain itself on tap ([nonEditableMessage]) and a picker
/// row opens its picker through [onEdit].
class ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isEditing;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String)? validator;
  final VoidCallback? onEdit;
  final VoidCallback? onNonEditableTap;

  const ProfileField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.isEditing,
    this.controller,
    this.keyboardType,
    this.validator,
    this.onEdit,
    this.onNonEditableTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInput = isEditing && controller != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
            ).fontFamily,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        showInput ? _editable(isDark) : _display(isDark),
      ],
    );
  }

  Widget _display(bool isDark) {
    final shown = value.trim().isEmpty || value.trim().toLowerCase() == 'false'
        ? 'Not set'
        : value;
    return GestureDetector(
      onTap: onEdit ?? onNonEditableTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.inputFill(isDark),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isDark ? Colors.white70 : Colors.black,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shown,
                  style: shown == 'Not set'
                      ? AppTheme.fieldHintStyle(isDark)
                      : AppTheme.fieldValueStyle(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editable(bool isDark) {
    final controller = this.controller!;
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.inputFill(isDark),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    width: hasFocus ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: icon,
                        color: isDark ? Colors.white70 : Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          style: AppTheme.fieldValueStyle(isDark),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: controller.text.isEmpty
                                ? 'Enter $label'
                                : null,
                            hintStyle: AppTheme.fieldHintStyle(isDark),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          cursorColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (validator != null)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, v, _) {
                    final message = validator!(v.text);
                    if (message == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Colors.red[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The blocking "Saving..." dialog the reference shows during a write.
void showProfileLoadingDialog(BuildContext context, String message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
        elevation: 8,
        child: SavingCard(message: message),
      ),
    ),
  );
}

/// The Related Company picker: a searchable list of company partners. Pops with
/// the chosen `{id, name}` map, or null on Cancel.
Future<Map<String, dynamic>?> showRelatedCompanyPicker(
  BuildContext context, {
  required Future<List<Map<String, dynamic>>> Function(String query) search,
  required int? selectedId,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final theme = Theme.of(context);
  final searchCtrl = TextEditingController();
  var companies = await search('');
  var loading = false;
  if (!context.mounted) return null;

  final picked = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: AppTheme.surface(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Select Related Company',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                style: AppTheme.fieldValueStyle(isDark),
                decoration: InputDecoration(
                  hintText: 'Search companies...',
                  hintStyle: AppTheme.fieldHintStyle(isDark),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.inputFill(isDark),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (q) async {
                  setDlg(() => loading = true);
                  final result = await search(q);
                  companies = result;
                  if (ctx.mounted) setDlg(() => loading = false);
                },
              ),
              const SizedBox(height: 12),
              // Sized by its content up to 320, and squeezed by the dialog's own
              // height limit on a short screen or with the keyboard up; a fixed
              // 320 overflowed there.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: loading
                      ? const _CompanyListSkeleton()
                      : companies.isEmpty
                      ? SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'No companies found',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: companies.length,
                          separatorBuilder: (_, _) => Divider(
                            height: .01,
                            thickness: .01,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                          itemBuilder: (ctx, i) {
                            final c = companies[i];
                            return ListTile(
                              dense: true,
                              title: Text('${c['name'] ?? ''}'),
                              trailing: c['id'] == selectedId
                                  ? Icon(
                                      Icons.check,
                                      color: theme.primaryColor,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () => Navigator.of(ctx).pop(c),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                minimumSize: const Size(0, 48),
                side: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  // The dialog's field is still animating out when the future completes, so
  // the controller outlives that.
  Future.delayed(const Duration(milliseconds: 400), searchCtrl.dispose);
  return picked;
}

/// Stands in for the company rows while a search runs. Each row is as tall as
/// the dense list tile it replaces (48), so the picker does not change height
/// when the results arrive.
class _CompanyListSkeleton extends StatelessWidget {
  const _CompanyListSkeleton();

  static const _widths = [0.55, 0.4, 0.65, 0.48, 0.58];

  @override
  Widget build(BuildContext context) {
    // Scroll-wrapped, though never scrolled: on a short screen or with the
    // keyboard up the picker is squeezed, and clipping beats overflowing.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final width in _widths)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                child: SkeletonBar(widthFactor: width, height: 14),
              ),
          ],
        ),
      ),
    );
  }
}
