// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add for HapticFeedback
import 'dart:convert';
import 'dart:async'; // Add for Timer
import '../views/json_view.dart';
import '../views/input_view.dart';
import '../views/pdf_view.dart';
import '../providers/cv_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'cv_file_handler.dart';
import 'cv_file_handler_stub.dart'
    if (dart.library.html) 'main_screen_web.dart'
    if (dart.library.io) 'main_screen_desktop.dart';
import 'main_screen_mobile.dart' as mobile_handler;

// =====================================
// Platform-aware file handler function
// =====================================
CVFileHandler _getPlatformFileHandler() {
  if (kIsWeb) {
    return getCVFileHandler();
  } else if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return mobile_handler.getCVFileHandler();
  } else {
    return getCVFileHandler();
  }
}

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

  // Store the width fractions for each view (Input, JSON, PDF)
  double _jsonFraction = 0.33;
  double _inputFraction = 0.33;
  double _pdfFraction = 0.34;

  late final CVFileHandler _fileHandler;

  // Preserve PDF view state
  late final PDFView _pdfView;

  // Auto-save debouncing
  Timer? _autoSaveTimer;

  // Page controller for swipe navigation on mobile
  late final PageController _pageController;

  // =====================================
  // Save to History (delegated)
  // =====================================
  Future<void> _saveToHistory() async {
    final mostRecentData = context.read<CVDataProvider>().mostRecentEditData;
    try {
      json.decode(mostRecentData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid JSON data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _fileHandler.saveToHistory(context, mostRecentData);
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
                      // Show confirmation dialog before deleting
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Delete from History'),
                              content: Text(
                                'Are you sure you want to delete "$name" from history?\n\nThis action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                      );

                      // Only delete if user confirmed
                      if (confirmed == true) {
                        await _fileHandler.removeHistoryKey(context, key);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "$name"'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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
          context.read<CVDataProvider>().updateJsonDataFromImport(jsonData);
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
    final jsonContent = await _fileHandler.importFromFile(context);
    if (jsonContent != null) {
      // Update provider with imported data (using import-specific method)
      // This will automatically reset edit mode, sync both views, and clear dirty flags
      final provider = context.read<CVDataProvider>();
      provider.updateJsonDataFromImport(jsonContent);

      // Auto-save will be triggered automatically by provider when data changes

      // Show success message (moved from file handlers to here)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imported and loaded JSON data!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
    // Initialize platform-specific file handler
    _fileHandler = _getPlatformFileHandler();
    // Initialize PDF view once to preserve state
    _pdfView = const PDFView();
    _selectedIndex = widget.initialIndex;

    // Initialize page controller for swipe navigation
    _pageController = PageController(initialPage: widget.initialIndex);

    // Set up auto-save callback for non-web platforms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CVDataProvider>();
      provider.setAutoSaveCallback(() {
        _autoSaveData();
      });
      provider.setAutoSavePdfCallback(() {
        _autoSavePdfData();
      });
    });

    // Restore last state (draft) for all views
    Future.microtask(() async {
      final handler = _fileHandler;
      // Restore JSON/input state
      await handler.loadTempData(context);
      // Restore PDF state
      await handler.loadTempPdfData(context);
    });
  }

  @override
  void dispose() {
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();
    // Dispose page controller
    _pageController.dispose();
    // Save PDF temp data before disposing
    _savePdfTempDataBeforeDispose();
    super.dispose();
  }

  Future<void> _savePdfTempDataBeforeDispose() async {
    try {
      final provider = context.read<CVDataProvider>();
      await _fileHandler.saveTempPdfData(
        context,
        provider.tempPdfBytes,
        provider.tempPdfIsTemplate,
      );
    } catch (e) {
      debugPrint('Error saving PDF temp data on dispose: $e');
    }
  }

  // =====================================
  // Auto-save functionality
  // =====================================
  void _autoSaveData() {
    if (!kIsWeb) {
      // Cancel previous timer if it exists
      _autoSaveTimer?.cancel();

      // Set up a new timer to debounce rapid changes
      _autoSaveTimer = Timer(const Duration(milliseconds: 500), () async {
        try {
          await _fileHandler.saveTempData(context);
          debugPrint('DEBUG: Auto-saved temp data');
        } catch (e) {
          debugPrint('DEBUG: Error during auto-save: $e');
        }
      });
    }
  }

  void _autoSavePdfData() {
    if (!kIsWeb) {
      // Auto-save PDF temp data for non-web platforms
      Future.microtask(() async {
        try {
          final provider = context.read<CVDataProvider>();
          await _fileHandler.saveTempPdfData(
            context,
            provider.tempPdfBytes,
            provider.tempPdfIsTemplate,
          );
          debugPrint('DEBUG: Auto-saved PDF temp data');
        } catch (e) {
          debugPrint('DEBUG: Error during PDF auto-save: $e');
        }
      });
    }
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          // Save PDF temp data before closing
          await _savePdfTempDataBeforeDispose();
        }
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
                              if (canSwitch) {
                                setState(() => _showAllViews = !_showAllViews);
                              }
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

                        // On mobile, also animate PageController to the selected page
                        if (defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
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
                          icon: Icon(Icons.picture_as_pdf),
                          label: 'PDF',
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
    // On mobile platforms, use PageView for swipe navigation
    // On desktop, use IndexedStack for tab-like behavior
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          // Provide haptic feedback when user starts swiping
          if (scrollNotification is ScrollStartNotification) {
            HapticFeedback.selectionClick();
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (newIndex) {
            // Prevent navigation if editing
            final editMode = context.read<CVDataProvider>().editMode;
            if (editMode != EditMode.none) {
              // Reset to current page if editing
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _pageController.animateToPage(
                  _selectedIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
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

            // Provide haptic feedback when page changes
            HapticFeedback.lightImpact();

            setState(() {
              _selectedIndex = newIndex;
            });
          },
          children: [
            JsonView(onSave: _onJsonSave, onCancel: _onJsonCancel), // Index 0
            const InputView(), // Index 1
            _pdfView, // Index 2
          ],
        ),
      );
    } else {
      // Desktop: Use IndexedStack to preserve all view states
      // All views are created once and kept alive, only visibility changes
      return IndexedStack(
        index: index,
        children: [
          JsonView(onSave: _onJsonSave, onCancel: _onJsonCancel), // Index 0
          const InputView(), // Index 1
          _pdfView, // Index 2
        ],
      );
    }
  }

  Widget _buildMultiViewBody(double totalWidth) {
    final dividerWidth = 8.0;
    final minPanelWidth =
        420.0; // Increased to ensure button row fits and prevent crushing
    double jsonWidth = _jsonFraction * totalWidth;
    double inputWidth = _inputFraction * totalWidth;
    double pdfWidth = _pdfFraction * totalWidth;
    final minTotal = minPanelWidth * 3 + dividerWidth * 2;
    if (totalWidth < minTotal) {
      jsonWidth = inputWidth = pdfWidth = (totalWidth - dividerWidth * 2) / 3;
    }
    final usedWidth = jsonWidth + inputWidth + pdfWidth + dividerWidth * 2;
    if (usedWidth > totalWidth) {
      final scale =
          (totalWidth - dividerWidth * 2) / (jsonWidth + inputWidth + pdfWidth);
      jsonWidth *= scale;
      inputWidth *= scale;
      pdfWidth *= scale;
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
              _pdfFraction = 1 - _jsonFraction - _inputFraction;
            });
          },
        ),
        SizedBox(width: inputWidth, child: const InputView()),
        _ResizableDivider(
          onDrag: (dx) {
            setState(() {
              final delta = dx / totalWidth;
              _inputFraction = (_inputFraction + delta).clamp(0.1, 0.8);
              _pdfFraction = (_pdfFraction - delta).clamp(0.1, 0.8);
              _jsonFraction = 1 - _inputFraction - _pdfFraction;
            });
          },
        ),
        SizedBox(
          width: pdfWidth,
          child: _pdfView,
        ), // Use preserved PDF view instance
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
