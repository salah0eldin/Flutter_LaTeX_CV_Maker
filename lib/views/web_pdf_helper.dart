// Web-specific PDF helper functions
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

class WebPdfHelper {
  // Cache for PDF iframe view types
  static String? _cachedViewType;
  static String? _cachedDataUrl;
  static bool? _cachedIsDarkMode;

  static void openPdfInNewTab(Uint8List pdfBytes) {
    try {
      // Create blob URL and open in new tab
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');

      // Clean up the blob URL after a delay
      Future.delayed(const Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      throw Exception('Failed to open PDF in new tab: $e');
    }
  }

  static String createPdfIframe(
    String viewType,
    Uint8List pdfBytes, {
    bool isDarkMode = false,
  }) {
    try {
      // Create data URL for the PDF
      final base64String = html.window.btoa(String.fromCharCodes(pdfBytes));
      final dataUrl = 'data:application/pdf;base64,$base64String';

      // Check if we can reuse the cached iframe
      if (_cachedViewType != null &&
          _cachedDataUrl == dataUrl &&
          _cachedIsDarkMode == isDarkMode) {
        // Return the cached view type
        return _cachedViewType!;
      }

      // Clean up previous iframe if it exists
      _cleanup();

      // Register the iframe factory with a unique view type
      final uniqueViewType =
          '${viewType}_${DateTime.now().millisecondsSinceEpoch}';

      // Cache the values
      _cachedViewType = uniqueViewType;
      _cachedDataUrl = dataUrl;
      _cachedIsDarkMode = isDarkMode;

      ui_web.platformViewRegistry.registerViewFactory(uniqueViewType, (
        int viewId,
      ) {
        // Create a container div with dark mode support
        final backgroundColor = isDarkMode ? '#1e1e1e' : '#ffffff';
        final container =
            html.DivElement()
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..style.overflow = 'hidden'
              ..style.backgroundColor = backgroundColor;

        // Try embed element first (best for PDFs)
        final embed =
            html.EmbedElement()
              ..src = dataUrl
              ..type = 'application/pdf'
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..style.backgroundColor = backgroundColor
              ..onLoad.listen((_) {
                print('PDF embed loaded successfully');
              })
              ..onError.listen((error) {
                print('PDF embed error: $error');
                // If embed fails, show fallback
                _showPdfFallback(container, dataUrl, isDarkMode: isDarkMode);
              });

        container.children.add(embed);
        return container;
      });

      return uniqueViewType;
    } catch (e) {
      throw Exception('Failed to create PDF iframe: $e');
    }
  }

  static void _showPdfFallback(
    html.DivElement container,
    String dataUrl, {
    bool isDarkMode = false,
  }) {
    // Clear container and add fallback content
    container.children.clear();

    // Dark mode color scheme
    final backgroundColor = isDarkMode ? '#1e1e1e' : '#f5f5f5';
    final textColor = isDarkMode ? '#ffffff' : '#333333';
    final buttonBgColor = isDarkMode ? '#424242' : '#2196F3';
    final buttonTextColor = '#ffffff';

    // Add a message and link to open PDF
    final fallbackDiv =
        html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.flexDirection = 'column'
          ..style.justifyContent = 'center'
          ..style.alignItems = 'center'
          ..style.backgroundColor = backgroundColor
          ..style.color = textColor
          ..style.fontFamily = 'Arial, sans-serif';

    final icon =
        html.DivElement()
          ..style.fontSize = '48px'
          ..style.marginBottom = '16px'
          ..text = '📄';

    final message =
        html.DivElement()
          ..style.fontSize = '18px'
          ..style.fontWeight = 'bold'
          ..style.marginBottom = '8px'
          ..text = 'PDF Ready';

    final subMessage =
        html.DivElement()
          ..style.fontSize = '14px'
          ..style.marginBottom = '16px'
          ..style.textAlign = 'center'
          ..text =
              'Your browser blocked the PDF viewer.\nClick below to open the PDF.';

    final openButton =
        html.ButtonElement()
          ..style.padding = '12px 24px'
          ..style.backgroundColor = buttonBgColor
          ..style.color = buttonTextColor
          ..style.border = 'none'
          ..style.borderRadius = '4px'
          ..style.cursor = 'pointer'
          ..style.fontSize = '14px'
          ..style.transition = 'background-color 0.2s ease'
          ..text = 'Open PDF'
          ..onClick.listen((_) {
            html.window.open(dataUrl, '_blank');
          });

    // Add hover effects after button is created
    openButton.onMouseEnter.listen((_) {
      openButton.style.backgroundColor = isDarkMode ? '#616161' : '#1976D2';
    });

    openButton.onMouseLeave.listen((_) {
      openButton.style.backgroundColor = buttonBgColor;
    });

    fallbackDiv.children.addAll([icon, message, subMessage, openButton]);
    container.children.add(fallbackDiv);
  }

  static void _cleanup() {
    // Clear cache when cleaning up
    _cachedViewType = null;
    _cachedDataUrl = null;
    _cachedIsDarkMode = null;
  }

  static void dispose() {
    _cleanup();
  }

  static void downloadPdf(Uint8List pdfBytes, String filename) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      throw Exception('Failed to download PDF: $e');
    }
  }
}
