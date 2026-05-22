import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

class NativeToolBridgeService {
  Future<Map<String, dynamic>> execute({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    switch (toolName) {
      case nativeOpenUrlToolName:
        return _openUrl(args);
      case nativeOpenAppToolName:
        return _openApp(args);
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

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return <String, dynamic>{
      'status': ok ? 'success' : 'error',
      'tool': nativeOpenAppToolName,
      'uri': rawUri,
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
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: <String, String>{
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

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
}
