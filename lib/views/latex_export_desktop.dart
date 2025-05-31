import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'latex_exporter.dart';

class LatexExporterDesktop implements LatexExporter {
  @override
  Future<void> saveLatexFile(BuildContext context, String latexContent) async {
    final directory = await getApplicationDocumentsDirectory();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save LaTeX File',
      fileName: 'cv.tex',
      type: FileType.custom,
      allowedExtensions: ['tex'],
      initialDirectory: directory.path,
    );
    if (outputFile != null) {
      if (!outputFile.endsWith('.tex')) {
        outputFile = '[0m$outputFile.tex';
      }
      final file = File(outputFile);
      await file.writeAsString(latexContent);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exported LaTeX file!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

LatexExporter getLatexExporter() => LatexExporterDesktop();
