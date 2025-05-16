import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../providers/cv_data_provider.dart';

class LatexView extends StatefulWidget {
  const LatexView({super.key});

  @override
  State<LatexView> createState() => _LatexViewState();
}

class _LatexViewState extends State<LatexView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<CVDataProvider>().latexOutput,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: _controller.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LaTeX copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying to clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLatexFile() async {
    try {
      // First, ensure we have content to save
      if (_controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No content to save'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get the documents directory as default save location
      final directory = await getApplicationDocumentsDirectory();
      final defaultPath = '${directory.path}/cv.tex';

      // Show save dialog
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save LaTeX File',
        fileName: 'cv.tex',
        type: FileType.custom,
        allowedExtensions: ['tex'],
        initialDirectory: directory.path,
      );

      if (outputFile != null) {
        // Ensure the file has .tex extension
        if (!outputFile.endsWith('.tex')) {
          outputFile = '$outputFile.tex';
        }

        final file = File(outputFile);
        await file.writeAsString(_controller.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully saved to: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _convertToPdf() async {
    try {
      // First, ensure we have content to convert
      if (_controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No content to convert'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final texFile = File('${tempDir.path}/cv.tex');
      final pdfFile = File('${tempDir.path}/cv.pdf');

      // Save LaTeX content to temporary file
      await texFile.writeAsString(_controller.text);

      // Check if pdflatex is installed
      try {
        final checkResult = await Process.run('which', ['pdflatex']);
        if (checkResult.exitCode != 0) {
          throw Exception(
            'pdflatex is not installed. Please install TeX Live.',
          );
        }
      } catch (e) {
        throw Exception('pdflatex is not installed. Please install TeX Live.');
      }

      // Run pdflatex command
      final result = await Process.run('pdflatex', [
        '-interaction=nonstopmode',
        '-output-directory=${tempDir.path}',
        texFile.path,
      ]);

      if (result.exitCode == 0 && pdfFile.existsSync()) {
        // Share the PDF file
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'My CV',
          subject: 'CV in PDF format',
        );
      } else {
        String errorMessage = 'Error generating PDF';
        if (result.stderr.toString().isNotEmpty) {
          errorMessage += ': ${result.stderr}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update controller text when provider data changes
    if (_controller.text != context.watch<CVDataProvider>().latexOutput) {
      _controller.text = context.watch<CVDataProvider>().latexOutput;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'LaTeX output will appear here...',
              ),
              onChanged: (value) {
                context.read<CVDataProvider>().updateLatexOutput(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return isNarrow
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _saveLatexFile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save LaTeX'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveLatexFile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save LaTeX'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                      ),
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }
}
