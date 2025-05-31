// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'dart:convert';
import '../views/json_view.dart';
import '../views/input_view.dart';
import '../views/latex_view.dart';
import '../providers/cv_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'cv_file_handler.dart';
import 'cv_file_handler_stub.dart'
    if (dart.library.html) 'main_screen_web.dart'
    if (dart.library.io) 'main_screen_desktop.dart';

// All web/desktop-specific logic will be delegated to platform-specific files using conditional imports.

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
  double _jsonFraction = 0.32;
  double _inputFraction = 0.40;
  double _latexFraction = 0.25;

  final CVFileHandler _fileHandler =
      getCVFileHandler(); // Use platform-specific implementation

  // =====================================
  // Save to History (delegated)
  // =====================================
  Future<void> _saveToHistory() async {
    final jsonData = context.read<CVDataProvider>().jsonData;
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
    await _fileHandler.saveToHistory(context, jsonData);
  }

  // =====================================
  // Load from History (delegated)
  // =====================================
  Future<void> _loadHistory() async {
    final keys = await _fileHandler.getHistoryKeys(context);
    String? selectedKey;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load CV from History'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final name = key.replaceFirst('cv_history_', '');
                return ListTile(
                  title: Text(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () async {
                      await _fileHandler.removeHistoryKey(context, key);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted "$name"'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    selectedKey = key;
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
    if (selectedKey != null) {
      final jsonData = await _fileHandler.loadHistoryItem(
        context,
        selectedKey!,
      );
      if (jsonData != null) {
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded CV: \\${selectedKey!.replaceFirst('cv_history_', '')}',
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
    }
  }

  // =====================================
  // Import JSON (Web-compatible)
  // =====================================
  Future<void> _importJson() async {
    await _fileHandler.importFromFile(context);
  }

  // =====================================
  // Export JSON (Web-compatible)
  // =====================================
  Future<void> _exportJson() async {
    final jsonData = context.read<CVDataProvider>().jsonData;
    await _fileHandler.exportToFile(context, jsonData);
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
  // Init State
  // =====================================
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  // =====================================
  // Build Methods
  // =====================================
  @override
  Widget build(BuildContext context) {
    // Defensive: ensure _selectedIndex is always valid
    if (_selectedIndex < 0 || _selectedIndex > 2) _selectedIndex = 1;

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
                Builder(
                  builder: (context) {
                    if (totalWidth < 520) {
                      // Small width: combine actions into dropdown
                      return PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (isEditing) return;
                          switch (value) {
                            case 'theme':
                              context.read<CVDataProvider>().toggleTheme();
                              break;
                            case 'view':
                              if (canSwitch)
                                setState(() => _showAllViews = !_showAllViews);
                              break;
                            case 'import':
                              await _importJson();
                              break;
                            case 'history':
                              await _loadHistory();
                              break;
                            case 'save':
                              await _saveToHistory();
                              break;
                            case 'export':
                              await _exportJson();
                              break;
                          }
                        },
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'theme',
                                child: Row(
                                  children: [
                                    Icon(
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Icons.light_mode
                                          : Icons.dark_mode,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Switch Theme'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'view',
                                enabled: canSwitch,
                                child: Row(
                                  children: [
                                    Icon(
                                      shouldShowAllViews
                                          ? Icons.view_agenda
                                          : Icons.view_column,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shouldShowAllViews
                                          ? 'Show Single View'
                                          : 'Show All Views',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'import',
                                enabled: !isEditing,
                                child: Row(
                                  children: const [
                                    Icon(Icons.file_download),
                                    SizedBox(width: 8),
                                    Text('Import JSON'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'history',
                                enabled: !isEditing,
                                child: Row(
                                  children: const [
                                    Icon(Icons.history),
                                    SizedBox(width: 8),
                                    Text('Load from History'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'save',
                                enabled: !isEditing,
                                child: Row(
                                  children: const [
                                    Icon(Icons.save),
                                    SizedBox(width: 8),
                                    Text('Save to History'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'export',
                                enabled: !isEditing,
                                child: Row(
                                  children: const [
                                    Icon(Icons.file_upload),
                                    SizedBox(width: 8),
                                    Text('Export JSON'),
                                  ],
                                ),
                              ),
                            ],
                        icon: const Icon(Icons.menu),
                        tooltip: 'Actions',
                      );
                    } else {
                      // Wide: show all actions as icons
                      return Row(
                        children: [
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
                              shouldShowAllViews
                                  ? Icons.view_agenda
                                  : Icons.view_column,
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
                            onPressed: isEditing ? null : _loadHistory,
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
                      );
                    }
                  },
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
                        // Prevent navigation if editing
                        final editMode =
                            context.read<CVDataProvider>().editMode;
                        if (editMode != EditMode.none) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Finish or cancel editing before switching views.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
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
