/// Returns a user-friendly label for the helpdesk team visibility value.
///
/// Supported values:
/// - `invited_internal` → Invited internal users (private)
/// - `internal` → All internal users (company)
/// - `portal` → Invited portal users and all internal users (public)
///
/// Returns `'—'` if the value is null or not recognized.
String getVisibilityText(String? value) {
  switch (value) {
    case 'invited_internal':
      return 'Invited internal users (private)';
    case 'internal':
      return 'All internal users (company)';
    case 'portal':
      return 'Invited portal users and all internal users (public)';
    default:
      return '—';
  }
}

/// Returns a human-readable description of the ticket assignment method.
///
/// Supported values:
/// - `balanced` → Each user has an equal number of open tickets
/// - `randomly` → Each user is assigned an equal number of tickets
///
/// Returns `'—'` if the value is null or not recognized.
String getAssignmentMethodText(String? value) {
  switch (value) {
    case 'balanced':
      return 'Each user has an equal number of open tickets';
    case 'randomly':
      return 'Each user is assigned an equal number of tickets';
    default:
      return '—';
  }
}

/// Returns a readable label for email source configuration.
///
/// Supported values:
/// - `everyone` → Everyone
/// - `partners` → Authenticated Partners
/// - `followers` → Followers Only
/// - `employees` → Authenticated Employees
///
/// Returns `'—'` if the value is null or not recognized.
String getEmailFromText(String? value) {
  switch (value) {
    case 'everyone':
      return 'Everyone';
    case 'partners':
      return 'Authenticated Partners';
    case 'followers':
      return 'Followers Only';
    case 'employees':
      return 'Authenticated Employees';
    default:
      return '—';
  }
}

/// Combines alias name and domain into a single display string.
///
/// Rules:
/// - If both are null/empty → returns `'_'`
/// - If both exist → returns `'$name $domain'`
/// - If only one exists → returns that value
///
/// Example:
/// `getAliasText("support", "@company.com") → "support @company.com"`
String getAliasText(dynamic name, dynamic domain) {
  final aliasName =
      (name == null || name == false || name.toString().trim().isEmpty)
      ? null
      : name.toString();

  final aliasDomain =
      (domain == null || domain == false || domain.toString().trim().isEmpty)
      ? null
      : domain.toString();

  if (aliasName == null && aliasDomain == null) {
    return '_';
  }

  if (aliasName != null && aliasDomain != null) {
    return '$aliasName $aliasDomain';
  }

  return aliasName ?? aliasDomain!;
}
