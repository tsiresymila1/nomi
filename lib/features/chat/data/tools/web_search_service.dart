import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ddgs/ddgs.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gena/core/logger.dart';
import 'package:html2md/html2md.dart' as html2md;

class WebSearchService {
  const WebSearchService._();

  static Future<Map<String, dynamic>> search({
    required String query,
    int maxResults = 5,
    int maxContentPages = 2,
    int maxExcerptChars = 2500,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_query',
        'message': 'Search query is empty.',
      };
    }

    final ddgs = DDGS(timeout: const Duration(seconds: 12));
    try {
      final rawResults = await ddgs.text(
        normalizedQuery,
        backend: 'duckduckgo',
        maxResults: maxResults.clamp(1, 10),
      );

      final parsedResults = <Map<String, dynamic>>[];
      for (final item in rawResults) {
        final href = (item['href'] ?? item['url'] ?? '').toString().trim();
        if (href.isEmpty) continue;

        parsedResults.add(<String, dynamic>{
          'title': (item['title'] ?? '').toString(),
          'url': href,
          'snippet': (item['body'] ?? item['snippet'] ?? '').toString(),
        });
      }

      final docs = <Map<String, dynamic>>[];
      for (final result in parsedResults.take(maxContentPages.clamp(1, 5))) {
        final url = result['url'] as String;
        final markdown = await _fetchPageAsMarkdown(url);
        if (markdown == null || markdown.trim().isEmpty) continue;

        docs.add(<String, dynamic>{
          'url': url,
          'title': result['title'],
          'content_markdown': _trimForPrompt(
            markdown,
            maxChars: maxExcerptChars.clamp(500, 8000),
          ),
        });
      }

      return <String, dynamic>{
        'status': 'success',
        'query': normalizedQuery,
        'engine': 'duckduckgo',
        'results': parsedResults,
        'documents': docs,
      };
    } catch (error, stackTrace) {
      logger.e(
        'Web search failed for query: $normalizedQuery',
        error: error,
        stackTrace: stackTrace,
      );
      return <String, dynamic>{
        'status': 'error',
        'error': 'search_failed',
        'message': error.toString(),
      };
    } finally {
      ddgs.close();
    }
  }

  static Future<String?> _fetchPageAsMarkdown(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    String? html;
    try {
      html = await _HeadlessWebHtmlFetcher.fetch(uri);
    } catch (error, stackTrace) {
      logger.w(
        'Headless webview fetch failed for $uri, fallback to HttpClient.',
      );
      logger.w('$error');
      logger.d(stackTrace.toString());
    }

    html ??= await _fetchHtmlWithHttpClient(uri);
    if (html == null || html.trim().isEmpty) return null;
    final nonNullHtml = html;

    return Isolate.run(() => _convertHtmlToMarkdown(nonNullHtml));
  }

  static Future<String?> _fetchHtmlWithHttpClient(Uri uri) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _defaultUserAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final html = await response.transform(const Utf8Decoder()).join();
      client.close(force: true);
      return html;
    } catch (_) {
      return null;
    }
  }

  static String _convertHtmlToMarkdown(String html) {
    final markdown = html2md.convert(
      html,
      ignore: const <String>[
        'script',
        'style',
        'noscript',
        'svg',
        'iframe',
        'canvas',
      ],
      styleOptions: const <String, String>{
        'headingStyle': 'atx',
        'codeBlockStyle': 'fenced',
      },
    );

    return markdown
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }

  static String _trimForPrompt(String input, {required int maxChars}) {
    if (input.length <= maxChars) return input;
    return '${input.substring(0, maxChars)}\n\n...[truncated]';
  }
}

class _HeadlessWebHtmlFetcher {
  const _HeadlessWebHtmlFetcher._();

  static Future<String?> fetch(Uri uri) async {
    final completer = Completer<String?>();
    var completed = false;
    void completeOnce(String? value) {
      if (completed) return;
      completed = true;
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    late final HeadlessInAppWebView headless;
    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        disableDefaultErrorPage: true,
        mediaPlaybackRequiresUserGesture: true,
        transparentBackground: true,
        useShouldOverrideUrlLoading: false,
      ),
      onLoadStop: (controller, _) async {
        try {
          final html = await controller.getHtml();
          completeOnce(html);
        } catch (_) {
          completeOnce(null);
        }
      },
      onReceivedError: (_, _, _) {
        completeOnce(null);
      },
      onReceivedHttpError: (_, _, _) {
        completeOnce(null);
      },
    );

    try {
      await headless.run();
      final html = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
      return html;
    } finally {
      try {
        await headless.dispose();
      } catch (_) {}
    }
  }
}

const String _defaultUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
