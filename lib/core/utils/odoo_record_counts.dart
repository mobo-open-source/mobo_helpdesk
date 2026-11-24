import '../session/company_session_manager.dart';

/// Reads count fields the way Odoo's own forms show them.
///
/// A count such as a customer's other tickets, a team's open tickets or an SLA
/// policy's tickets is computed by searching for records, and a search honours
/// `active_test` in the request's context. The forms read a record with
/// `active_test: false` so an archived one can still be opened, which makes
/// these counts include archived records as well: the app showed 3 tickets
/// where Odoo showed 2, the extra one being archived.
///
/// Reading the counts in a request of their own, without that context, gives
/// the numbers Odoo shows.
class OdooRecordCounts {
  const OdooRecordCounts._();

  /// The values of [fields] of record [id] of [model], as Odoo's form shows
  /// them. Empty when they cannot be read: counts only inform, so the values
  /// already read stay in place.
  static Future<Map<String, dynamic>> read(
    String model,
    int id,
    List<String> fields,
  ) async {
    if (fields.isEmpty) return {};
    try {
      final rows = await CompanySessionManager.callKwWithCompany({
        'model': model,
        'method': 'read',
        'args': [
          [id],
          fields,
        ],
        'kwargs': {},
      });
      if (rows is List && rows.isNotEmpty && rows.first is Map) {
        return Map<String, dynamic>.from(rows.first as Map)..remove('id');
      }
    } catch (_) {
      // Fall back to what the main read returned.
    }
    return {};
  }
}
