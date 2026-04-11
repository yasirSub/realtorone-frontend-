import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/services.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String url;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Disable screenshots if possible (security)
    // Actually, this requires a specialized plugin like flutter_windowmanager
    // For now, we just don't provide a download button.
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
          // We explicitly DO NOT add a download button here
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
          SfPdfViewer.network(
            widget.url,
            key: _pdfViewerKey,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _isLoading = false;
              });
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              setState(() {
                _isLoading = false;
              });
              _showErrorDialog(details.description);
            },
            enableDoubleTapZooming: true,
            enableTextSelection: false, // Disable text selection to prevent copying
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('ENCRYPTION ERROR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('Failed to decrypt and load asset: $description',
            style: const TextStyle(color: Colors.white70)),
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
