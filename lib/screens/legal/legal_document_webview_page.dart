import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/app_config.dart';

/// Loads Privacy or Terms HTML from the API (admin-editable) inside an in-app WebView.
class LegalDocumentWebViewPage extends StatefulWidget {
  const LegalDocumentWebViewPage({super.key, required this.slug});

  final String slug;

  @override
  State<LegalDocumentWebViewPage> createState() =>
      _LegalDocumentWebViewPageState();
}

class _LegalDocumentWebViewPageState extends State<LegalDocumentWebViewPage> {
  late final WebViewController _controller;
  String _title = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get(
        ApiEndpoints.legalDocument(widget.slug),
        requiresAuth: false,
      );
      if (!mounted) return;
      if (res['success'] == true && res['html'] != null) {
        final html = res['html'] as String;
        final title = (res['title'] as String?) ?? _defaultTitle();
        final wrapped = _wrapHtml(html);
        await _controller.loadHtmlString(
          wrapped,
          baseUrl: AppConfig.apiOrigin,
        );
        setState(() {
          _title = title;
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Could not load document.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error.';
        _loading = false;
      });
    }
  }

  String _defaultTitle() {
    return widget.slug == 'terms' ? 'Terms & Conditions' : 'Privacy Policy';
  }

  String _wrapHtml(String body) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    padding: 16px 18px 32px; margin: 0; line-height: 1.55; color: #0f172a; background: #f8fafc; font-size: 15px; }
  h1 { font-size: 1.35rem; margin-top: 0; }
  h2 { font-size: 1.05rem; margin-top: 1.25rem; }
  a { color: #2563eb; }
  @media (prefers-color-scheme: dark) {
    body { color: #e2e8f0; background: #0f172a; }
    a { color: #93c5fd; }
  }
</style>
</head>
<body>$body</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isEmpty ? _defaultTitle() : _title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_loading && _error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
