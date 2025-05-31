// latex_export_stub.dart
// Platform-agnostic interface for LaTeX export

import 'package:flutter/material.dart';
import 'latex_exporter.dart';

// Fallback implementation (should never be used)
class LatexExporterStub implements LatexExporter {
  @override
  Future<void> saveLatexFile(BuildContext context, String latexContent) async {
    throw UnimplementedError('No platform implementation for LaTeX export.');
  }
}

LatexExporter getLatexExporter() => LatexExporterStub();
