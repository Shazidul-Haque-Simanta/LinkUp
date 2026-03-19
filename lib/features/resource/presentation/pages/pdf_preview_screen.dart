import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String? pdfUrl;
  final String? resourceId;
  
  const PdfPreviewScreen({super.key, this.pdfUrl, this.resourceId});

  static final FirebaseService _firebaseService = FirebaseService();

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (urlString.isEmpty) return;
    
    String finalUrl = urlString;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final Uri url = Uri.parse(finalUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched && resourceId != null) {
        await _firebaseService.incrementDownloadCount(resourceId!);
      }
    } catch (e) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          pdfUrl != null ? pdfUrl!.split('/').last.split('?').first : 'Resource Preview',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => _launchURL(context, pdfUrl ?? ''),
          ),
          IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: pdfUrl == null || pdfUrl!.isEmpty
          ? const Center(child: Text('No preview available', style: TextStyle(color: Colors.white)))
          : pdfUrl!.toLowerCase().contains('.pdf') || pdfUrl!.toLowerCase().contains('pdf')
              ? SfPdfViewer.network(
                  pdfUrl!,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                )
              : Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      pdfUrl!,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Text('Preview not available for this file type.', style: TextStyle(color: Colors.white));
                      },
                    ),
                  ),
                ),
    );
  }
}
