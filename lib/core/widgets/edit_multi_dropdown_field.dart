import 'package:flutter/material.dart';

import 'mobo/mobo_select_field.dart';

/// Multi-select dropdown for edit forms, rendered with the Mobo multi-select
/// field: selected values as chips, a searchable panel with checkboxes and a
/// Done button.
///
/// Keeps the item-map API the forms already use (`Map<String, dynamic>` with
/// an `id` and a `label` / `display_name` / `name`).
class EditMultiDropdownField extends StatelessWidget {
  final dynamic icon;
  final String fieldName;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> selectedItems;
  final Function(List<Map<String, dynamic>>) onChanged;
  final bool isFieldEdit;
  final bool isNotNameShow;
  final bool isRequired;

  const EditMultiDropdownField({
    super.key,
    this.icon,
    required this.fieldName,
    required this.items,
    this.selectedItems = const [],
    required this.onChanged,
    this.isFieldEdit = false,
    this.isNotNameShow = false,
    this.isRequired = false,
  });

  static String _label(Map<String, dynamic> item) {
    for (final key in const ['label', 'display_name', 'name']) {
      final v = item[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '_';
  }

  @override
  Widget build(BuildContext context) {
    // Selected items may be missing from [items] (a follower outside the
    // loaded page, say); they stay selectable so they are never dropped.
    final byId = <String, Map<String, dynamic>>{
      for (final item in [...items, ...selectedItems])
        if (item['id'] != null) item['id'].toString(): item,
    };

    final field = MoboMultiSelectField<String>(
      label: isNotNameShow ? null : fieldName,
      isRequired: isRequired,
      options: [
        for (final entry in byId.entries)
          MoboSelectOption<String>(
            value: entry.key,
            label: _label(entry.value),
          ),
      ],
      selected: [
        for (final item in selectedItems)
          if (item['id'] != null) item['id'].toString(),
      ],
      hintText: 'Select $fieldName',
      panelTitle: fieldName,
      onChanged: (ids) => onChanged([
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ]),
    );

    // The multi field has no disabled state, so a read-only form swallows taps.
    return isFieldEdit
        ? field
        : IgnorePointer(child: Opacity(opacity: 0.6, child: field));
  }
}
