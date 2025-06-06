// =====================================
// InputView: GUI-based CV Input Form
// =====================================
// - Supports two main categories: Header and Body
// - Header: name, phone, email, links (each with checkbox)
// - Body: title, content (content can have multiple topic lines, secondary lines, description points)
// - Each input has a checkbox to include/exclude
// - Add button (bottom right) to add Header or Body tab
// - Tabs: vertically aligned, show name, expandable, draggable for reordering
// =====================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cv_data_provider.dart';
import '../widgets/main_screen_desktop.dart'
    if (dart.library.html) '../widgets/main_screen_web.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class InputView extends StatefulWidget {
  const InputView({super.key});

  @override
  State<InputView> createState() => _InputViewState();
}

class _InputViewState extends State<InputView> {
  // List of tabs (header/body)
  final List<_InputTab> _tabs = [];
  List<_InputTab>? _tabsBackup; // Backup for cancel
  bool _dirtyFromJson = false; // True if JSON was edited and not yet synced
  bool _tabsDeleted = false; // Track if user has intentionally deleted tabs

  // Add new tab (header, skills, or body)
  void _addTab(String type) {
    setState(() {
      // Reset the deleted flag when adding new tabs
      _tabsDeleted = false;
      // Count existing tabs of this type for unique naming
      int count = _tabs.where((t) => t.type == type).length + 1;
      String baseName =
          type == 'header'
              ? 'Header'
              : type == 'skills'
              ? 'Skills'
              : 'Body';
      String name = count > 1 ? '$baseName $count' : baseName;
      if (type == 'header') {
        _tabs.add(
          _InputTab(
            type: 'header',
            name: name,
            data: {
              'name': {'value': '', 'enabled': true},
              'phone': {'value': '', 'enabled': true},
              'address': {'value': '', 'enabled': true},
              'email': {'value': '', 'enabled': true},
              'links':
                  <
                    Map<String, dynamic>
                  >[], // Each: {'value': '', 'enabled': true}
            },
          ),
        );
      } else if (type == 'skills') {
        _tabs.add(
          _InputTab(
            type: 'skills',
            name: name,
            data:
                <
                  Map<String, dynamic>
                >[], // Each: {'title': '', 'content': '', 'enabled': true}
          ),
        );
      } else {
        _tabs.add(_InputTab(type: 'body', name: name));
      }
    });
    _setDirty();
  }

  void _setDirty() {
    setState(() {
      _dirtyFromJson = false;
    });
    // Save draft to provider
    final provider = context.read<CVDataProvider>();
    provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
    // Also trigger autosave to disk to prevent tabs from being restored after deletion
    _autosaveAfterChange();
  }

  // Autosave after any change (including tab deletion)
  void _autosaveAfterChange() async {
    final fileHandler = getCVFileHandler();
    await fileHandler.saveTempData(context);
  }

  // Called by JsonView after save
  void markDirtyFromJson() {
    setState(() {
      _dirtyFromJson = true;
    });
  }

  void _startEdit(CVDataProvider provider) {
    if (_dirtyFromJson) return; // Prevent editing if out of sync
    // Backup tabs before editing
    _tabsBackup = _tabs.map((t) => t.copy()).toList();
    provider.setEditMode(EditMode.input);
  }

  void _cancelEdit(CVDataProvider provider) async {
    // Only confirm if there are unsaved changes
    final hasChanges =
        _tabsBackup == null ||
        _tabs.length != _tabsBackup!.length ||
        List.generate(_tabs.length, (i) => _tabs[i].toString()).join() !=
            List.generate(
              _tabsBackup!.length,
              (i) => _tabsBackup![i].toString(),
            ).join();
    if (!hasChanges) {
      setState(() {
        _tabs
          ..clear()
          ..addAll(_tabsBackup ?? []);
      });
      provider.cancelEdit();
      return;
    }
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Edits?'),
            content: const Text('Are you sure you want to cancel your edits?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (shouldCancel == true) {
      setState(() {
        _tabs
          ..clear()
          ..addAll(_tabsBackup ?? []);
      });
      provider.cancelEdit();
    }
  }

