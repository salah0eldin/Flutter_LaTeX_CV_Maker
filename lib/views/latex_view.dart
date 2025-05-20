// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;
import 'dart:io';
import '../providers/cv_data_provider.dart';

// =====================================
// LatexView Widget
// =====================================
class LatexView extends StatefulWidget {
  const LatexView({super.key});

  @override
  State<LatexView> createState() => _LatexViewState();
}

// =====================================
// _LatexViewState
// =====================================
class _LatexViewState extends State<LatexView> {
  late TextEditingController _controller;

  // =====================================
  // initState & dispose
  // =====================================
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

  // =====================================
  // Save LaTeX File
  // =====================================
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
        // Write as bytes for compatibility with all platforms
        await file.writeAsBytes(_controller.text.codeUnits);

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

  // =====================================
  // Convert to PDF
  // =====================================
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
        if (Platform.isLinux) {
          // On Linux, save to user-specified location
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save PDF File',
            fileName: 'cv.pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            initialDirectory: tempDir.path,
          );
          if (outputFile != null) {
            if (!outputFile.endsWith('.pdf')) {
              outputFile = '$outputFile.pdf';
            }
            await pdfFile.copy(outputFile);
            // Open the PDF file after saving
            try {
              await Process.run('xdg-open', [outputFile]);
            } catch (e) {
              // Ignore errors if xdg-open is not available
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF saved to: $outputFile'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          // On other platforms, share the PDF file
          await Share.shareXFiles(
            [XFile(pdfFile.path)],
            text: 'My CV',
            subject: 'CV in PDF format',
          );
        }
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

  // =====================================
  // Build Method
  // =====================================
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isOtherEditing =
        provider.editMode == EditMode.json ||
        provider.editMode == EditMode.input;
    final providerLatex = provider.latexOutput;
    if (_controller.text != providerLatex) {
      _controller.value = TextEditingValue(
        text: providerLatex,
        selection: TextSelection.collapsed(offset: providerLatex.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // =====================================
          // Action Buttons Row (moved to top)
          // =====================================
          LayoutBuilder(
            builder: (context, constraints) {
              // Set a higher threshold for LaTeX view due to wider button labels
              final isNarrow = constraints.maxWidth < 520;
              return isNarrow
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _saveLatexFile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save LaTeX'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed:
                            isOtherEditing
                                ? null
                                : () {
                                  setState(
                                    () {},
                                  ); // Dummy update, replace with actual update logic if needed
                                },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update'),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _saveLatexFile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save LaTeX'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            isOtherEditing
                                ? null
                                : () {
                                  setState(
                                    () {},
                                  ); // Dummy update, replace with actual update logic if needed
                                },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update'),
                      ),
                    ],
                  );
            },
          ),
          const SizedBox(height: 16),
          // =====================================
          // Editor
          // =====================================
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'LaTeX output will appear here...',
              ),
              onChanged:
                  isOtherEditing
                      ? null
                      : (value) {
                        context.read<CVDataProvider>().updateLatexOutput(value);
                      },
              enabled: !isOtherEditing,
            ),
          ),
        ],
      ),
    );
  }
}
