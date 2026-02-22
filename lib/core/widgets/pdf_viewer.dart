import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CustomPdfViewer extends StatefulWidget {
  final String url;
  final String title;

  const CustomPdfViewer({super.key, required this.url, required this.title});

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUiVisible = true;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await _downloadPdfBytes();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/temp_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes);

      _pdfController = PdfController(document: PdfDocument.openFile(file.path));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _downloadPdfBytes() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF (Status: ${response.statusCode})');
      }

      final contentLength = response.contentLength;
      final bytes = BytesBuilder(copy: false);
      int downloaded = 0;

      await for (final chunk in response) {
        bytes.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = downloaded / contentLength;
          });
        }
      }
      return bytes.takeBytes();
    } catch (e) {
      if (_isTlsCertificateError(e)) {
        final fallbackBytes = await _downloadPdfBytesWithFallback();
        if (fallbackBytes != null) return fallbackBytes;
      }
      rethrow;
    }
  }

  bool _isTlsCertificateError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('certificate_verify_failed') ||
        message.contains('handshakeexception') ||
        message.contains('handshake error');
  }

  Future<Uint8List?> _downloadPdfBytesWithFallback() async {
    final uri = Uri.parse(widget.url);
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => host == uri.host;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;

      final contentLength = response.contentLength;
      final bytes = BytesBuilder(copy: false);
      int downloaded = 0;

      await for (final chunk in response) {
        bytes.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = downloaded / contentLength;
          });
        }
      }
      return bytes.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _isUiVisible = !_isUiVisible),
        child: Stack(
          children: [
            // PDF Content
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                    if (_downloadProgress > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_pdfController != null)
              PdfView(
                controller: _pdfController!,
                scrollDirection: Axis.vertical,
              ),

            // Header (Back & Title)
            if (_isUiVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    InteractiveWrapper(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.title,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Page Number Indicator
            if (_isUiVisible && !_isLoading && _pdfController != null)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: PdfPageNumber(
                    controller: _pdfController!,
                    builder: (context, loadingState, page, pagesCount) =>
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$page / $pagesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
