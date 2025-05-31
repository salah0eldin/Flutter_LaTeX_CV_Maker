import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'latex_exporter.dart';

// Web-specific LaTeX export implementation using dart:html
// To be filled with logic moved from latex_view.dart

class LatexExporterWeb implements LatexExporter {
  @override
  Future<void> saveLatexFile(BuildContext context, String latexContent) async {
    final bytes = utf8.encode(latexContent);
    final blob = html.Blob([bytes], 'text/x-tex');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'cv.tex')
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported LaTeX file (check your downloads)'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

LatexExporter getLatexExporter() => LatexExporterWeb();
