// latex_exporter.dart
import 'package:flutter/material.dart';

abstract class LatexExporter {
  Future<void> saveLatexFile(BuildContext context, String latexContent);
}

abstract class PdfCapableLatexExporter implements LatexExporter {
  Future<void> convertToPdf(BuildContext context, String latexContent);
}
