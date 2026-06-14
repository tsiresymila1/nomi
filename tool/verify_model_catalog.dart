// Verifies that every default catalog source is a single-file llamadart model
// (.gguf or .litertlm) that resolves on Hugging Face. This includes vision
// `mmprojUrl` projector files, which are extracted alongside the model URLs
// because both are plain `'https://...'` string literals in the catalog.
//
// A source "resolves" when the request returns HTTP 200 (public file) or
// HTTP 401 (gated file that requires the Hugging Face token the app supplies at
// download time). Any other status — 404, 403, network failure — fails the run.
//
// Run with: dart run tool/verify_model_catalog.dart
//
// The script reads the catalog source file directly instead of importing it,
// because the catalog still depends on Flutter-only types that cannot be loaded
// by the plain Dart VM.

import 'dart:io';

const _catalogPath = 'lib/features/downloads/data/default_seed_models.dart';

Future<void> main() async {
  final file = File(_catalogPath);
  if (!file.existsSync()) {
    stderr.writeln('Catalog file not found: $_catalogPath');
    exitCode = 1;
    return;
  }

  final source = file.readAsStringSync();
  final urls = _extractSourceUrls(source);

  if (urls.isEmpty) {
    stderr.writeln('No model source URLs found in $_catalogPath');
    exitCode = 1;
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  var failures = 0;

  for (final url in urls) {
    if (!url.endsWith('.gguf') && !url.endsWith('.litertlm')) {
      stdout.writeln('FAIL  incompatible format  $url');
      failures++;
      continue;
    }

    try {
      final status = await _resolve(client, url);
      if (status == 200) {
        stdout.writeln('OK    public ($status)        $url');
      } else if (status == 401) {
        stdout.writeln('OK    gated  ($status)        $url');
      } else {
        stdout.writeln('FAIL  status $status          $url');
        failures++;
      }
    } catch (error) {
      stdout.writeln('FAIL  $error  $url');
      failures++;
    }
  }

  client.close(force: true);

  stdout.writeln('---');
  stdout.writeln('${urls.length} sources checked, $failures failure(s).');
  if (failures > 0) {
    exitCode = 1;
  }
}

/// Pulls every `http(s)` string literal out of the catalog source text.
List<String> _extractSourceUrls(String source) {
  final pattern = RegExp(r"'(https?://[^']+)'");
  final urls = <String>[];
  for (final match in pattern.allMatches(source)) {
    final url = match.group(1)!;
    if (!urls.contains(url)) urls.add(url);
  }
  return urls;
}

/// Follows redirects manually so a Hugging Face CDN redirect to a signed CAS URL
/// reports the final status rather than the intermediate 302.
Future<int> _resolve(HttpClient client, String url) async {
  var current = Uri.parse(url);
  for (var hop = 0; hop < 10; hop++) {
    final request = await client.getUrl(current);
    request.followRedirects = false;
    final response = await request.close();
    final status = response.statusCode;
    await response.drain<void>();

    if (status >= 300 && status < 400) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) return status;
      current = current.resolve(location);
      continue;
    }
    return status;
  }
  return 508; // redirect loop
}
