import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../../domain/entities/profile_entity.dart';
import '../models/profile_model.dart';

/// Contract for profile-related remote operations.
///
/// Defines methods for fetching and updating user profile data,
/// along with retrieving country and state information from the backend.
abstract class ProfileRemoteDatasource {
  /// Fetches the logged-in user's profile details.
  Future<ProfileEntity> loadProfile();

  /// Retrieves the list of countries.
  Future<List<Map<String, dynamic>>> loadCountry();

  /// Retrieves the list of states for a given country.
  Future<List<Map<String, dynamic>>> loadState(int countryId);

  /// Company partners whose name matches [query], for the Related Company
  /// picker.
  Future<List<Map<String, dynamic>>> searchCompanies(String query);

  /// Updates user details with given data and ID.
  Future<Map<String, dynamic>> updateUserDetails(
    Map<String, dynamic> data,
    int id,
  );
}

class ProfileRemoteDatasourceImpl implements ProfileRemoteDatasource {
  /// Loads user profile data from the server.
  ///
  /// - Retrieves user ID and server version from [SharedPreferences].
  /// - Asks the server which mobile field the database has.
  /// - Calls `res.users`,`search_read` to fetch profile data.
  ///
  /// Throws:
  /// - Parsed Odoo errors using [extractOdooError]
  /// - Network-related errors (connection refused, unreachable)
  /// - Generic error if something unexpected occurs
  @override
  Future<ProfileEntity> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      // Which field holds each number is asked of the server, never guessed
      // from the version: Mobile and Phone may live on `res.partner` or on
      // `res.users` (hr's work fields), and naming a field a model does not
      // have fails the whole read.
      final mobile = await _resolveMobile();
      final phone = await _resolvePhone();
      final partnerFields = await _partnerFieldNames();

