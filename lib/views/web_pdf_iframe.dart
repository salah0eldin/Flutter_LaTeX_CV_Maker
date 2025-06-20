// Web-specific PDF iframe widget
// This file should only be imported on web platforms

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class WebPdfIframe extends StatelessWidget {
  final String viewType;

  const WebPdfIframe({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        child: Text('WebPdfIframe is only available on web platforms'),
      );
    }

    try {
      // Create the HtmlElementView with the registered view type
      return HtmlElementView(viewType: viewType);
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('HtmlElementView Error: $e'),
            const SizedBox(height: 8),
            Text('View Type: $viewType'),
          ],
        ),
      );
    }
  }
}
