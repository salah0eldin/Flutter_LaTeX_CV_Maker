// Stub for non-web platforms
import 'dart:typed_data';

class WebPdfHelper {
  static void openPdfInNewTab(Uint8List pdfBytes) {
    throw UnsupportedError('Web PDF helper not available on this platform');
  }

  static String createPdfIframe(
    String viewType,
    Uint8List pdfBytes, {
    bool isDarkMode = false,
  }) {
    throw UnsupportedError('Web PDF iframe not available on this platform');
  }

  static void downloadPdf(Uint8List pdfBytes, String filename) {
    throw UnsupportedError('Web PDF download not available on this platform');
  }

  static void dispose() {
    // No-op for non-web platforms
  }
}