      Future<dynamic> readUser(List<String> fields) =>
          CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [userId],
              fields,
            ],
            'kwargs': {},
          });

      dynamic response;
      try {
        response = await readUser(await _profileUserFields());
      } on OdooException {
        // A field the server refused: forget the discovered list and read the
        // essentials, which every account may read.
        _userReadFieldsCache = null;
        response = await readUser(_fallbackUserFields);
      }

      final Map<String, dynamic> json = Map<String, dynamic>.from(response[0]);

      // Only fields this server defines: one unknown name rejects the read.
      final partnerRead = <String>[
        for (final f in _wantedPartnerFields)
          if (partnerFields.isEmpty || partnerFields.contains(f)) f,
        if (mobile != null && mobile.model == 'res.partner') mobile.name,
        if (phone != null && phone.model == 'res.partner') phone.name,
      ];
      final partner = json['partner_id'];
      Map<String, dynamic> partnerData = {};
      if (partner is List && partner.isNotEmpty && partnerRead.isNotEmpty) {
        try {
          final rows = await CompanySessionManager.callKwWithCompany({
            'model': 'res.partner',
            'method': 'read',
            'args': [
              [partner[0]],
              partnerRead,
            ],
            'kwargs': {},
          });
          if (rows is List && rows.isNotEmpty) {
            partnerData = Map<String, dynamic>.from(rows.first as Map);
          }
        } catch (_) {
          // The profile still opens on the user's own values if the partner
          // read is refused.
        }
      }
      if (partnerData.isNotEmpty) {
        for (final f in _wantedPartnerFields) {
          json[f] = partnerData[f];
        }
      }

      Future<String> numberOf(_ResolvedField? field) async {
        if (field == null) return '';
        final value = field.model == 'res.users'
            ? await _readUserField(userId, field.name)
            : partnerData[field.name];
        final text = value?.toString() ?? '';
        return (text.isEmpty || text == 'false') ? '' : text;
      }

      json['mobile'] = await numberOf(mobile);
      json['phone'] = await numberOf(phone);
      json['has_mobile_field'] = mobile != null;
      json['has_phone_field'] = phone != null;

      return ProfileModel.fromJson(json);
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      throw errorMsg;
    } catch (e) {
      final errorText = e.toString().toLowerCase();

      if (errorText.contains('connection refused')) {
        throw {
          'title': 'Connection Refused',
          'description':
              'Please contact your administrator to restart the server.',
        };
      }

      if (errorText.contains('connection failed') ||
          errorText.contains('network is unreachable')) {
        throw {
          'title': 'Network Error',
          'description':
              'Please check your network connection and restart after enabling it.',
        };
      }
      throw {
        'title': 'Something went wrong',
        'description': 'Error fetching profile, Please try again later.',
      };
    }
  }

  /// Fetches all countries from the server.
  ///
  /// Calls `res.country`, `search_read` and returns
  /// a sorted list of countries by name.
  ///
  /// Throws a simple error message if the request fails.
  @override
  Future<List<Map<String, dynamic>>> loadCountry() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching countries';
    }
  }

  /// Fetches states filtered by [countryId].
  ///
  /// Calls `res.country.state`, `search_read`
  /// and filters results based on the provided country ID.
  ///
  /// Throws a simple error message if the request fails.
  @override
  Future<List<Map<String, dynamic>>> loadState(int countryId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country.state',
        'method': 'search_read',
        'args': [
          [
            ['country_id', '=', countryId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching countries';
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    try {
      final domain = [
        ['is_company', '=', true],
        if (query.trim().isNotEmpty) ['name', 'ilike', query.trim()],
      ];
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name'],
          'limit': 20,
          'order': 'name asc',
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Updates user details in the backend.
  ///
  /// - Calls `res.partner.write` to update user-related fields.
  /// - Uses [data] as the payload and [id] as the record identifier.
  ///
  /// Returns:
  /// - `{ success: true }` if update succeeds
  /// - `{ success: false, error: message }` if unexpected failure occurs
  ///
  /// Throws:
  /// - Parsed Odoo error message if validation fails
  @override
  Future<Map<String, dynamic>> updateUserDetails(
    Map<String, dynamic> data,
    int id,
  ) async {
    try {
      final partnerData = Map<String, dynamic>.from(data);
      final userData = <String, dynamic>{};

      // `mobile` and `phone` are canonical keys; each is written to whichever
      // model and field this server keeps it on, or dropped when it has none.
      for (final entry in {
        'mobile': await (partnerData.containsKey('mobile')
            ? _resolveMobile()
            : Future<_ResolvedField?>.value(null)),
        'phone': await (partnerData.containsKey('phone')
            ? _resolvePhone()
            : Future<_ResolvedField?>.value(null)),
      }.entries) {
        if (!partnerData.containsKey(entry.key)) continue;
        final value = partnerData.remove(entry.key);
        final field = entry.value;
        if (field == null) continue;
        (field.model == 'res.users' ? userData : partnerData)[field.name] =
            value;
      }

      // Fields a user may write on their own `res.users` record go there:
      // `res.users.write` bypasses access rights only for these, whereas
      // `res.partner` write needs partner-manager rights an ordinary helpdesk
      // user lacks.
      final prefs0 = await SharedPreferences.getInstance();
      final major =
          int.tryParse(
            RegExp(r'\d+')
                    .firstMatch(prefs0.getString('serverVersion') ?? '')
                    ?.group(0) ??
                '',
          ) ??
          18;
      final selfWritable = {
        'signature',
        'action_id',
        'company_id',
        'email',
        'name',
        'image_1920',
        'lang',
        'tz',
        if (major >= 19) 'phone',
      };
      for (final key in selfWritable) {
        if (partnerData.containsKey(key)) {
          userData[key] = partnerData.remove(key);
        }
      }

      // Address writes send only fields the server defines.
      final known = await _partnerFieldNames();
      if (known.isNotEmpty) {
        partnerData.removeWhere(
          (key, _) =>
              _wantedPartnerFields.contains(key) && !known.contains(key),
        );
      }

      dynamic result = true;
      if (userData.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        result = await CompanySessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [prefs.getInt('userId') ?? 0],
            userData,
          ],
          'kwargs': {},
        });
      }
      if (partnerData.isNotEmpty) {
        result = await CompanySessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'write',
          'args': [
            [id],
            partnerData,
          ],
          'kwargs': {},
        });
      }
      return {'success': result == true, 'error': null};
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';

      throw errorMsg.toString();
    } catch (e) {
      return {
        'success': false,
        'error': "Something went wrong, Please try again later.",
      };
    }
  }

  // ------------------------------------------------------ field resolution

  static const List<String> _wantedPartnerFields = [
    'street',
    'street2',
    'city',
    'zip',
    'state_id',
    'country_id',
    'parent_id',
  ];

  /// `res.users` fields read when the server's own field list can't be
  /// discovered, or a read of it is refused.
  static const List<String> _fallbackUserFields = [
    'name',
    'partner_id',
    'email',
    'contact_address',
    'company_id',
    'image_1920',
    'website',
    'function',
  ];

  // Resolutions are scoped to the signed-in account: the datasource outlives
  // logins, and a name valid on one server is rejected by another.
  static String? _cacheAccount;
  static Set<String>? _partnerFieldsCache;
  static Map<String, Map<String, dynamic>>? _usersDescribeCache;
  static List<String>? _userReadFieldsCache;
  static _ResolvedField? _mobileCache;
  static bool _mobileResolved = false;
  static _ResolvedField? _phoneCache;
  static bool _phoneResolved = false;

  Future<void> _scopeCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        '${prefs.getString('url')}|${prefs.getString('database')}|${prefs.getInt('userId')}';
    if (key != _cacheAccount) {
      _cacheAccount = key;
      _partnerFieldsCache = null;
      _usersDescribeCache = null;
      _userReadFieldsCache = null;
      _mobileCache = null;
      _mobileResolved = false;
      _phoneCache = null;
      _phoneResolved = false;
    }
  }

  /// `fields_get` of [model], keyed by field name. Throws on RPC failure so a
  /// dropped connection is retried rather than read as "field absent".
  Future<Map<String, Map<String, dynamic>>> _describe(String model) async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [
        <String>[],
        ['type', 'related'],
      ],
      'kwargs': const {},
    });
    if (result is! Map) return const {};
    return result.map(
      (k, v) => MapEntry(
        '$k',
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
      ),
    );
  }

  /// `res.users` `fields_get`, fetched once per account: the field list, the
  /// mobile and the phone resolution all read from it.
  Future<Map<String, Map<String, dynamic>>> _describeUsers() async {
    await _scopeCaches();
    final cached = _usersDescribeCache;
    if (cached != null) return cached;
    final described = await _describe('res.users');
    if (described.isNotEmpty) _usersDescribeCache = described;
    return described;
  }

  /// The `res.users` fields the profile reads.
  ///
  /// Asked of the server instead of reading every field: a bare read also
  /// requests columns such as hr's `category_ids`, which an ordinary user may
  /// not read, and one refused field fails the whole read. One2many and
  /// many2many columns, binaries other than the photo, and hr's
  /// employee-backed fields are left out. The last are read on their own, see
  /// [_readUserField].
  Future<List<String>> _profileUserFields() async {
    await _scopeCaches();
    final cached = _userReadFieldsCache;
    if (cached != null) return cached;
    try {
      final described = await _describeUsers();
      const skippedTypes = {'one2many', 'many2many'};
      final fields = <String>[];
      described.forEach((name, describe) {
        final type = describe['type']?.toString() ?? '';
        if (skippedTypes.contains(type)) return;
        if (type == 'binary' && name != 'image_1920') return;
        if (_isEmployeeBacked(describe)) return;
        fields.add(name);
      });
      if (fields.isEmpty) return _fallbackUserFields;
      fields.sort();
      return _userReadFieldsCache = fields;
    } catch (_) {
      return _fallbackUserFields;
    }
  }

  Future<Set<String>> _partnerFieldNames() async {
    await _scopeCaches();
    final cached = _partnerFieldsCache;
    if (cached != null) return cached;
    try {
      final names = (await _describe('res.partner')).keys.toSet();
      if (names.isNotEmpty) _partnerFieldsCache = names;
      return names;
    } catch (_) {
      return {};
    }
  }

  bool _isEmployeeBacked(Map<String, dynamic> describe) {
    final related = describe['related'];
    if (related is String) return related.startsWith('employee_id.');
    if (related is List && related.isNotEmpty) {
      return '${related.first}' == 'employee_id';
    }
    return false;
  }

  /// hr's employee-backed `res.users` fields write onto the user's employee;
  /// with none linked the write hits an empty recordset and is silently lost.
  Future<bool> _hasLinkedEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'read',
      'args': [
        [prefs.getInt('userId') ?? 0],
        ['employee_id'],
      ],
      'kwargs': const {},
    });
    if (rows is! List || rows.isEmpty) return false;
    final value = (rows.first as Map)['employee_id'];
    return value is List && value.isNotEmpty;
  }

  Future<_ResolvedField?> _firstUserField(
    Map<String, Map<String, dynamic>> userFields,
    List<String> candidates,
  ) async {
    for (final name in candidates) {
      final describe = userFields[name];
      if (describe == null) continue;
      if (_isEmployeeBacked(describe) && !await _hasLinkedEmployee()) continue;
      return _ResolvedField(name, 'res.users');
    }
    return null;
  }

  /// Mobile: `res.partner` first (where Odoo's contact form keeps it), then
  /// hr's `res.users.mobile_phone`, which is all Odoo 19 has.
  Future<_ResolvedField?> _resolveMobile() async {
    await _scopeCaches();
    if (_mobileResolved) return _mobileCache;
    try {
      final partnerFields = await _describe('res.partner');
      for (final name in const [
        'mobile',
        'mobile_phone',
        'x_studio_mobile_phone',
      ]) {
        if (partnerFields.containsKey(name)) {
          _mobileCache = _ResolvedField(name, 'res.partner');
          _mobileResolved = true;
          return _mobileCache;
        }
      }
      final userFields = await _describeUsers();
      _mobileCache = await _firstUserField(userFields, const [
        'mobile_phone',
        'x_studio_mobile_phone',
      ]);
      // The Mobile row is always shown, so a server whose only field is hr's
      // employee-backed one still gets it even with no employee linked.
      if (_mobileCache == null) {
        for (final name in const ['mobile_phone', 'x_studio_mobile_phone']) {
          if (userFields.containsKey(name)) {
            _mobileCache = _ResolvedField(name, 'res.users');
            break;
          }
        }
      }
      _mobileResolved = true;
      return _mobileCache;
    } catch (_) {
      return null; // Unresolved, so retried on the next call.
    }
  }

  /// Phone: hr's `res.users.work_phone` first, since that is the number Odoo's
  /// own user form shows; `res.partner.phone` otherwise.
  Future<_ResolvedField?> _resolvePhone() async {
    await _scopeCaches();
    if (_phoneResolved) return _phoneCache;
    try {
      final users = await _firstUserField(await _describeUsers(), const [
        'work_phone',
        'x_studio_work_phone',
      ]);
      if (users != null) {
        _phoneCache = users;
      } else {
        final partnerFields = await _describe('res.partner');
        _phoneCache = partnerFields.containsKey('phone')
            ? const _ResolvedField('phone', 'res.partner')
            : null;
      }
      _phoneResolved = true;
      return _phoneCache;
    } catch (_) {
      return const _ResolvedField('phone', 'res.partner');
    }
  }

  /// A single-field `res.users` read: `res.users.read` only takes the
  /// same-user bypass when every requested field is self-readable, which hr's
  /// fields are but only when asked for alone.
  Future<dynamic> _readUserField(int userId, String field) async {
    try {
      final rows = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          [field],
        ],
        'kwargs': const {},
      });
      if (rows is! List || rows.isEmpty) return null;
      return (rows.first as Map)[field];
    } catch (_) {
      return null;
    }
  }
}

class _ResolvedField {
  final String name;
  final String model;
  const _ResolvedField(this.name, this.model);
}