  void _saveEdit(CVDataProvider provider) async {
    _tabsBackup = null;
    provider.setEditMode(EditMode.none);
    // Build new JSON structure: { order: [...], sections... }
    final order = _tabs.map((t) => t.name).toList();
    final Map<String, dynamic> jsonMap = {'order': order};
    for (final tab in _tabs) {
      if (tab.type == 'header') {
        final data = Map<String, dynamic>.from(tab.data ?? {});
        final headerSection = <String, dynamic>{};
        for (final key in ['name', 'phone', 'address', 'email']) {
          headerSection[key] = {
            'value': data[key]['value'],
            'enabled': data[key]['enabled'],
          };
        }
        headerSection['links'] =
            (data['links'] as List?)
                ?.map(
                  (link) => {
                    'display': link['display'],
                    'url': link['url'],
                    'enabled': link['enabled'],
                  },
                )
                .toList() ??
            [];
        headerSection['enabled'] = data['enabled'] ?? true;
        headerSection['id'] = tab.id;
        jsonMap[tab.name] = headerSection;
      } else if (tab.type == 'skills') {
        final List skills = tab.data ?? [];
        jsonMap[tab.name] = {
          'skills':
              skills
                  .map(
                    (s) => {
                      'title': s['title'],
                      'content': s['content'],
                      'enabled': s['enabled'],
                    },
                  )
                  .toList(),
          'enabled': skills.isNotEmpty ? (skills[0]['enabled'] ?? true) : true,
          'id': tab.id,
        };
      } else if (tab.type == 'body') {
        // Placeholder for body, can be extended later
        jsonMap[tab.name] = {
          'enabled': tab.data is Map ? (tab.data['enabled'] ?? true) : true,
          'id': tab.id,
        };
      }
    }
    final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonMap);
    provider.inputTabsJson = prettyJson;
    // Set dirty flag to indicate InputView has changes that JsonView hasn't seen yet
    provider.setJsonDirtyFromInput();
    // DO NOT call provider.updateJsonData() here - JsonView should only update when its Update button is clicked
    setState(() {
      _dirtyFromJson = false;
    });
    // --- AUTOSAVE: Save draft to provider after every save ---
    provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
    // --- AUTOSAVE: Save temp file to disk after every save ---
    final fileHandler = getCVFileHandler();
    await fileHandler.saveTempData(context);
    // Log the file path for desktop
    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final appDir = await getApplicationSupportDirectory();
        final tempFilePath = '${appDir.path}/cv_temp_autosave.json';
        debugPrint('Temp autosave file path: $tempFilePath');
      } else {
        debugPrint('Temp autosave file: web/localStorage or unknown platform');
      }
    } catch (e) {
      debugPrint('Temp autosave file: error getting path ($e)');
    }
  }

  void _updateView(CVDataProvider provider) {
    // Parse provider.inputTabsJson and update _tabs
    try {
      final data = provider.parsedJsonData;
      if (data is Map && data['order'] is List) {
        final order = List<String>.from(data['order']);
        final List<_InputTab> newTabs = [];
        for (final name in order) {
          if (data[name] != null) {
            final section = data[name];
            if (section['skills'] != null) {
              // Skills tab
              newTabs.add(
                _InputTab(
                  type: 'skills',
                  name: name,
                  data: List<Map<String, dynamic>>.from(
                    section['skills'] ?? [],
                  ),
                  expanded: false,
                  id: section['id'],
                ),
              );
            } else if (section['links'] != null) {
              // Header tab
              newTabs.add(
                _InputTab(
                  type: 'header',
                  name: name,
                  data: {
                    'name': section['name'],
                    'phone': section['phone'],
                    'address': section['address'],
                    'email': section['email'],
                    'links': List<Map<String, dynamic>>.from(
                      section['links'] ?? [],
                    ),
                    'enabled': section['enabled'] ?? true,
                  },
                  expanded: false,
                  id: section['id'],
                ),
              );
            } else {
              // Body or unknown tab
              newTabs.add(
                _InputTab(
                  type: 'body',
                  name: name,
                  data: section,
                  expanded: false,
                  id: section['id'],
                ),
              );
            }
          }
        }
        setState(() {
          _tabs.clear();
          _tabs.addAll(newTabs);
          _dirtyFromJson = false;
          _tabsDeleted = false; // Reset deleted flag when updating view
        });
        // Update counter to avoid duplicate IDs
        _InputTab.updateCounterFromExistingIds(_tabs);
        provider.clearInputDirtyFromJson();
        provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<CVDataProvider>();
    // Restore draft tabs if available
    final draft = provider.inputTabsDraft;
    if (draft != null) {
      _tabs.clear();
      _tabs.addAll(draft.map((m) => _InputTab.fromMap(m)));
      // Update counter to avoid duplicate IDs
      _InputTab.updateCounterFromExistingIds(_tabs);
      _tabsDeleted = false; // Reset deleted flag when loading from draft
    } else {
      // If no draft, but there's jsonData (from autosave), load it into InputView
      _updateViewFromProvider(provider);
    }
    // Listen for when autosave data gets loaded on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check again after the frame is built, in case autosave data was loaded
      if (_tabs.isEmpty) {
        _updateViewFromProvider(provider);
      }
    });
  }

  // Helper method to update view from provider data without triggering auto-sync
  void _updateViewFromProvider(CVDataProvider provider) {
    try {
      final data = provider.parsedJsonData;
      if (data is Map && data['order'] is List) {
        final order = List<String>.from(data['order']);
        final List<_InputTab> newTabs = [];
        for (final name in order) {
          if (data[name] != null) {
            final section = data[name];
            if (section['skills'] != null) {
              // Skills tab
              newTabs.add(
                _InputTab(
                  type: 'skills',
                  name: name,
                  data: List<Map<String, dynamic>>.from(
                    section['skills'] ?? [],
                  ),
                  expanded: false,
                  id: section['id'],
                ),
              );
            } else if (section['links'] != null) {
              // Header tab
              newTabs.add(
                _InputTab(
                  type: 'header',
                  name: name,
                  data: {
                    'name': section['name'],
                    'phone': section['phone'],
                    'address': section['address'],
                    'email': section['email'],
                    'links': List<Map<String, dynamic>>.from(
                      section['links'] ?? [],
                    ),
                    'enabled': section['enabled'] ?? true,
                  },
                  expanded: false,
                  id: section['id'],
                ),
              );
            } else {
              // Body or unknown tab
              newTabs.add(
                _InputTab(
                  type: 'body',
                  name: name,
                  data: section,
                  expanded: false,
                  id: section['id'],
                ),
              );
            }
          }
        }
        if (newTabs.isNotEmpty) {
          _tabs.clear();
          _tabs.addAll(newTabs);
          // Update counter to avoid duplicate IDs
          _InputTab.updateCounterFromExistingIds(_tabs);
          // Save as draft for future use
          provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
          _tabsDeleted = false; // Reset deleted flag when loading from provider
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.input;
    final isOtherEditing = provider.editMode == EditMode.json;
    final isJsonDirty = provider.inputDirtyFromJson;

    // Check if autosave data was just loaded and we need to update InputView
    // But don't restore if user has intentionally deleted all tabs
    if (provider.autosaveDataLoaded && _tabs.isEmpty && !_tabsDeleted) {
      // Use microtask to avoid building during build
      Future.microtask(() {
        if (mounted) {
          _updateViewFromProvider(provider);
          setState(() {}); // Trigger rebuild after loading data
        }
      });
    }

    // Check if JSON data was imported and we need to update InputView
    if (provider.jsonImported) {
      // Use microtask to avoid building during build
      Future.microtask(() {
        if (mounted) {
          _updateViewFromProvider(provider);
          provider.clearJsonImported(); // Clear the flag after handling
          _tabsDeleted = false; // Reset deleted flag when importing
          setState(() {}); // Trigger rebuild after loading data
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 380;
                  return isNarrow
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isEditing)
                            ElevatedButton.icon(
                              onPressed:
                                  isOtherEditing || isJsonDirty
                                      ? null
                                      : () => _startEdit(provider),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (isEditing) ...[
                            ElevatedButton.icon(
                              onPressed: () => _cancelEdit(provider),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _saveEdit(provider),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          if (!isEditing) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  (!isEditing && !isOtherEditing)
                                      ? () => _updateView(provider)
                                      : null,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Update'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (!isEditing) ...[
                            ElevatedButton.icon(
                              onPressed:
                                  isOtherEditing || isJsonDirty
                                      ? null
                                      : () => _startEdit(provider),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  (!isEditing && !isOtherEditing)
                                      ? () => _updateView(provider)
                                      : null,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Update'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          if (isEditing) ...[
                            ElevatedButton.icon(
                              onPressed: () => _cancelEdit(provider),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _saveEdit(provider),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      );
                },
              ),
              const SizedBox(height: 8),
              // Tabs list (vertical, draggable)
              Expanded(
                child: ReorderableListView(
                  onReorder:
                      isEditing
                          ? (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _tabs.removeAt(oldIndex);
                              _tabs.insert(newIndex, item);
                            });
                            _setDirty();
                          }
                          : (oldIndex, newIndex) {}, // No-op if not editing
                  buildDefaultDragHandles: isEditing,
                  children: [
                    for (int i = 0; i < _tabs.length; i++)
                      _InputTabWidget(
                        key: ValueKey(_tabs[i].id),
                        tab: _tabs[i],
                        onChanged: (tab) {
                          setState(() => _tabs[i] = tab);
                          _setDirty();
                        },
                        onDelete: () {
                          setState(() {
                            _tabs.removeAt(i);
                            // Mark that tabs have been intentionally deleted
                            if (_tabs.isEmpty) {
                              _tabsDeleted = true;
                            }
                          });
                          _setDirty();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Add button (bottom right) - only show in edit mode
          if (isEditing)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () async {
                  final type = await showModalBottomSheet<String>(
                    context: context,
                    builder:
                        (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.person),
                              title: const Text('Header'),
                              onTap: () => Navigator.pop(context, 'header'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.star),
                              title: const Text('Skills'),
                              onTap: () => Navigator.pop(context, 'skills'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.list),
                              title: const Text('Body'),
                              onTap: () => Navigator.pop(context, 'body'),
                            ),
                          ],
                        ),
                  );
                  if (type != null) _addTab(type);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================
// _InputTab: Model for a tab (header/body)
// =====================================
class _InputTab {
  final String id;
  String type; // 'header', 'skills', or 'body'
  String name;
  bool expanded;
  dynamic data; // Map for header, List for skills, null for body
  static int _idCounter = 0;
  _InputTab({
    String? id,
    required this.type,
    required this.name,
    this.expanded = false,
    this.data,
  }) : id = id ?? 'tab_${_idCounter++}';

  // Method to update the counter based on existing IDs
  static void updateCounterFromExistingIds(List<_InputTab> tabs) {
    int maxId = -1;
    for (final tab in tabs) {
      if (tab.id.startsWith('tab_')) {
        try {
          final idNum = int.parse(tab.id.substring(4));
          if (idNum > maxId) maxId = idNum;
        } catch (_) {
          // Ignore non-numeric IDs
        }
      }
    }
    if (maxId >= _idCounter) {
      _idCounter = maxId + 1;
    }
  }

  _InputTab copy() => _InputTab(
    id: id,
    type: type,
    name: name,
    expanded: expanded,
    data:
        data is List
            ? List.from(data)
            : data is Map
            ? Map.from(data)
            : data,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'name': name,
    'expanded': expanded,
    'data': data,
  };
  static _InputTab fromMap(Map<String, dynamic> map) => _InputTab(
    id: map['id'],
    type: map['type'],
    name: map['name'],
    expanded: map['expanded'] ?? false,
    data: map['data'],
  );

  @override
  String toString() =>
      'id:$id|type:$type|name:$name|expanded:$expanded|data:$data';
}

// =====================================
// _InputTabWidget: UI for a single tab
// =====================================
class _InputTabWidget extends StatefulWidget {
  final _InputTab tab;
  final ValueChanged<_InputTab> onChanged;
  final VoidCallback? onDelete;
  const _InputTabWidget({
    super.key,
    required this.tab,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_InputTabWidget> createState() => _InputTabWidgetState();
}

class _InputTabWidgetState extends State<_InputTabWidget> {
  final Map<String, TextEditingController> _headerControllers = {};
  final List<Map<String, TextEditingController>> _skillsControllers = [];
  final List<TextEditingController> _linkControllers = [];

  // Persistent controller for tab name
  late final TextEditingController _tabNameController;

  // Track the number of links/skills to avoid unnecessary controller recreation
  int _lastLinksCount = 0;
  int _lastSkillsCount = 0;

  // Listeners for controllers
  final Map<String, VoidCallback> _headerListeners = {};
  final List<Map<String, VoidCallback>> _skillsListeners = [];
  final List<VoidCallback> _linkListeners = [];

  @override
  void initState() {
    super.initState();
    _tabNameController = TextEditingController(text: widget.tab.name);
    _tabNameController.addListener(_onTabNameChanged);
    _initControllers(force: true);
  }

  void _onTabNameChanged() {
    final newName = _tabNameController.text;
    if (newName != widget.tab.name) {
      widget.onChanged(widget.tab.copy()..name = newName);
    }
  }

  @override
  void didUpdateWidget(covariant _InputTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // DO NOT update _tabNameController.text at all
    // DO NOT re-init controllers unless type changes (not object reference)
    if (widget.tab.type != oldWidget.tab.type) {
      _initControllers(force: true);
    } else {
      _initControllers(force: false);
    }
  }

  @override
  void dispose() {
    _tabNameController.removeListener(_onTabNameChanged);
    _tabNameController.dispose();
    for (final c in _headerControllers.values) {
      c.dispose();
    }
    for (final m in _skillsControllers) {
      m['title']?.dispose();
      m['content']?.dispose();
    }
    for (final c in _linkControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers({bool force = false}) {
    final tab = widget.tab;
    // Remove old listeners
    _removeAllListeners();
    if (tab.type == 'header') {
      final data = Map<String, dynamic>.from(tab.data ?? {});
      for (final key in ['name', 'phone', 'address', 'email']) {
        if (force || !_headerControllers.containsKey(key)) {
          _headerControllers[key]?.dispose();
          _headerControllers[key] = TextEditingController(
            text: data[key]['value'],
          );
        }
        // Add listener
        _headerListeners[key]?.call();
        _headerListeners[key] = () {
          data[key]['value'] = _headerControllers[key]!.text;
        };
        _headerControllers[key]!.addListener(_headerListeners[key]!);
      }
      final links = data['links'] as List? ?? [];
      if (force || links.length != _lastLinksCount) {
        for (final c in _linkControllers) {
          c.dispose();
        }
        _linkControllers.clear();
        _linkListeners.clear();
        for (final link in links) {
          // Ensure both display and url fields exist
          link['display'] ??= '';
          link['url'] ??= '';
          final displayCtrl = TextEditingController(text: link['display']);
          final urlCtrl = TextEditingController(text: link['url']);
          _linkControllers.add(displayCtrl);
          _linkControllers.add(urlCtrl);
          final displayListener = () {
            link['display'] = displayCtrl.text;
          };
          final urlListener = () {
            link['url'] = urlCtrl.text;
          };
          _linkListeners.add(displayListener);
          _linkListeners.add(urlListener);
          displayCtrl.addListener(displayListener);
          urlCtrl.addListener(urlListener);
        }
        _lastLinksCount = links.length;
      }
    } else if (tab.type == 'skills') {
      final List skills = tab.data ?? [];
      if (force || skills.length != _lastSkillsCount) {
        for (final m in _skillsControllers) {
          m['title']?.dispose();
          m['content']?.dispose();
        }
        _skillsControllers.clear();
        _skillsListeners.clear();
        for (final skill in skills) {
          final titleCtrl = TextEditingController(text: skill['title'] ?? '');
          final contentCtrl = TextEditingController(
            text: skill['content'] ?? '',
          );
          _skillsControllers.add({'title': titleCtrl, 'content': contentCtrl});
          final titleListener = () {
            skill['title'] = titleCtrl.text;
          };
          final contentListener = () {
            skill['content'] = contentCtrl.text;
          };
          _skillsListeners.add({
            'title': titleListener,
            'content': contentListener,
          });
          titleCtrl.addListener(titleListener);
          contentCtrl.addListener(contentListener);
        }
        _lastSkillsCount = skills.length;
      }
    }
  }

  void _removeAllListeners() {
    for (final key in _headerControllers.keys) {
      if (_headerListeners[key] != null) {
        _headerControllers[key]?.removeListener(_headerListeners[key]!);
      }
    }
    for (int i = 0; i < _linkControllers.length; i++) {
      if (i < _linkListeners.length) {
        _linkControllers[i].removeListener(_linkListeners[i]);
      }
    }
    for (int i = 0; i < _skillsControllers.length; i++) {
      if (i < _skillsListeners.length) {
        _skillsControllers[i]['title']?.removeListener(
          _skillsListeners[i]['title']!,
        );
        _skillsControllers[i]['content']?.removeListener(
          _skillsListeners[i]['content']!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.input;
    final tabEnabled =
        widget.tab.data is Map
            ? (widget.tab.data['enabled'] ?? true)
            : (widget.tab.data is List
                ? (widget.tab.data.isNotEmpty &&
                        widget.tab.data[0]['enabled'] != null
                    ? widget.tab.data[0]['enabled']
                    : true)
                : true);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: tabEnabled,
              onChanged:
                  isEditing
                      ? (val) {
                        if (widget.tab.data is Map) {
                          final newData = Map<String, dynamic>.from(
                            widget.tab.data,
                          );
                          newData['enabled'] = val;
                          widget.onChanged(widget.tab.copy()..data = newData);
                        } else if (widget.tab.data is List) {
                          final newList = List.from(widget.tab.data);
                          if (newList.isNotEmpty) {
                            newList[0]['enabled'] = val;
                          }
                          widget.onChanged(widget.tab.copy()..data = newList);
                        }
                      }
                      : null,
            ),
            title:
                isEditing && widget.tab.expanded
                    ? TextFormField(
                      // Remove ValueKey to prevent field recreation and focus loss
                      controller: _tabNameController,
                      decoration: const InputDecoration(labelText: 'Tab Name'),
                      // No onChanged here, handled by controller listener
                    )
                    : Text(widget.tab.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEditing && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: widget.onDelete,
                  ),
                Icon(
                  widget.tab.expanded ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
            onTap:
                () => widget.onChanged(
                  _InputTab(
                    type: widget.tab.type,
                    name: widget.tab.name,
                    expanded: !widget.tab.expanded,
                    data: widget.tab.data,
                  ),
                ),
          ),
          if (widget.tab.expanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  tabEnabled
                      ? _buildTabContent(context, widget.tab, isEditing)
                      : Opacity(
                        opacity: 0.5,
                        child: AbsorbPointer(
                          absorbing: true,
                          child: _buildTabContent(
                            context,
                            widget.tab,
                            isEditing,
                          ),
                        ),
                      ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, _InputTab tab, bool isEditing) {
    if (tab.type == 'header') {
      final data = Map<String, dynamic>.from(tab.data ?? {});
      final links = data['links'] as List? ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...['name', 'phone', 'address', 'email'].map(
            (key) => _checkboxTextField(
              context,
              label: key[0].toUpperCase() + key.substring(1),
              controller: _headerControllers[key]!,
              enabled: data[key]['enabled'],
              isEditing: isEditing,
              onChanged: (_) {}, // No-op, handled by controller listener
              onEnable: (val) {
                data[key]['enabled'] = val;
                widget.onChanged(tab.copy()..data = data);
              },
              fieldKey: ValueKey('header-$key'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Links', style: Theme.of(context).textTheme.titleMedium),
          ...List.generate(links.length, (i) {
            final link = links[i];
            final displayController = _linkControllers[i * 2];
            final urlController = _linkControllers[i * 2 + 1];
            return Row(
              children: [
                Checkbox(
                  value: link['enabled'] ?? true,
                  onChanged:
                      isEditing
                          ? (val) {
                            link['enabled'] = val;
                            widget.onChanged(tab.copy()..data = data);
                          }
                          : null,
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('link-display-$i'),
                    controller: displayController,
                    enabled: isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                    onChanged: (_) {}, // No-op, handled by controller listener
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('link-url-$i'),
                    controller: urlController,
                    enabled: isEditing,
                    decoration: const InputDecoration(labelText: 'URL'),
                    onChanged: (_) {}, // No-op, handled by controller listener
                  ),
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      links.removeAt(i);
                      widget.onChanged(tab.copy()..data = data);
                      setState(() {}); // Only needed for add/remove
                    },
                  ),
              ],
            );
          }),
          if (isEditing)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Link'),
              onPressed: () {
                links.add({'display': '', 'url': '', 'enabled': true});
                widget.onChanged(tab.copy()..data = data);
                setState(() {}); // Only needed for add/remove
              },
            ),
        ],
      );
    } else if (tab.type == 'skills') {
      final List skills = tab.data ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(skills.length, (i) {
            final skill = skills[i];
            final ctrls = _skillsControllers[i];
            return Row(
              children: [
                Checkbox(
                  value: skill['enabled'] ?? true,
                  onChanged:
                      isEditing
                          ? (val) {
                            skill['enabled'] = val;
                            widget.onChanged(
                              tab.copy()..data = List.from(skills),
                            );
                          }
                          : null,
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('skill-title-$i'),
                    controller: ctrls['title'],
                    enabled: isEditing,
                    decoration: const InputDecoration(labelText: 'Skill Title'),
                    onChanged: (_) {}, // No-op, handled by controller listener
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('skill-content-$i'),
                    controller: ctrls['content'],
                    enabled: isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Ex: c++, python, ...',
                    ),
                    onChanged: (_) {}, // No-op, handled by controller listener
                  ),
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      skills.removeAt(i);
                      widget.onChanged(tab.copy()..data = List.from(skills));
                      setState(() {}); // Only needed for add/remove
                    },
                  ),
              ],
            );
          }),
          if (isEditing)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Skill'),
              onPressed: () {
                skills.add({'title': '', 'content': '', 'enabled': true});
                widget.onChanged(tab.copy()..data = List.from(skills));
                setState(() {}); // Only needed for add/remove
              },
            ),
        ],
      );
    } else {
      return const Text('Tab content for Body goes here.');
    }
  }

  Widget _checkboxTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required bool isEditing,
    required ValueChanged<String> onChanged,
    required ValueChanged<bool> onEnable,
    required Key fieldKey,
  }) {
    return Row(
      children: [
        Checkbox(
          value: enabled,
          onChanged: isEditing ? (val) => onEnable(val ?? false) : null,
        ),
        Expanded(
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            enabled: isEditing,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) {}, // No-op, handled by controller listener
          ),
        ),
      ],
    );
  }
}

// =====================================
// END OF FILE
// =====================================
