import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/themes/app_colors.dart';
import '../../features/tickets/presentation/widgets/group_items.dart';

/// A rich header widget for list and Kanban views with integrated search, filters,
/// grouping, and pagination controls.
///
/// This widget serves as the top bar for ticket/task listing screens. It includes:
/// * Search field with filter button
/// * Active filter & group indicators (as chips)
/// * Pagination controls with page count and navigation arrows
/// * View switcher (List ↔ Kanban) via popup menu
/// * Loading indicators for search and pagination
///
/// The design is consistent with the rest of the app and fully supports light/dark themes.
class ListKanbanHeaderWidget extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onPressed;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final Map<String, String>? groupMap;
  final String currentPageCount;
  final String totalCount;
  final int displayedCount;
  final int currentPage;

  /// Number of groups when a group by is applied; shown instead of the record
  /// range, as Odoo does.
  final int? groupCount;
  final String title;
  final TextEditingController? controller;
  final bool isSearchLoading;
  final bool isPaginationLoading;
  final bool isKanbanView;
  final bool isSmartView;
  final ValueChanged<bool>? onViewChanged;
  final bool isMoreView;

  const ListKanbanHeaderWidget({
    super.key,
    required this.onNext,
    required this.onPrevious,
    this.onChanged,
    this.onSubmitted,
    this.onPressed,
    required this.selectedFilters,
    this.selectedGroupBy,
    this.groupMap,
    required this.currentPageCount,
    required this.totalCount,
    required this.displayedCount,
    required this.currentPage,
    this.groupCount,
    required this.title,
    this.controller,
    this.isSearchLoading = false,
    this.isPaginationLoading = false,
    this.isKanbanView = false,
    this.isSmartView = false,
    this.onViewChanged,
    this.isMoreView = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasFilters = selectedFilters.isNotEmpty;
    final hasGroupBy = (selectedGroupBy?.isNotEmpty ?? false);

    final isGroupCount = hasGroupBy && groupCount != null;
    int total = int.tryParse(totalCount) ?? 0;

    String? groupDisplayName;
    if (hasGroupBy) {
      groupDisplayName = getGroupTitleFromValue(selectedGroupBy);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: 0.0,
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
          ),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: controller,
                  title: title,
                  isDark: isDark,
                  isSearchLoading: isSearchLoading,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850]! : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(3, 11),
                      blurRadius: 8.5,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: onPressed,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/new_filter.svg',
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white : const Color(0xFF1A1A1A),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                      builder: (context) {
                        if (!hasFilters && !hasGroupBy) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Text(
                              "No filters applied",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasFilters)
                              _buildChip(
                                isDark,
                                "${selectedFilters.length} Active",
                              ),
                            if (hasFilters) ...[const SizedBox(width: 6)],
                            if (hasGroupBy) ...[
                              _buildChip(
                                isDark,
                                groupDisplayName ?? "Group",
                                icon: HugeIcons.strokeRoundedLayer,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    Row(
                      children: [
                        if (!isSmartView && isMoreView) ...[
                          SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minHeight: 35),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton2<String>(
                                value: isKanbanView ? 'Kanban' : 'List',
                                customButton: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isKanbanView
                                          ? Icons.view_kanban
                                          : Icons.menu,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isKanbanView ? 'Kanban' : 'List',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ],
                                ),

                                onChanged: (value) {
                                  if (value != null) {
                                    onViewChanged?.call(value == 'Kanban');
                                  }
                                },

                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  width: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.white,
                                  ),
                                ),

                                items: const ['Kanban', 'List'].map((measure) {
                                  final isKanban = measure == 'Kanban';
                                  final isSelected =
                                      (isKanbanView && isKanban) ||
                                      (!isKanbanView && !isKanban);

                                  return DropdownMenuItem<String>(
                                    value: measure,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.grey.withValues(
                                                      alpha: 0.15,
                                                    ))
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isKanban
                                                ? Icons.view_kanban
                                                : Icons.menu,
                                            size: 20,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            measure,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                        if (isPaginationLoading) ...[
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isDark ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGroupCount)
                                _buildCountBox(isDark)
                              else if (displayedCount > 0)
                                _buildCountBox(isDark),

                              if (!isGroupCount &&
                                  (currentPage > 1 ||
                                      displayedCount < total)) ...[
                                _navButton(
                                  icon: HugeIcons.strokeRoundedArrowLeft01,
                                  enabled: currentPage > 1,
                                  onTap: onPrevious,
                                  isDark: isDark,
                                ),
                                SizedBox(width: 5),
                                _navButton(
                                  icon: HugeIcons.strokeRoundedArrowRight01,
                                  enabled: displayedCount < total,
                                  onTap: onNext,
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(bool isDark, String text, {dynamic icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Text(
        (groupCount != null)
            ? (groupCount == 0 ? "0 / 0" : "1-$groupCount / $groupCount")
            : "$currentPageCount / $totalCount",
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _navButton({
    required dynamic icon,
    required bool enabled,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: HugeIcon(
          icon: icon,
          size: 20,
          color: enabled
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.grey : Colors.grey[400]!),
        ),
      ),
    );
  }
}

/// Search field for the list/Kanban header.
///
/// Owns a [FocusNode] so the hint ("Search by …") is hidden as soon as the
/// field is focused (tapped), and restored when focus is lost while empty.
class _SearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String title;
  final bool isDark;
  final bool isSearchLoading;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SearchField({
    required this.controller,
    required this.title,
    required this.isDark,
    required this.isSearchLoading,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final FocusNode _focusNode = FocusNode();

  /// Stands in when the caller passes no controller, so the clear button can
  /// still tell whether there is text to clear.
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  /// Empties the box and searches again with no text, so the list goes back to
  /// everything the active filters allow. Goes through whichever callback the
  /// screen uses for searching: typing ([ListKanbanHeaderWidget.onChanged]) or
  /// the keyboard's search key ([ListKanbanHeaderWidget.onSubmitted]).
  void _clear() {
    _controller.clear();
    (widget.onChanged ?? widget.onSubmitted)?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850]! : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(3, 11),
            blurRadius: 8.5,
            spreadRadius: -3,
          ),
        ],
      ),
      // Rebuilt on every keystroke so the clear button appears and disappears
      // with the text.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xff1E1E1E),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            // Hide the hint the moment the field is focused (tapped).
            hintText: _focusNode.hasFocus ? '' : 'Search by ${widget.title}',
            hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : const Color(0xFF99A1AF),
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  isDark
                      ? Colors.white.withValues(alpha: 0.70)
                      : const Color(0xFF99A1AF),
                  BlendMode.srcIn,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: widget.isSearchLoading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isDark ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clear,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : const Color(0xFF99A1AF),
                    ),
                  ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
