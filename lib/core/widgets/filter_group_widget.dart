import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/themes/app_colors.dart';
import 'calendar_date_picker.dart';

/// A comprehensive bottom sheet-style widget for filtering and grouping data.
///
/// This widget provides a tabbed interface with two main sections:
/// - **Filter Tab**: Allows users to apply multiple filters (including date pickers)
/// - **Group By Tab**: Allows users to select grouping options with optional date units
///
/// It includes active filter chips, a searchable/filterable UI, date selection support,
/// and bottom action buttons (Clear All + Apply).
///
/// Designed to be used inside a modal bottom sheet or dialog with `setDialogState`
/// for state management.
class FilterGroupWidget extends StatefulWidget {
  final String title;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final List<String> tempFilters;
  final String? tempGroupBy;
  final String? tempDateUnit;
  final Function(void Function()) setDialogState;
  final Map<String, Map<String, String>> filterMap;
  final Map<String, Map<String, dynamic>> groupMap;
  final Map<String, String>? dateUnits;

  final Function(String?) onGroupByChanged;
  final Function(String?) onDateUnitChanged;

  final Map<String, DateTime>? tempSelectedDates;

  const FilterGroupWidget({
    super.key,
    required this.title,
    required this.onClear,
    required this.onSubmit,
    required this.tempFilters,
    this.tempGroupBy,
    this.tempDateUnit,
    required this.setDialogState,
    required this.filterMap,
    required this.groupMap,
    this.dateUnits,

    required this.onGroupByChanged,
    required this.onDateUnitChanged,

    this.tempSelectedDates,
  });

  @override
  State<FilterGroupWidget> createState() => _FilterGroupWidgetState();
}

