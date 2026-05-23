import 'dart:io';

import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

class NativeToolBridgeService {
  static const MethodChannel _phoneChannel = MethodChannel(
    'gena/native_phone_tools',
  );

  Future<Map<String, dynamic>> execute({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    switch (toolName) {
      case nativeOpenUrlToolName:
        return _openUrl(args);
      case nativeOpenAppToolName:
        return _openApp(args);
      case nativePhoneCallToolName:
        return _directPhoneCall(args);
      case nativeReadContactsToolName:
        return _readContacts(args);
      case nativeSearchContactsToolName:
        return _searchContacts(args);
      case nativeCreateContactToolName:
        return _createContact(args);
      case nativeSendSmsToolName:
        return _sendSms(args);
      case nativeSendEmailToolName:
        return _sendEmail(args);
      case nativeFlashlightToolName:
        return _flashlight(args);
      default:
        return <String, dynamic>{
          'status': 'error',
          'error': 'unsupported_tool',
          'message': 'Unsupported native tool: $toolName',
        };
    }
  }

  Future<Map<String, dynamic>> _readContacts(Map<String, dynamic> args) async {
    final permissionOk = await _ensureContactsPermission();
    if (!permissionOk) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'permission_denied',
        'message': 'Contacts permission is required to read contacts.',
      };
    }

