// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/cv_data_provider.dart';
import 'latex_exporter.dart';
import 'latex_export_stub.dart'
    if (dart.library.html) 'latex_export_web.dart'
    if (dart.library.io) 'latex_export_desktop.dart';

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
  final LatexExporter _exporter = getLatexExporter();

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
      await _exporter.saveLatexFile(context, _controller.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export LaTeX: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================
  // Convert to PDF
  // =====================================
  Future<void> _convertToPdf() async {
    try {
      if (_controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No content to convert'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Delegate to platform-specific implementation
      if (_exporter is PdfCapableLatexExporter) {
        await (_exporter as PdfCapableLatexExporter).convertToPdf(
          context,
          _controller.text,
        );
      } else {
        throw Exception('PDF export not supported on this platform.');
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isOtherEditing ? null : _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Convert to PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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

// All web/desktop-specific LaTeX export logic will be delegated to platform-specific files using conditional imports.
