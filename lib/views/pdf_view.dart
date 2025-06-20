// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cv_data_provider.dart';

// Web PDF helper with conditional import
import 'web_pdf_helper_stub.dart' if (dart.library.html) 'web_pdf_helper.dart';

// Web PDF iframe with conditional import
import 'web_pdf_iframe_stub.dart' if (dart.library.html) 'web_pdf_iframe.dart';

// =====================================
// PDFView Widget
// =====================================
class PDFView extends StatefulWidget {
  const PDFView({super.key});

  @override
  State<PDFView> createState() => _PDFViewState();
}

// =====================================
// _PDFViewState
// =====================================
class _PDFViewState extends State<PDFView> {
  Uint8List? _pdfBytes;
  Uint8List? _templatePdfBytes;
  bool _isGeneratingPdf = false;
  bool _isLoadingTemplate = false;
  String? _error;
  bool _isShowingTemplate = false;

  // =====================================
  // initState
  // =====================================
  @override
  void initState() {
    super.initState();

    // Check for temp PDF data and load template
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePdfView();
    });
  }

  // =====================================
  // dispose
  // =====================================
  @override
  void dispose() {
    if (kIsWeb) {
      WebPdfHelper.dispose();
    }
    super.dispose();
  }

  // =====================================
  // Load Template PDF from Assets
  // =====================================
  Future<void> _loadTemplatePdf() async {
    setState(() {
      _isLoadingTemplate = true;
    });

    try {
      final ByteData data = await rootBundle.load('assets/template_cv.pdf');
      _templatePdfBytes = data.buffer.asUint8List();
      setState(() {
        _isLoadingTemplate = false;
        _isShowingTemplate = true; // Show template by default
      });
      // Update provider with template data
      _updatePdfStateInProvider();
      debugPrint(
        'Template PDF loaded successfully (${_templatePdfBytes!.length} bytes)',
      );
    } catch (e) {
      setState(() {
        _isLoadingTemplate = false;
      });
      // Template PDF is optional, so we don't show an error if it's missing
      debugPrint('Template PDF not found: $e');
    }
  }

  // =====================================
  // Show Template CV
  // =====================================
  void _showTemplateCv() {
    debugPrint(
      '_showTemplateCv called. Template bytes available: ${_templatePdfBytes != null}',
    );

    if (_templatePdfBytes != null) {
      setState(() {
        _isShowingTemplate = true;
        _pdfBytes = null; // Clear any generated PDF
        _error = null;
      });
      // Update provider with template state
      _updatePdfStateInProvider();

      debugPrint(
        'Template CV state set. _isShowingTemplate: $_isShowingTemplate',
      );

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing template CV'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template CV not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // =====================================
  // Build Platform-Aware PDF Viewer
  // =====================================
  Widget _buildPdfViewer(Uint8List pdfBytes) {
    debugPrint(
      'Building PDF viewer for platform: ${defaultTargetPlatform.name}, isWeb: $kIsWeb, PDF size: ${pdfBytes.length} bytes',
    );

    try {
      // Validate PDF bytes
      if (pdfBytes.isEmpty) {
        debugPrint('Error: PDF bytes are empty');
        return _buildErrorWidget('PDF data is empty');
      }

      // Check if it looks like a valid PDF (starts with %PDF)
      if (pdfBytes.length < 4 ||
          pdfBytes[0] != 0x25 ||
          pdfBytes[1] != 0x50 ||
          pdfBytes[2] != 0x44 ||
          pdfBytes[3] != 0x46) {
        debugPrint('Error: Invalid PDF format - does not start with %PDF');
        return _buildErrorWidget('Invalid PDF format');
      }

      // Try different configurations based on platform
      if (kIsWeb) {
        // Web-specific configuration with enhanced features
        debugPrint('Using enhanced web PDF viewer configuration');
        return _buildWebPdfViewer(pdfBytes);
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        // Use fallback for Linux due to Syncfusion issues
        debugPrint('Using fallback PDF viewer for Linux');
        return _buildLinuxPdfViewer(pdfBytes);
      } else {
        // Use default configuration for other desktop platforms (Windows, macOS)
        debugPrint('Using default PDF viewer configuration for desktop');
        return SfPdfViewer.memory(
          pdfBytes,
          key: UniqueKey(), // Force recreation to avoid caching issues
          onDocumentLoadFailed: (details) {
            debugPrint('PDF load failed: ${details.error}');
            debugPrint('PDF load details: ${details.description}');
          },
          onDocumentLoaded: (details) {
            debugPrint(
              'PDF loaded successfully: ${details.document.pages.count} pages',
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error creating PDF viewer: $e');
      return _buildErrorWidget('Failed to load PDF: $e');
    }
  }

  // =====================================
  // Build Web-Specific PDF Viewer
  // =====================================
  Widget _buildWebPdfViewer(Uint8List pdfBytes) {
    debugPrint('Building web PDF viewer with ${pdfBytes.length} bytes');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                // Web PDF status bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.web, size: 16, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Web PDF Viewer • ${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _openPdfInNewTab(pdfBytes),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Open in New Tab'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                // PDF iframe viewer
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1e1e1e)
                              : Colors.white,
                      border: Border.all(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: _buildWebPdfIframe(pdfBytes),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================
  // Build Linux-Specific PDF Viewer (Fallback)
  // =====================================
  Widget _buildLinuxPdfViewer(Uint8List pdfBytes) {
    // Simple fallback for Linux since PDF viewers have platform issues
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900,
            Colors.grey.shade800,
            Colors.grey.shade900,
          ],
        ),
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // PDF Icon with animation (smaller)
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0.8, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade800,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade900.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Title (smaller)
            Text(
              'PDF Ready!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            // File info (more compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade700.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'PDF loaded • ${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade300,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description (more compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'PDF preview temporarily unavailable on Linux.\nDownload or open in external viewer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.grey.shade400,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons (more compact, wrap if needed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildCompactButton(
                    onPressed: () => _downloadPdf(),
                    icon: Icons.download,
                    label: 'Download',
                    color: Colors.blue.shade600,
                  ),
                  _buildCompactButton(
                    onPressed: () => _openPdfExternally(),
                    icon: Icons.open_in_new,
                    label: 'Open',
                    color: Colors.green.shade600,
                  ),
                  _buildCompactButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'PDF preview will be improved in future updates',
                          ),
                          backgroundColor: Colors.blue.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icons.info_outline,
                    label: 'Info',
                    color: Colors.blue.shade600,
                    isOutlined: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Platform info (smaller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade600, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.desktop_windows,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Linux Desktop',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper method for compact buttons
  Widget _buildCompactButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: color, width: 1.5),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      );
    }
  }

  // =====================================
  // Build Error Widget
  // =====================================
  Widget _buildErrorWidget(String message) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'PDF Display Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _generatePdfFromJson(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _downloadPdf(),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Text(
                'Web browsers may have PDF display restrictions',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================
  // Generate PDF from JSON
  // =====================================
  Future<void> _generatePdfFromJson() async {
    // PDF generation will be handled server-side for privacy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PDF generation will be implemented server-side for privacy and security.',
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // =====================================
  // Update PDF (same as generate for now)
  // =====================================
  void _updatePdf() {
    _generatePdfFromJson();
  }

  // =====================================
  // Download PDF
  // =====================================
  Future<void> _downloadPdf() async {
    try {
      Uint8List? bytesToDownload;
      String filename = 'cv.pdf';

      if (_isShowingTemplate && _templatePdfBytes != null) {
        bytesToDownload = _templatePdfBytes;
        filename = 'template_cv.pdf';
      } else if (_pdfBytes != null) {
        bytesToDownload = _pdfBytes;
        filename = 'my_cv.pdf';
      }

      if (bytesToDownload != null) {
        // Platform-specific download implementation
        await _savePdfFile(context, bytesToDownload, filename);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // =====================================
  // Platform-specific PDF save function
  // =====================================
  Future<void> _savePdfFile(
    BuildContext context,
    Uint8List pdfBytes,
    String filename,
  ) async {
    if (kIsWeb) {
      // Web: trigger download using HTML anchor element
      await _downloadPdfWeb(pdfBytes, filename);
    } else {
      // Desktop/Mobile: save to downloads or documents folder
      await _savePdfToFile(pdfBytes, filename);
    }
  }

  Future<void> _downloadPdfWeb(Uint8List pdfBytes, String filename) async {
    // Web download implementation using WebPdfHelper
    WebPdfHelper.downloadPdf(pdfBytes, filename);
  }

  Future<void> _savePdfToFile(Uint8List pdfBytes, String filename) async {
    try {
      Directory? directory;
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  // =====================================
  // Open PDF Externally
  // =====================================
  Future<void> _openPdfExternally() async {
    try {
      Uint8List? bytesToOpen;
      String filename = 'cv.pdf';

      if (_isShowingTemplate && _templatePdfBytes != null) {
        bytesToOpen = _templatePdfBytes;
        filename = 'template_cv.pdf';
      } else if (_pdfBytes != null) {
        bytesToOpen = _pdfBytes;
        filename = 'my_cv.pdf';
      }

      if (bytesToOpen != null) {
        // Save to temporary file and open it
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(bytesToOpen);

        final uri = Uri.file(tempFile.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $filename in external viewer...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception('No PDF viewer found');
        }
      }
    } catch (e) {
      debugPrint('Error opening PDF externally: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open PDF externally: $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } // =====================================

  // Open PDF in New Tab (Web)
  // =====================================
  void _openPdfInNewTab(Uint8List pdfBytes) {
    if (!kIsWeb) {
      // For non-web platforms, use external opening instead
      _openPdfExternally();
      return;
    }

    try {
      // Use the web helper for blob URL creation
      WebPdfHelper.openPdfInNewTab(pdfBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF opened in new tab'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error opening PDF in new tab: $e');

      // Fallback to download
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open PDF, downloading instead: $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      _downloadPdf();
    }
  }

  // =====================================
  // Helper methods for mobile-aware UI
  // =====================================
  String _getUpdateButtonText() {
    if (_isGeneratingPdf) {
      return 'Generating...';
    }

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Export LaTeX';
    }

    return 'Update';
  }

  bool _isUpdateButtonEnabled() {
    if (_isGeneratingPdf) return false;

    // On mobile, always allow the button (it will show a helpful message)
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }

    // On desktop/web, only enable if not generating
    return !_isGeneratingPdf;
  }

  // =====================================
  // Build Method
  // =====================================
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isOtherEditing =
        provider.editMode == EditMode.json ||
        provider.editMode == EditMode.input;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // =====================================
          // Action Buttons Row
          // =====================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;
              return isNarrow
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            !_isUpdateButtonEnabled() || isOtherEditing
                                ? null
                                : _updatePdf,
                        icon:
                            _isGeneratingPdf
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh),
                        label: Text(_getUpdateButtonText()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed:
                            (_pdfBytes == null &&
                                        !_isShowingTemplate &&
                                        _templatePdfBytes == null) ||
                                    _isGeneratingPdf
                                ? null
                                : _downloadPdf,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (_templatePdfBytes != null) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isGeneratingPdf ? null : _showTemplateCv,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Show Template'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            !_isUpdateButtonEnabled() || isOtherEditing
                                ? null
                                : _updatePdf,
                        icon:
                            _isGeneratingPdf
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh),
                        label: Text(_getUpdateButtonText()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            (_pdfBytes == null &&
                                        !_isShowingTemplate &&
                                        _templatePdfBytes == null) ||
                                    _isGeneratingPdf
                                ? null
                                : _downloadPdf,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (_templatePdfBytes != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isGeneratingPdf ? null : _showTemplateCv,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Show Template'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  );
            },
          ),
          const SizedBox(height: 16),

          // =====================================
          // PDF Display Area
          // =====================================
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPdfDisplayArea(),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // Build PDF Display Area
  // =====================================
  Widget _buildPdfDisplayArea() {
    debugPrint('_buildPdfDisplayArea called:');
    debugPrint('  _isLoadingTemplate: $_isLoadingTemplate');
    debugPrint('  _isGeneratingPdf: $_isGeneratingPdf');
    debugPrint('  _error: $_error');
    debugPrint('  _isShowingTemplate: $_isShowingTemplate');
    debugPrint('  _templatePdfBytes: ${_templatePdfBytes?.length} bytes');
    debugPrint('  _pdfBytes: ${_pdfBytes?.length} bytes');

    // Show loading state while template is loading
    if (_isLoadingTemplate) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading template...'),
            ],
          ),
        ),
      );
    }

    // Show PDF generation loading state
    if (_isGeneratingPdf) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Generating PDF...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (_error != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generatePdfFromJson,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show template PDF if explicitly requested and available
    if (_isShowingTemplate && _templatePdfBytes != null) {
      return Column(
        children: [
          // Template indicator banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Template CV Preview - Add your data in the Input tab to generate a personalized CV',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // PDF viewer
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: _buildPdfViewer(_templatePdfBytes!),
            ),
          ),
        ],
      );
    }

    // Show generated PDF if available and not explicitly showing template
    if (_pdfBytes != null && !_isShowingTemplate) {
      return _buildPdfViewer(_pdfBytes!);
    }

    // Show template PDF automatically if no generated PDF is available
    if (_templatePdfBytes != null && _pdfBytes == null && !_isShowingTemplate) {
      return Column(
        children: [
          // Template indicator banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getInstructionText(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // PDF viewer
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: _buildPdfViewer(_templatePdfBytes!),
            ),
          ),
        ],
      );
    }

    // No PDF available (neither generated nor template)
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No PDF Available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(_getInstructionText(), textAlign: TextAlign.center),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Template PDF loading failed on web platform',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generatePdfFromJson,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // Build Web PDF Iframe
  // =====================================
  Widget _buildWebPdfIframe(Uint8List pdfBytes) {
    if (!kIsWeb) {
      return _buildIframeFallback(pdfBytes, 'Not supported on this platform');
    }

    try {
      // Detect current theme for dark mode support
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      // Create iframe view type using PDF bytes as identifier
      final viewType = WebPdfHelper.createPdfIframe(
        'pdf-iframe',
        pdfBytes,
        isDarkMode: isDarkMode,
      );

      // Use HtmlElementView to display the registered iframe
      return _createHtmlElementView(viewType);
    } catch (e) {
      debugPrint('Error creating PDF iframe: $e');
      return _buildIframeFallback(pdfBytes, e.toString());
    }
  }

  // =====================================
  // Create HtmlElementView for Web
  // =====================================
  Widget _createHtmlElementView(String viewType) {
    // This method will only be called on web platforms
    // We use dynamic imports to avoid compilation issues on other platforms
    try {
      // Import HtmlElementView dynamically for web
      if (kIsWeb) {
        // Use the widgets library HtmlElementView
        // We need to return it as a Widget to avoid type issues
        return _webHtmlElementView(viewType);
      } else {
        return Container(
          child: Text('HtmlElementView not available on this platform'),
        );
      }
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error creating HTML view: $e'),
          ],
        ),
      );
    }
  }

  // =====================================
  // Web HTML Element View
  // =====================================
  Widget _webHtmlElementView(String viewType) {
    // This will be the actual HtmlElementView for web
    // We'll create it using Flutter's web widgets
    return Builder(
      builder: (context) {
        // For web platforms, we can use HtmlElementView directly
        // The import is handled by Flutter's conditional compilation
        return kIsWeb ? _actualHtmlElementView(viewType) : Container();
      },
    );
  }

  // =====================================
  // Actual HTML Element View Implementation
  // =====================================
  Widget _actualHtmlElementView(String viewType) {
    // This is where we actually create the HtmlElementView
    // We use a try-catch to handle any issues gracefully
    try {
      // For Flutter web, we need to use the platform view
      // Let's use a simple approach that should work
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: kIsWeb ? _createWebPlatformView(viewType) : Container(),
      );
    } catch (e) {
      return Container(child: Text('Platform view error: $e'));
    }
  }

  // =====================================
  // Create Web Platform View
  // =====================================
  Widget _createWebPlatformView(String viewType) {
    // This is the core method that creates the platform view
    // We'll use the registered view type from the iframe helper
    try {
      // Create the actual HtmlElementView - this only works on web
      // We use the viewType that was registered in WebPdfHelper
      final view =
          kIsWeb
              ? _buildActualPlatformView(viewType)
              : Container(child: Text('Not supported'));

      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRect(child: view),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Platform view error: $e'),
            const SizedBox(height: 16),
            Text(
              'View Type: $viewType',
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }
  }

  // =====================================
  // Build Actual Platform View (Web Only)
  // =====================================
  Widget _buildActualPlatformView(String viewType) {
    // This method creates the real HtmlElementView
    // It should only be called on web platforms
    if (!kIsWeb) {
      return Container(child: Text('Platform view only available on web'));
    }

    // For Flutter web, we can create HtmlElementView directly
    // The viewType should match what was registered in platformViewRegistry
    return _safeHtmlElementView(viewType);
  }

  // =====================================
  // Safe HTML Element View
  // =====================================
  Widget _safeHtmlElementView(String viewType) {
    try {
      // This is where we need to actually import and use HtmlElementView
      // Let's use a dynamic approach to avoid import issues
      return _dynamicHtmlElementView(viewType);
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.web_asset, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text('HTML Element View Error'),
            Text('$e'),
            const SizedBox(height: 16),
            Text('Registered View: $viewType'),
          ],
        ),
      );
    }
  }

  // =====================================
  // Dynamic HTML Element View
  // =====================================
  Widget _dynamicHtmlElementView(String viewType) {
    // Use the dedicated WebPdfIframe widget for clean separation
    if (!kIsWeb) {
      return Container(child: Text('Web only'));
    }

    // Use the dedicated WebPdfIframe widget
    return WebPdfIframe(viewType: viewType);
  }

  // =====================================
  // Build Iframe Fallback
  // =====================================
  Widget _buildIframeFallback(Uint8List pdfBytes, String error) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      color: isDarkMode ? const Color(0xFF1e1e1e) : Colors.grey.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDarkMode ? Colors.orange.shade400 : Colors.orange.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'PDF Iframe Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode ? Colors.orange.shade300 : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Could not embed PDF: $error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color:
                  isDarkMode ? Colors.orange.shade400 : Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openPdfInNewTab(pdfBytes),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in New Tab'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? Colors.grey.shade700 : Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructionText() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Template CV Preview - Add your data in the Input tab and click "Export LaTeX" to save your CV template for compilation';
    }
    return 'Template CV Preview - Add your data in the Input tab and click "Update" to generate your personalized CV';
  }

  // =====================================
  // Initialize PDF View
  // =====================================
  Future<void> _initializePdfView() async {
    final provider = context.read<CVDataProvider>();

    // Check if we have temp PDF data
    if (provider.tempPdfBytes != null) {
      // Restore from temp data
      setState(() {
        if (provider.tempPdfIsTemplate) {
          _templatePdfBytes = provider.tempPdfBytes;
          _isShowingTemplate = true;
          _pdfBytes = null;
        } else {
          _pdfBytes = provider.tempPdfBytes;
          _isShowingTemplate = false;
        }
      });
      debugPrint(
        'PDF view initialized from temp data (isTemplate: ${provider.tempPdfIsTemplate})',
      );
    } else {
      // No temp data, load template PDF as fallback
      await _loadTemplatePdf();
    }
  }

  // =====================================
  // Save PDF state to provider for temp saving
  // =====================================
  void _updatePdfStateInProvider() {
    final provider = context.read<CVDataProvider>();

    if (_isShowingTemplate && _templatePdfBytes != null) {
      provider.updateTempPdfData(_templatePdfBytes, true);
    } else if (_pdfBytes != null) {
      provider.updateTempPdfData(_pdfBytes, false);
    } else {
      provider.updateTempPdfData(null, false);
    }
  }
}
