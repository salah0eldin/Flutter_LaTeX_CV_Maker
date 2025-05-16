import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../views/json_view.dart';
import '../views/input_view.dart';
import '../views/latex_view.dart';
import '../providers/cv_data_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _showAllViews = false;

  // Store the width fractions for each view
  double _jsonFraction = 0.33;
  double _inputFraction = 0.34;
  double _latexFraction = 0.33;

  final List<Widget> _views = [
    const JsonView(),
    const InputView(),
    const LatexView(),
  ];

  Future<void> _saveToHistory() async {
    try {
      final jsonData = context.read<CVDataProvider>().jsonData;

      // Validate JSON
      try {
        json.decode(jsonData);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/cv_history');

      // Create history directory if it doesn't exist
      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }

      // Show dialog to get file name
      final TextEditingController nameController = TextEditingController();
      final String? fileName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Save to History'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Enter a name for your CV',
                labelText: 'CV Name',
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Save'),
                onPressed: () => Navigator.of(context).pop(nameController.text),
              ),
            ],
          );
        },
      );

      if (fileName != null && fileName.isNotEmpty) {
        final sanitizedFileName = fileName.replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final file = File('${historyDir.path}/$sanitizedFileName.json');

        // Check if file exists
        if (await file.exists()) {
          final bool? shouldOverwrite = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('File Already Exists'),
                content: Text(
                  'A CV named "$sanitizedFileName" already exists. Do you want to overwrite it?',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Overwrite'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          );

          if (shouldOverwrite != true) {
            return;
          }
        }

        await file.writeAsString(jsonData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to history as: $sanitizedFileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final jsonData = context.read<CVDataProvider>().jsonData;

      // Validate JSON
      try {
        json.decode(jsonData);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get the documents directory as default save location
      final directory = await getApplicationDocumentsDirectory();

      // Show save dialog
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export JSON File',
        fileName: 'cv.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        initialDirectory: directory.path,
      );

      if (outputFile != null) {
        // Ensure the file has .json extension
        if (!outputFile.endsWith('.json')) {
          outputFile = '$outputFile.json';
        }

        final file = File(outputFile);

        // Check if file exists
        if (await file.exists()) {
          final bool? shouldOverwrite = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('File Already Exists'),
                content: Text(
                  'A file already exists at:\n${file.path}\nDo you want to overwrite it?',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Overwrite'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          );

          if (shouldOverwrite != true) {
            return;
          }
        }

        await file.writeAsString(jsonData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully exported to: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFromHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/cv_history');

      if (!await historyDir.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved CVs found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final files = await historyDir.list().toList();
      final jsonFiles =
          files.where((file) => file.path.endsWith('.json')).toList();

      if (jsonFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved CVs found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show file selection dialog
      final selectedFile = await showDialog<FileSystemEntity>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Load CV from History'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: jsonFiles.length,
                itemBuilder: (context, index) {
                  final file = jsonFiles[index];
                  final fileName = file.path
                      .split('/')
                      .last
                      .replaceAll('.json', '');
                  return ListTile(
                    title: Text(fileName),
                    onTap: () => Navigator.of(context).pop(file),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );

      if (selectedFile != null) {
        final file = File(selectedFile.path);
        final jsonData = await file.readAsString();

        // Validate JSON
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded CV: ${selectedFile.path.split('/').last}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid JSON file'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading from history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importJson() async {
    try {
      // Show file picker dialog
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final jsonData = await file.readAsString();

        // Validate JSON
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Successfully imported: ${file.path.split('/').last}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid JSON file'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Maker'),
        actions: [
          IconButton(
            icon: Icon(_showAllViews ? Icons.view_agenda : Icons.view_column),
            tooltip: _showAllViews ? 'Show Single View' : 'Show All Views',
            onPressed: () {
              setState(() {
                _showAllViews = !_showAllViews;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _importJson,
            tooltip: 'Import JSON',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _loadFromHistory,
            tooltip: 'Load from History',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveToHistory,
            tooltip: 'Save to History',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _exportJson,
            tooltip: 'Export JSON',
          ),
        ],
      ),
      body:
          _showAllViews
              ? LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final dividerWidth = 8.0;
                  final minPanelWidth = 150.0;
                  double jsonWidth = _jsonFraction * totalWidth;
                  double inputWidth = _inputFraction * totalWidth;
                  double latexWidth = _latexFraction * totalWidth;
                  // Ensure minimum widths
                  final minTotal = minPanelWidth * 3 + dividerWidth * 2;
                  if (totalWidth < minTotal) {
                    jsonWidth =
                        inputWidth =
                            latexWidth = (totalWidth - dividerWidth * 2) / 3;
                  }
                  // Fix: Ensure the sum of widths does not exceed totalWidth
                  final usedWidth =
                      jsonWidth + inputWidth + latexWidth + dividerWidth * 2;
                  if (usedWidth > totalWidth) {
                    final scale =
                        (totalWidth - dividerWidth * 2) /
                        (jsonWidth + inputWidth + latexWidth);
                    jsonWidth *= scale;
                    inputWidth *= scale;
                    latexWidth *= scale;
                  }
                  return Row(
                    children: [
                      SizedBox(width: jsonWidth, child: const JsonView()),
                      _ResizableDivider(
                        onDrag: (dx) {
                          setState(() {
                            final delta = dx / totalWidth;
                            _jsonFraction = (_jsonFraction + delta).clamp(
                              0.1,
                              0.8,
                            );
                            _inputFraction = (_inputFraction - delta).clamp(
                              0.1,
                              0.8,
                            );
                            _latexFraction = 1 - _jsonFraction - _inputFraction;
                          });
                        },
                      ),
                      SizedBox(width: inputWidth, child: const InputView()),
                      _ResizableDivider(
                        onDrag: (dx) {
                          setState(() {
                            final delta = dx / totalWidth;
                            _inputFraction = (_inputFraction + delta).clamp(
                              0.1,
                              0.8,
                            );
                            _latexFraction = (_latexFraction - delta).clamp(
                              0.1,
                              0.8,
                            );
                            _jsonFraction = 1 - _inputFraction - _latexFraction;
                          });
                        },
                      ),
                      SizedBox(width: latexWidth, child: const LatexView()),
                    ],
                  );
                },
              )
              : _views[_selectedIndex],
      bottomNavigationBar:
          _showAllViews
              ? null
              : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.code), label: 'JSON'),
                  NavigationDestination(icon: Icon(Icons.edit), label: 'Input'),
                  NavigationDestination(
                    icon: Icon(Icons.description),
                    label: 'LaTeX',
                  ),
                ],
              ),
    );
  }
}

class _ResizableDivider extends StatelessWidget {
  final void Function(double dx) onDrag;
  const _ResizableDivider({required this.onDrag, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        onDrag(details.delta.dx);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: double.infinity,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
