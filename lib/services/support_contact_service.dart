import 'package:shared_preferences/shared_preferences.dart';

/// Support contact shown on maintenance / service-unavailable screens.
class SupportContact {
  const SupportContact({
    required this.email,
    required this.phone,
    required this.contactUrl,
  });

  final String email;
  final String phone;
  final String contactUrl;

  static const SupportContact defaults = SupportContact(
    email: 'aanant@therealtorone.com',
    phone: '+918595137609',
    contactUrl: 'https://therealtorone.com/contact',
  );

  bool get hasAny =>
      email.isNotEmpty || phone.isNotEmpty || contactUrl.isNotEmpty;

  Map<String, String> toRouteArgs() => {
        if (email.isNotEmpty) 'supportEmail': email,
        if (phone.isNotEmpty) 'supportPhone': phone,
        if (contactUrl.isNotEmpty) 'supportContactUrl': contactUrl,
      };

  static SupportContact fromAppConfigMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return defaults;
    }
    final email = (data['support_email'] as String?)?.trim() ?? '';
    final phone = (data['support_phone'] as String?)?.trim() ?? '';
    final url = (data['support_contact_url'] as String?)?.trim() ?? '';
    return SupportContact(
      email: email.isNotEmpty ? email : defaults.email,
      phone: phone.isNotEmpty ? phone : defaults.phone,
      contactUrl: url.isNotEmpty ? url : defaults.contactUrl,
    );
  }

  static SupportContact fromRouteArgs(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) {
      return defaults;
    }
    final email = (args['supportEmail'] as String?)?.trim() ?? '';
    final phone = (args['supportPhone'] as String?)?.trim() ?? '';
    final url = (args['supportContactUrl'] as String?)?.trim() ?? '';
    return SupportContact(
      email: email.isNotEmpty ? email : defaults.email,
      phone: phone.isNotEmpty ? phone : defaults.phone,
      contactUrl: url.isNotEmpty ? url : defaults.contactUrl,
    );
  }
}

class SupportContactService {
  static const _emailKey = 'support_contact_email';
  static const _phoneKey = 'support_contact_phone';
  static const _urlKey = 'support_contact_url';

  static Future<void> cacheFromAppConfig(Map<String, dynamic>? data) async {
    final contact = SupportContact.fromAppConfigMap(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, contact.email);
    await prefs.setString(_phoneKey, contact.phone);
    await prefs.setString(_urlKey, contact.contactUrl);
  }

  static Future<SupportContact> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    final phone = prefs.getString(_phoneKey);
    final url = prefs.getString(_urlKey);
    if (email == null && phone == null && url == null) {
      return SupportContact.defaults;
    }
    return SupportContact(
      email: (email ?? '').isNotEmpty ? email! : SupportContact.defaults.email,
      phone: (phone ?? '').isNotEmpty ? phone! : SupportContact.defaults.phone,
      contactUrl: (url ?? '').isNotEmpty
          ? url!
          : SupportContact.defaults.contactUrl,
    );
  }

  static Future<Map<String, String>> maintenanceRouteArgs({
    String? message,
  }) async {
    final contact = await loadCached();
    return {
      if (message != null && message.isNotEmpty) 'message': message,
      ...contact.toRouteArgs(),
    };
  }
}
