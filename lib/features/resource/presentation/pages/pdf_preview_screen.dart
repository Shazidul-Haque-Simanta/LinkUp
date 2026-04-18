import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class PdfPreviewScreen extends StatefulWidget {
  final String? pdfUrl;
  final String? resourceId;
  final String? fileName;
  
  const PdfPreviewScreen({super.key, this.pdfUrl, this.resourceId, this.fileName});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late PdfViewerController _pdfViewerController;
  int _pageCount = 0;
  int _currentPage = 0;
  double _zoomLevel = 1.0;
  bool _isLoading = true;
  bool _showTroubleshoot = false;
  bool _useProxy = false;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadTimer = Timer(const Duration(seconds: 6), () {
      if (_isLoading && mounted) {
        setState(() => _showTroubleshoot = true);
        if (kIsWeb && !_useProxy) {
          setState(() {
            _useProxy = true;
            _isLoading = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  bool _isPdf(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('.pdf?') || (widget.fileName?.toLowerCase().endsWith('.pdf') ?? false) || lower.contains('/uploads/');
  }

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.contains('.jpg?') || lower.contains('.png?');
  }

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (urlString.isEmpty) return;
    String finalUrl = urlString;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    final Uri url = Uri.parse(finalUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched && widget.resourceId != null) {
        await _firebaseService.incrementDownloadCount(widget.resourceId!);
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String finalUrl = widget.pdfUrl ?? '';
    // Bypass SSL issues for shazid.info
    if (finalUrl.contains('https://shazid.info')) {
      finalUrl = finalUrl.replaceAll('https://', 'http://');
    }

    if (kIsWeb && _useProxy) {
      // Use AllOrigins proxy as fallback for insecure shazid.info links
      final encodedUrl = Uri.encodeComponent(finalUrl);
      finalUrl = 'https://api.allorigins.win/raw?url=$encodedUrl';
    }

    final String displayFileName = widget.fileName ?? (widget.pdfUrl != null ? widget.pdfUrl!.split('/').last.split('?').first : 'Resource Preview');
    final bool isPdf = _isPdf(finalUrl);
    final bool isImage = _isImage(finalUrl);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          // Main Preview Content
          Positioned.fill(
            child: finalUrl.isEmpty
              ? const Center(child: Text('No preview available', style: TextStyle(color: Colors.white)))
              : isPdf
                  ? SfPdfViewer.network(
                      finalUrl,
                      controller: _pdfViewerController,
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        if (mounted) {
                          setState(() {
                            _pageCount = details.document.pages.count;
                            _isLoading = false;
                          });
                        }
                      },
                      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to load: ${details.description}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'Try Proxy 2',
                                textColor: Colors.white,
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _useProxy = true;
                                      _isLoading = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                        }
                      },
                      onPageChanged: (PdfPageChangedDetails details) {
                        if (mounted) {
                          setState(() {
                            _currentPage = details.newPageNumber;
                          });
                        }
                      },
                    )
                  : isImage
                    ? Center(
                        child: InteractiveViewer(
                          child: Image.network(
                            finalUrl,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            },
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                            const SizedBox(height: 16),
                            const Text('Format not supported for in-app preview', style: TextStyle(color: Colors.white)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _launchURL(context, finalUrl),
                              child: const Text('Open in Browser'),
                            ),
                          ],
                        ),
                      ),
          ),

          // Loading Indicator Over the Preview
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  if (_showTroubleshoot) ...[
                    const SizedBox(height: 24),
                    const Text('Taking a while? CORS might be blocking this.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _launchURL(context, finalUrl),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Try opening in new tab'),
                    ),
                  ],
                ],
              ),
            ),

          // Top Control Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 16, right: 16),
              color: Colors.black.withValues(alpha: 0.6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.insert_drive_file_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayFileName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('LinkUp Resource Viewer', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 20),
                    onPressed: () {}, // Optional: Full screen toggle
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // Floating Control Island (The Pill at the bottom)
          if (_isPdf(finalUrl) && _pageCount > 0)
            Positioned(
              bottom: 100,
              left: 40,
              right: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                        onPressed: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_currentPage / $_pageCount',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0),
                      ),
                      const VerticalDivider(color: Colors.white24, indent: 8, endIndent: 8),
                      IconButton(
                        icon: const Icon(Icons.zoom_in_map_rounded, color: Colors.white, size: 20),
                        onPressed: () => _pdfViewerController.zoomLevel = 1.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Quick Info Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Document', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayFileName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchURL(context, widget.pdfUrl ?? ''),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