    try {
      final limit = _toInt(args['limit'], fallback: 50).clamp(1, 200);
      final contacts = await ContactsService.getContacts(withThumbnails: false);
      final payload = contacts.take(limit).map(_contactToMap).toList();
      return <String, dynamic>{
        'status': 'success',
        'tool': nativeReadContactsToolName,
        'count': payload.length,
        'contacts': payload,
      };
    } catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'contacts_read_failed',
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _searchContacts(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_query',
        'message': 'Parameter "query" is required.',
      };
    }

    final permissionOk = await _ensureContactsPermission();
    if (!permissionOk) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'permission_denied',
        'message': 'Contacts permission is required to search contacts.',
      };
    }

    try {
      final limit = _toInt(args['limit'], fallback: 20).clamp(1, 100);
      final contacts = await ContactsService.getContacts(
        query: query,
        withThumbnails: false,
      );
      final payload = contacts.take(limit).map(_contactToMap).toList();
      return <String, dynamic>{
        'status': 'success',
        'tool': nativeSearchContactsToolName,
        'query': query,
        'count': payload.length,
        'contacts': payload,
      };
    } catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'contacts_search_failed',
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _createContact(Map<String, dynamic> args) async {
    final permissionOk = await _ensureContactsPermission();
    if (!permissionOk) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'permission_denied',
        'message': 'Contacts permission is required to create contacts.',
      };
    }

    var givenName = (args['given_name'] ?? '').toString().trim();
    var familyName = (args['family_name'] ?? '').toString().trim();
    final displayName = (args['display_name'] ?? '').toString().trim();

    if (givenName.isEmpty && familyName.isEmpty && displayName.isNotEmpty) {
      final parts = displayName
          .split(RegExp(r'\s+'))
          .where((item) => item.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        givenName = parts.first;
      }
      if (parts.length > 1) {
        familyName = parts.sublist(1).join(' ');
      }
    }

    if (givenName.isEmpty && familyName.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_contact_name',
        'message':
            'Provide at least "given_name", "family_name", or "display_name".',
      };
    }

    final phoneNumbers = _toStringList(args['phone_numbers']);
    final emails = _toStringList(args['emails']);
    final company = (args['company'] ?? '').toString().trim();
    final jobTitle = (args['job_title'] ?? '').toString().trim();

    final contact = Contact(
      givenName: givenName.isEmpty ? null : givenName,
      familyName: familyName.isEmpty ? null : familyName,
      company: company.isEmpty ? null : company,
      jobTitle: jobTitle.isEmpty ? null : jobTitle,
      phones: phoneNumbers
          .map((value) => Item(label: 'mobile', value: value))
          .toList(),
      emails: emails.map((value) => Item(label: 'work', value: value)).toList(),
    );

    try {
      await ContactsService.addContact(contact);
      return <String, dynamic>{
        'status': 'success',
        'tool': nativeCreateContactToolName,
        'contact': <String, dynamic>{
          'display_name': _displayNameOf(contact),
          'given_name': contact.givenName,
          'family_name': contact.familyName,
          'phones': phoneNumbers,
          'emails': emails,
          if (company.isNotEmpty) 'company': company,
          if (jobTitle.isNotEmpty) 'job_title': jobTitle,
        },
      };
    } catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'contact_create_failed',
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _sendSms(Map<String, dynamic> args) async {
    final message = (args['message'] ?? '').toString().trim();
    final recipients = _toStringList(args['recipients']);
    if (message.isEmpty || recipients.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_sms_payload',
        'message':
            'Parameters "message" and "recipients" are required for SMS.',
      };
    }

    try {
      final capable = await canSendSMS();
      if (!capable) {
        return <String, dynamic>{
          'status': 'error',
          'error': 'sms_unavailable',
          'message': 'This device cannot send SMS.',
        };
      }

      final result = await sendSMS(message: message, recipients: recipients);
      return <String, dynamic>{
        'status': 'success',
        'tool': nativeSendSmsToolName,
        'recipients': recipients,
        'result': result,
      };
    } catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'sms_send_failed',
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _directPhoneCall(
    Map<String, dynamic> args,
  ) async {
    final rawPhoneNumber = ((args['phone_number'] ?? args['number']) ?? '')
        .toString()
        .trim();
    if (rawPhoneNumber.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_phone_number',
        'message':
            'Parameter "phone_number" is required and must be non-empty.',
      };
    }

    if (!Platform.isAndroid) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'unsupported_platform',
        'message': 'Direct phone call is currently supported on Android only.',
      };
    }

    try {
      final didStart = await _phoneChannel.invokeMethod<bool>(
        'makeDirectPhoneCall',
        <String, dynamic>{'phoneNumber': rawPhoneNumber},
      );
      final ok = didStart ?? false;
      return <String, dynamic>{
        'status': ok ? 'success' : 'error',
        'tool': nativePhoneCallToolName,
        'phone_number': rawPhoneNumber,
        if (!ok) 'message': 'Could not start direct phone call.',
      };
    } on PlatformException catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': e.code,
        'message': e.message ?? e.toString(),
      };
    } on MissingPluginException {
      return <String, dynamic>{
        'status': 'error',
        'error': 'missing_native_implementation',
        'message':
            'Native phone call implementation is not available on this platform.',
      };
    }
  }

  Future<Map<String, dynamic>> _openUrl(Map<String, dynamic> args) async {
    final rawUrl = (args['url'] ?? '').toString().trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || rawUrl.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_url',
        'message': 'Parameter "url" is required and must be valid.',
      };
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return <String, dynamic>{
      'status': ok ? 'success' : 'error',
      'tool': nativeOpenUrlToolName,
      'url': rawUrl,
      if (!ok) 'message': 'Could not open URL.',
    };
  }

  Future<Map<String, dynamic>> _openApp(Map<String, dynamic> args) async {
    final rawUri = (args['uri'] ?? '').toString().trim();
    final uri = Uri.tryParse(rawUri);
    if (uri == null || rawUri.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_uri',
        'message': 'Parameter "uri" is required for open_app action.',
      };
    }

    final candidates = <Uri>[uri, ..._buildMapsFallbackUris(rawUri)];
    var ok = false;
    Uri? launchedUri;
    for (final candidate in candidates) {
      final launched = await _tryLaunchExternal(candidate);
      if (launched) {
        ok = true;
        launchedUri = candidate;
        break;
      }
    }
    return <String, dynamic>{
      'status': ok ? 'success' : 'error',
      'tool': nativeOpenAppToolName,
      'uri': rawUri,
      if (launchedUri != null && launchedUri.toString() != rawUri)
        'resolved_uri': launchedUri.toString(),
      if (!ok)
        'message':
            'Could not open app URI. Verify app is installed and URI scheme is correct.',
    };
  }

  Future<Map<String, dynamic>> _sendEmail(Map<String, dynamic> args) async {
    final to = (args['to'] ?? '').toString().trim();
    if (to.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_email',
        'message': 'Parameter "to" is required.',
      };
    }

    final subject = (args['subject'] ?? '').toString();
    final body = (args['body'] ?? '').toString();
    final queryParts = <String>[
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ];
    final query = queryParts.isEmpty ? '' : '?${queryParts.join('&')}';
    final uri = Uri.parse('mailto:$to$query');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return <String, dynamic>{
      'status': ok ? 'success' : 'error',
      'tool': nativeSendEmailToolName,
      'to': to,
      if (!ok) 'message': 'Could not open email application.',
    };
  }

  Future<Map<String, dynamic>> _flashlight(Map<String, dynamic> args) async {
    final mode = (args['mode'] ?? '').toString().trim().toLowerCase();
    if (mode != 'on' && mode != 'off') {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_mode',
        'message': 'Parameter "mode" must be "on" or "off".',
      };
    }

    try {
      if (mode == 'on') {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      return <String, dynamic>{
        'status': 'success',
        'tool': nativeFlashlightToolName,
        'mode': mode,
      };
    } catch (e) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'flashlight_failed',
        'message': e.toString(),
      };
    }
  }

  List<Uri> _buildMapsFallbackUris(String rawUri) {
    if (!rawUri.toLowerCase().startsWith('maps:')) return const <Uri>[];
    var location = rawUri.substring(5).trim();
    if (location.startsWith('//')) {
      location = location.substring(2).trim();
    }
    if (location.isEmpty) return const <Uri>[];

    final encoded = Uri.encodeComponent(location);
    return <Uri>[
      Uri.parse('geo:0,0?q=$encoded'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
      Uri.parse('https://maps.apple.com/?q=$encoded'),
    ];
  }

  Future<bool> _tryLaunchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureContactsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _phoneChannel.invokeMethod<bool>(
        'requestContactsPermission',
      );
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Map<String, dynamic> _contactToMap(Contact contact) {
    final phones =
        contact.phones
            ?.map((item) => item.value?.trim())
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];
    final emails =
        contact.emails
            ?.map((item) => item.value?.trim())
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];

    return <String, dynamic>{
      'identifier': contact.identifier,
      'display_name': _displayNameOf(contact),
      'given_name': contact.givenName,
      'family_name': contact.familyName,
      'company': contact.company,
      'job_title': contact.jobTitle,
      'phones': phones,
      'emails': emails,
    };
  }

  String _displayNameOf(Contact contact) {
    final display = contact.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final joined = <String>[
      if ((contact.givenName ?? '').trim().isNotEmpty)
        contact.givenName!.trim(),
      if ((contact.familyName ?? '').trim().isNotEmpty)
        contact.familyName!.trim(),
    ].join(' ');
    return joined.trim();
  }

  List<String> _toStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value == null) return <String>[];
    final single = value.toString().trim();
    return single.isEmpty ? <String>[] : <String>[single];
  }

  int _toInt(Object? value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }
}
