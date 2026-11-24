import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'mobo/mobo_select_field.dart';

/// Single-select dropdown for edit forms, rendered with the Mobo select field
/// (filled field, searchable panel anchored beneath it).
///
/// Keeps the item-map API the forms already use: items are
/// `Map<String, dynamic>` with an `id` and a `label` / `display_name` / `name`.
/// * [value] selects by object (reported through [onChanged]);
/// * [selectionValue] selects by id string (reported through
///   [onSelectionChanged]) when [isSelection] is true.
/// [isFieldEdit] false shows the field disabled.
class EditDropdownField extends StatelessWidget {
  final dynamic icon;
  final String fieldName;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? value;
  final String? selectionValue;
  final Function(Map<String, dynamic>?)? onChanged;
  final Function(String?)? onSelectionChanged;
  final bool isFieldEdit;
  final bool isSelection;
  final bool idNotNameShow;
  final bool hintRemove;
  final bool isRequired;

  const EditDropdownField({
    super.key,
    this.icon,
    required this.fieldName,
    required this.items,
    this.value,
    this.selectionValue,
    this.onChanged,
    this.onSelectionChanged,
    this.isFieldEdit = false,
    this.isSelection = false,
    this.idNotNameShow = false,
    this.hintRemove = false,
    this.isRequired = false,
  });

  String getDropdownLabel(Map<String, dynamic>? item) {
    if (item == null) return '';
    for (final key in const ['label', 'display_name', 'name']) {
      final v = item[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '_';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ids compared as text: forms mix int ids with string selection keys.
    final wantedId = value != null
        ? value!['id']?.toString()
        : selectionValue?.toString();
    final options = <MoboSelectOption<String>>[
      for (final item in items)
        if (item['id'] != null)
          MoboSelectOption<String>(
            value: item['id'].toString(),
            label: getDropdownLabel(item),
          ),
    ];
    final inOptions = options.any((o) => o.value == wantedId);
    // A value not among the items still shows, by its own label.
    final fallbackLabel = wantedId != null && !inOptions && value != null
        ? getDropdownLabel(value)
        : null;

    Widget? prefix;
    if (icon != null) {
      final color = isDark ? Colors.white70 : Colors.black54;
      prefix = icon is IconData
          ? Icon(icon as IconData, size: 20, color: color)
          : Padding(
              padding: const EdgeInsets.all(12),
              child: HugeIcon(icon: icon, size: 20, color: color),
            );
    }

    return MoboSingleSelectField<String>(
      label: idNotNameShow ? null : fieldName,
      isRequired: isRequired,
      selected: wantedId,
      selectedLabel: fallbackLabel,
      options: options,
      searchable: !isSelection,
      enabled: isFieldEdit,
      allowClear: !isRequired && !isSelection,
      prefixIcon: prefix,
      hintText: hintRemove ? fieldName : 'Select $fieldName',
      panelTitle: fieldName,
      onChanged: (id) {
        final item = id == null
            ? null
            : items.firstWhere(
                (i) => i['id']?.toString() == id,
                orElse: () => <String, dynamic>{},
              );
        if (isSelection) {
          onSelectionChanged?.call(
            item == null ? null : item['id']?.toString(),
          );
        } else {
          onChanged?.call(item == null || item.isEmpty ? null : item);
        }
      },
    );
  }
}