class _FilterGroupWidgetState extends State<FilterGroupWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() {
          _currentTab = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height:
          MediaQuery.of(context).size.height *
          (MediaQuery.orientationOf(context) == Orientation.landscape
              ? 0.95
              : 0.8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter & Group By',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.setDialogState(() {
                      widget.tempFilters.clear();
                    });
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black54,
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(height: 48, text: "Filter"),
                Tab(height: 48, text: "Group By"),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView(
                    children: [
                      // Inside the list so it scrolls with the filters instead of
                      // taking a fixed slice of a short landscape sheet.
                      _buildActiveSelections(isDark, horizontalPadding: 0),
                      ...widget.filterMap.entries.map((groupEntry) {
                        final groupTitle = groupEntry.key;
                        final filters = groupEntry.value;
                        final isDateGroup = groupTitle == "Date";
                        if (isDateGroup) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                  top: 12,
                                ),
                                child: Text(
                                  groupTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              Column(
                                children: filters.entries.map((entry) {
                                  final label = entry.key;
                                  final tech = entry.value;
                                  final selected = widget.tempFilters.contains(
                                    tech,
                                  );

                                  return InkWell(
                                    onTap: () async {
                                      final pickedDate =
                                          await CustomDatePicker.show(
                                            context: context,
                                            isDark: isDark,
                                            initialDate:
                                                widget.tempSelectedDates?[tech],
                                          );
                                      if (pickedDate != null) {
                                        widget.setDialogState(() {
                                          widget.tempSelectedDates?[tech] =
                                              pickedDate;
                                          widget.tempFilters
                                            ..removeWhere(
                                              (e) => filters.values.contains(e),
                                            )
                                            ..add(tech);
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey[300]!),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedCalendar03,
                                            size: 18,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            (widget.tempSelectedDates?[tech] !=
                                                    null)
                                                ? "$label: ${widget.tempSelectedDates?[tech]?.day}/${widget.tempSelectedDates?[tech]?.month}/${widget.tempSelectedDates?[tech]?.year}"
                                                : label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                                top: 12,
                              ),
                              child: Text(
                                groupTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: filters.entries.map((entry) {
                                final label = entry.key;
                                final tech = entry.value;
                                final selected = widget.tempFilters.contains(
                                  tech,
                                );

                                return FilterChip(
                                  label: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected || isDark
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selected || isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor: AppColors.primary,
                                  // Solid fills, as in the billing app.
                                  backgroundColor: isDark
                                      ? Colors.grey[700]
                                      : Color.alphaBlend(
                                          AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          Colors.white,
                                        ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: selected
                                          ? AppColors.primary
                                          : (isDark
                                                ? Colors.grey[600]!
                                                : Colors.grey[300]!),
                                    ),
                                  ),
                                  checkmarkColor: Colors.white,
                                  onSelected: (val) {
                                    widget.setDialogState(() {
                                      if (val) {
                                        widget.tempFilters.add(tech);
                                      } else {
                                        widget.tempFilters.remove(tech);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      widget.groupMap.isNotEmpty
                          ? Text(
                              'Group ${widget.title} by',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey[200]
                                    : Colors.grey[800],
                              ),
                            )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: widget.groupMap.isEmpty
                            ? Center(
                                child: Text(
                                  'No groups found for ${widget.title}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                              )
                            : ListView(
                                children: widget.groupMap.keys.map((label) {
                                  final groupData = widget.groupMap[label]!;
                                  final tech = groupData["value"];
                                  final description = groupData["description"];
                                  final hasUnits =
                                      groupData["hasUnits"] == true;

                                  final isSelected = widget.tempGroupBy == tech;
                                  final isNone = tech == null;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          widget.setDialogState(() {
                                            widget.onGroupByChanged(tech);
                                            if (hasUnits) {
                                              widget.onDateUnitChanged(
                                                widget.tempDateUnit ?? "day",
                                              );
                                            } else {
                                              widget.onDateUnitChanged(null);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                            left: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : Colors.grey,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      label,
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (description != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                        child: Text(
                                                          description,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: isDark
                                                                ? Colors
                                                                      .grey[400]
                                                                : Colors
                                                                      .grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isNone)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Divider(
                                            thickness: 1,
                                            color: isDark
                                                ? Colors.grey[700]
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      if (hasUnits && isSelected)
                                        ...widget.dateUnits!.keys.map((
                                          unitLabel,
                                        ) {
                                          final unitTech =
                                              widget.dateUnits?[unitLabel];
                                          final unitSelected =
                                              widget.tempDateUnit == unitTech;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              left: 40,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    widget.setDialogState(() {
                                                      widget.onDateUnitChanged(
                                                        unitTech,
                                                      );
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 6,
                                                          horizontal: 8,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          unitSelected
                                                              ? Icons
                                                                    .radio_button_checked
                                                              : Icons
                                                                    .radio_button_unchecked,
                                                          color: unitSelected
                                                              ? AppColors
                                                                    .primary
                                                              : Colors.grey,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          unitLabel,
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                      .black87,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              math.max(20.0, MediaQuery.of(context).padding.bottom + 8),
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSelections(bool isDark, {double horizontalPadding = 20}) {
    final Map<String, List<String>> groupedActiveFilters = {};
    final activeText = HSLColor.fromColor(
      AppColors.primary,
    ).withLightness(0.62).toColor();

    widget.filterMap.forEach((groupName, filters) {
      List<String> activeInGroup = [];

      if (groupName == "Date") {
        filters.forEach((label, tech) {
          if (widget.tempSelectedDates?.containsKey(tech) ?? false) {
            activeInGroup.add(
              "$label: ${widget.tempSelectedDates?[tech]?.day}/${widget.tempSelectedDates?[tech]?.month}/${widget.tempSelectedDates?[tech]?.year}",
            );
          }
        });
      } else {
        filters.forEach((label, tech) {
          if (widget.tempFilters.contains(tech)) {
            activeInGroup.add(label);
          }
        });
      }

      if (activeInGroup.isNotEmpty) {
        groupedActiveFilters[groupName] = activeInGroup;
      }
    });

    if (groupedActiveFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groupedActiveFilters.entries.map((entry) {
              final groupName = entry.key;
              final items = entry.value;
              final count = items.length;

              // Content-sized like Mobo Events' active-filter chip (12×6 padding,
              // no Material Chip minimum height / extra delete-icon padding).
              final text = isDark ? activeText : AppColors.primary;
              return GestureDetector(
                onTap: () {
                  widget.setDialogState(() {
                    if (groupName == "Date") {
                      widget.filterMap["Date"]?.values.forEach((tech) {
                        widget.tempSelectedDates!.remove(tech);
                        widget.tempFilters.remove(tech);
                      });
                    } else {
                      widget.filterMap[groupName]?.values.forEach((tech) {
                        widget.tempFilters.remove(tech);
                      });
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    // Solid fills: a translucent tint lets the sheet show
                    // through.
                    color: isDark
                        ? Color.alphaBlend(
                            AppColors.primary.withValues(alpha: 0.3),
                            const Color(0xFF1E1E1E),
                          )
                        : Color.alphaBlend(
                            AppColors.primary.withValues(alpha: 0.08),
                            Colors.white,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$groupName ($count)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedMultiplicationSign,
                        size: 14,
                        color: text,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
