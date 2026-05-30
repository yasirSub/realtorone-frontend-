// ignore_for_file: unnecessary_import

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../utils/authenticated_media_url.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String? url;
  final String? filePath;
  final Map<String, String>? headers;

  const PdfViewerPage({
    super.key,
    required this.title,
    this.url,
    this.filePath,
    this.headers,
  }) : assert(url != null || filePath != null);

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;
  Map<String, String> _headers = {};

  @override
  void initState() {
    super.initState();
    _initHeaders();
  }

  Future<void> _initHeaders() async {
    final merged = <String, String>{};
    if (widget.headers != null) {
      merged.addAll(widget.headers!);
    }
    if (widget.url != null && widget.url!.contains('/api/stream/')) {
      merged.addAll(await AuthenticatedMediaUrl.streamHeaders());
    }
    if (mounted) {
      setState(() => _headers = merged);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This asset is view-only for security reasons.'),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.filePath != null)
            SfPdfViewer.file(
              File(widget.filePath!),
              key: _pdfViewerKey,
              onDocumentLoaded: (_) => setState(() => _isLoading = false),
              onDocumentLoadFailed: (details) {
                setState(() => _isLoading = false);
                _showErrorDialog(details.description);
              },
              enableDoubleTapZooming: true,
              enableTextSelection: false,
            )
          else if (widget.url != null)
            SfPdfViewer.network(
              widget.url!,
              key: _pdfViewerKey,
              headers: _headers,
              onDocumentLoaded: (_) => setState(() => _isLoading = false),
              onDocumentLoadFailed: (details) {
                setState(() => _isLoading = false);
                _showErrorDialog(details.description);
              },
              enableDoubleTapZooming: true,
              enableTextSelection: false,
            ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String description) {
    final msg = description.toLowerCase().contains('unauthorized')
        ? 'Could not open this PDF. Please sign in again or check your connection.'
        : 'Failed to load asset: $description';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Could not open PDF',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }
}
