// =====================================
// Imports and Dependencies
// =====================================
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
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';

// =====================================
// MainScreen Widget
// =====================================
class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 1});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// =====================================
// _MainScreenState
// =====================================
class _MainScreenState extends State<MainScreen> with WindowListener {
  // =====================================
  // State Variables
  // =====================================
  late int _selectedIndex;
  bool _showAllViews = true;
  bool canSwitch = true;
  static const double minWidthForAllViews = 1000.0;

  // Store the width fractions for each view
  double _jsonFraction = 0.36;
  double _inputFraction = 0.36;
  double _latexFraction = 0.25;

  static const String _tempFileName = 'cv_temp_autosave.json';
  static const String _tempLatexFileName = 'cv_temp_autosave.tex';

  // =====================================
  // Save to History
  // =====================================
  Future<void> _saveToHistory() async {
    if (kIsWeb) return; // Skip on web
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
              autofocus: true,
              onSubmitted:
                  (value) => Navigator.of(context).pop(nameController.text),
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
                // Allow Enter to confirm overwrite
                actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                // Add a RawKeyboardListener to handle Enter key
                // But AlertDialog doesn't support focus by default, so wrap in Shortcuts/Actions
                // Instead, use a Focus widget and handle onKey
                // But for simplicity, wrap the AlertDialog in a Focus widget:
                // (see below)
              );
            },
          );

          if (shouldOverwrite != true) {
            return;
          }
        }

        await file.writeAsString(jsonData);
        // Mark as saved to history
        setState(() {
          // _lastSavedJson = jsonData;
        });

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

  // =====================================
  // Export JSON
  // =====================================
  Future<void> _exportJson() async {
    if (kIsWeb) return; // Skip on web
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
        // Write as bytes using UTF8 encoding for Android/iOS compatibility
        await file.writeAsBytes(utf8.encode(jsonData), flush: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully exported to: \\${file.path}'),
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

  // =====================================
  // Load from History
  // =====================================
  Future<void> _loadFromHistory() async {
    if (kIsWeb) return; // Skip on web
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
      // Sort files by last modified descending (most recent first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
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

      FileSystemEntity? selectedFile;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              List<FileSystemEntity> localFiles = List.from(jsonFiles);
              return AlertDialog(
                title: const Text('Load CV from History'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: localFiles.length,
                    itemBuilder: (context, index) {
                      final file = localFiles[index];
                      final fileName = file.path
                          .split('/')
                          .last
                          .replaceAll('.json', '');
                      return ListTile(
                        title: Text(fileName),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Delete CV'),
                                    content: Text(
                                      'Are you sure you want to delete "$fileName"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(false),
                                      ),
                                      TextButton(
                                        child: const Text('Delete'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed:
                                            () =>
                                                Navigator.of(context).pop(true),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm == true) {
                              try {
                                await File(file.path).delete();
                                setState(() {
                                  localFiles.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Deleted "$fileName"'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error deleting "$fileName": $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () {
                          selectedFile = file;
                          Navigator.of(context).pop();
                        },
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
        },
      );

      if (selectedFile != null) {
        final file = File(selectedFile!.path);
        final jsonData = await file.readAsString();

        // Validate JSON
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded CV: \\${selectedFile!.path.split('/').last}',
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

  // =====================================
  // Import JSON
  // =====================================
  Future<void> _importJson() async {
    if (kIsWeb) return; // Skip on web
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

  // =====================================
  // Lifecycle: initState, dispose, onWindowClose
  // =====================================
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    if (!kIsWeb) {
      windowManager.addListener(this);
      _loadTempData();
      _loadTempLatexData();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Future<bool> onWindowClose() async {
    if (!kIsWeb) {
      await _saveTempData();
      await _saveTempLatexData();
    }
    return true;
  }

  // =====================================
  // Temp Data Autosave/Autoload
  // =====================================
  Future<void> _loadTempData() async {
    if (kIsWeb) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempFileName');
      if (await tempFile.exists()) {
        final jsonData = await tempFile.readAsString();
        // Validate JSON before loading
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);
        } catch (_) {
          // Ignore invalid temp data
        }
      }
    } catch (_) {}
  }

  Future<void> _saveTempData() async {
    if (kIsWeb) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempFileName');
      final jsonData = context.read<CVDataProvider>().jsonData;
      await tempFile.writeAsString(jsonData);
    } catch (_) {}
  }

  Future<void> _loadTempLatexData() async {
    if (kIsWeb) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempLatexFileName');
      if (await tempFile.exists()) {
        final latexData = await tempFile.readAsString();
        if (latexData.isNotEmpty) {
          context.read<CVDataProvider>().updateLatexOutput(latexData);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveTempLatexData() async {
    if (kIsWeb) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempLatexFileName');
      final latexData = context.read<CVDataProvider>().latexOutput;
      await tempFile.writeAsString(latexData);
    } catch (_) {}
  }

  // =====================================
  // No-op Callbacks for JsonView
  // =====================================
  void _onJsonSave() {
    setState(() {
      // No-op
    });
  }

  void _onJsonCancel() {
    // No-op
  }

  // =====================================
  // Build Methods
  // =====================================
  @override
  Widget build(BuildContext context) {
    final editMode = context.watch<CVDataProvider>().editMode;
    final isEditing = editMode != EditMode.none;
    return WillPopScope(
      onWillPop: () async {
        // No unsaved-changes check, just allow pop
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final canSwitch = totalWidth >= minWidthForAllViews;
          final shouldShowAllViews = _showAllViews && canSwitch;
          return Scaffold(
            appBar: AppBar(
              title: const Text('CV Maker'),
              actions: [
                IconButton(
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  tooltip: 'Switch Theme',
                  onPressed: () {
                    context.read<CVDataProvider>().toggleTheme();
                  },
                ),
                IconButton(
                  icon: Icon(
                    shouldShowAllViews ? Icons.view_agenda : Icons.view_column,
                  ),
                  tooltip:
                      shouldShowAllViews
                          ? 'Show Single View'
                          : 'Show All Views',
                  onPressed:
                      canSwitch
                          ? () {
                            setState(() {
                              _showAllViews = !_showAllViews;
                            });
                          }
                          : null,
                  color: canSwitch ? null : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  onPressed: isEditing ? null : _importJson,
                  tooltip: 'Import JSON',
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: isEditing ? null : _loadFromHistory,
                  tooltip: 'Load from History',
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: isEditing ? null : _saveToHistory,
                  tooltip: 'Save to History',
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  onPressed: isEditing ? null : _exportJson,
                  tooltip: 'Export JSON',
                ),
              ],
            ),
            body:
                shouldShowAllViews
                    ? _buildMultiViewBody(totalWidth)
                    : _buildSingleView(_selectedIndex),
            bottomNavigationBar:
                !shouldShowAllViews
                    ? NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.code),
                          label: 'JSON',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.edit),
                          label: 'Input',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.description),
                          label: 'LaTeX',
                        ),
                      ],
                    )
                    : null,
          );
        },
      ),
    );
  }

  Widget _buildSingleView(int index) {
    switch (index) {
      case 0:
        return JsonView(onSave: _onJsonSave, onCancel: _onJsonCancel);
      case 1:
        return const InputView();
      case 2:
        return const LatexView();
      default:
        return Container();
    }
  }

  Widget _buildMultiViewBody(double totalWidth) {
    final dividerWidth = 8.0;
    final minPanelWidth =
        420.0; // Increased to ensure button row fits and prevent crushing
    double jsonWidth = _jsonFraction * totalWidth;
    double inputWidth = _inputFraction * totalWidth;
    double latexWidth = _latexFraction * totalWidth;
    final minTotal = minPanelWidth * 3 + dividerWidth * 2;
    if (totalWidth < minTotal) {
      jsonWidth = inputWidth = latexWidth = (totalWidth - dividerWidth * 2) / 3;
    }
    final usedWidth = jsonWidth + inputWidth + latexWidth + dividerWidth * 2;
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
        SizedBox(
          width: jsonWidth,
          child: JsonView(onSave: _onJsonSave, onCancel: _onJsonCancel),
        ),
        _ResizableDivider(
          onDrag: (dx) {
            setState(() {
              final delta = dx / totalWidth;
              _jsonFraction = (_jsonFraction + delta).clamp(0.1, 0.8);
              _inputFraction = (_inputFraction - delta).clamp(0.1, 0.8);
              _latexFraction = 1 - _jsonFraction - _inputFraction;
            });
          },
        ),
        SizedBox(width: inputWidth, child: const InputView()),
        _ResizableDivider(
          onDrag: (dx) {
            setState(() {
              final delta = dx / totalWidth;
              _inputFraction = (_inputFraction + delta).clamp(0.1, 0.8);
              _latexFraction = (_latexFraction - delta).clamp(0.1, 0.8);
              _jsonFraction = 1 - _inputFraction - _latexFraction;
            });
          },
        ),
        SizedBox(width: latexWidth, child: const LatexView()),
      ],
    );
  }
}

// =====================================
// _ResizableDivider Widget
// =====================================
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
