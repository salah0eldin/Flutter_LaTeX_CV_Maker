// Stub for non-web platforms
import 'package:flutter/material.dart';

class WebPdfIframe extends StatelessWidget {
  final String viewType;

  const WebPdfIframe({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('WebPdfIframe is not supported on this platform'),
    );
  }
}
