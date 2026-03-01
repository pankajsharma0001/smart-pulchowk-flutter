import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';
import 'dart:io';
import 'package:http/io_client.dart';

class SafeCacheManager {
  static const key = 'pdfCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(
        httpClient: IOClient(
          HttpClient()
            ..badCertificateCallback =
                (X509Certificate cert, String host, int port) => true,
        ),
      ),
    ),
  );
}

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
      final cacheStream = SafeCacheManager.instance.getFileStream(
        widget.url,
        withProgress: true,
      );

      await for (final response in cacheStream) {
        if (response is DownloadProgress) {
          if (mounted) {
            setState(() {
              _downloadProgress = response.progress ?? 0.0;
            });
          }
        } else if (response is FileInfo) {
          _pdfController = PdfController(
            document: PdfDocument.openFile(response.file.path),
          );
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          break; // Stop listening to stream once we have the file
        }
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
