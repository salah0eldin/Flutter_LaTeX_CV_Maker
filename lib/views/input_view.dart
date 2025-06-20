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
              'name': {'enabled': true, 'value': ''},
              'phone': {'enabled': true, 'value': ''},
              'address': {'enabled': true, 'value': ''},
              'email': {'enabled': true, 'value': ''},
              'links':
                  <
                    Map<String, dynamic>
                  >[], // Each: {'enabled': true, 'display': '', 'url': ''}
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
                >[], // Each: {'enabled': true, 'title': '', 'content': ''}
          ),
        );
      } else {
        _tabs.add(
          _InputTab(
            type: 'body',
            name: name,
            data: {
              'enabled': true,
              'instances': [
                {
                  'enabled': true,
                  'mainHeader': {'enabled': true, 'value': ''},
                  'extraInfo': {'enabled': true, 'value': ''},
                  'link': {'enabled': true, 'value': ''},
                  'date': {'enabled': true, 'value': ''},
                  'secondaryHeader': {'enabled': true, 'value': ''},
                  'location': {'enabled': true, 'value': ''},
                  'descriptions': <Map<String, dynamic>>[],
                },
              ],
            },
          ),
        );
      }
    });
    _setDirty();
  }

  void _setDirty() {
    setState(() {
      _dirtyFromJson = false;
    });
    // Save draft to provider (auto-save will be triggered automatically)
    final provider = context.read<CVDataProvider>();
    provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
  }

  // Note: Autosave is now handled automatically via CVDataProvider callbacks
  // No need for manual autosave calls since data changes trigger auto-save

  // Clear all tabs with confirmation
  Future<void> _clearAllTabs() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Tabs?'),
            content: const Text(
              'Are you sure you want to remove all tabs? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (shouldClear == true) {
      setState(() {
        _tabs.clear();
        _tabsDeleted = true;
      });
      _setDirty();
    }
  }

  // Add default tabs with confirmation if tabs exist
  Future<void> _addDefaultTabs() async {
    bool shouldAdd = true;

    if (_tabs.isNotEmpty) {
      shouldAdd =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Add Default Tabs?'),
                  content: const Text(
                    'This will add default tabs to your existing tabs. Continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ) ??
          false;
    }

    if (shouldAdd) {
      setState(() {
        _tabsDeleted = false;

        // Define default tabs
        final defaultTabs = [
          {'type': 'header', 'name': 'Header'},
          {'type': 'body', 'name': 'Education'},
          {'type': 'body', 'name': 'Work Experience'},
          {'type': 'skills', 'name': 'Skills'},
          {'type': 'body', 'name': 'Projects'},
          {'type': 'body', 'name': 'Courses'},
          {'type': 'body', 'name': 'Extracurricular Activities'},
        ];

        // Add tabs only if they don't already exist
        for (final defaultTab in defaultTabs) {
          final name = defaultTab['name']!;
          final type = defaultTab['type']!;

          // Check if tab with this name already exists
          if (!_tabs.any((tab) => tab.name == name)) {
            if (type == 'header') {
              _tabs.add(
                _InputTab(
                  type: 'header',
                  name: name,
                  data: {
                    'name': {'enabled': true, 'value': ''},
                    'phone': {'enabled': true, 'value': ''},
                    'address': {'enabled': true, 'value': ''},
                    'email': {'enabled': true, 'value': ''},
                    'links': <Map<String, dynamic>>[],
                  },
                ),
              );
            } else if (type == 'skills') {
              _tabs.add(
                _InputTab(
                  type: 'skills',
                  name: name,
                  data: <Map<String, dynamic>>[],
                ),
              );
            } else {
              // Body tab with customized field enabled/disabled states
              final bodyData = _getDefaultBodyTabData(name);
              _tabs.add(_InputTab(type: 'body', name: name, data: bodyData));
            }
          }
        }
      });
      _setDirty();
    }
  }

  // Get customized field enabled/disabled states for default body tabs
  Map<String, dynamic> _getDefaultBodyTabData(String tabName) {
    // Helper function to create a single instance with customized field states
    Map<String, dynamic> createInstance(Map<String, bool> fieldStates) {
      return {
        'enabled': true, // Instance is enabled by default
        'expanded': true, // New instances start expanded
        'mainHeader': {
          'enabled': fieldStates['mainHeader'] ?? true,
          'value': '',
        },
        'extraInfo': {'enabled': fieldStates['extraInfo'] ?? true, 'value': ''},
        'link': {'enabled': fieldStates['link'] ?? true, 'value': ''},
        'date': {'enabled': fieldStates['date'] ?? true, 'value': ''},
        'secondaryHeader': {
          'enabled': fieldStates['secondaryHeader'] ?? true,
          'value': '',
        },
        'location': {'enabled': fieldStates['location'] ?? true, 'value': ''},
        'descriptions': <Map<String, dynamic>>[],
      };
    }

    // Customize per tab - user can modify these as needed
    Map<String, bool> fieldStates;
    switch (tabName) {
      case 'Education':
        fieldStates = {
          'mainHeader': true, // Degree/School name
          'extraInfo': false, // Usually not needed for education
          'link': false, // Usually not needed for education
          'date': true, // Graduation date
          'secondaryHeader': true, // Field of study
          'location': true, // School location
        };
        break;

      case 'Work Experience':
        fieldStates = {
          'mainHeader': true, // Job title
          'extraInfo': false, // Usually not needed for work
          'link': true, // Company website
          'date': true, // Employment period
          'secondaryHeader': true, // Company name
          'location': true, // Work location
        };
        break;

      case 'Projects':
        fieldStates = {
          'mainHeader': true, // Project name
          'extraInfo': true, // Technologies used
          'link': true, // Project link/repo
          'date': true, // Project period
          'secondaryHeader': false, // Usually not needed
          'location': false, // Usually not needed for projects
        };
        break;

      case 'Courses':
        fieldStates = {
          'mainHeader': true, // Course name
          'extraInfo': false, // Usually not needed
          'link': true, // Course/certificate link
          'date': true, // Course completion date
          'secondaryHeader': true, // Institution/provider
          'location': false, // Usually online or not relevant
        };
        break;

      case 'Extracurricular Activities':
        fieldStates = {
          'mainHeader': true, // Activity/role name
          'extraInfo': true, // Skills gained or details
          'link': false, // Usually not needed
          'date': true, // Activity period
          'secondaryHeader': true, // Organization name
          'location': true, // Activity location
        };
        break;

      default:
        // For any other body tab names, use default configuration (all enabled)
        fieldStates = {
          'mainHeader': true,
          'extraInfo': true,
          'link': true,
          'date': true,
          'secondaryHeader': true,
          'location': true,
        };
        break;
    }

    // Return body tab data with one initial instance
    return {
      'enabled': true,
      'instances': [createInstance(fieldStates)],
    };
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
        // Place enabled attribute first
        headerSection['enabled'] = data['enabled'] ?? true;
        for (final key in ['name', 'phone', 'address', 'email']) {
          headerSection[key] = {
            'enabled': data[key]['enabled'],
            'value': data[key]['value'],
          };
        }
        headerSection['links'] =
            (data['links'] as List?)
                ?.map(
                  (link) => {
                    'enabled': link['enabled'],
                    'display': link['display'],
                    'url': link['url'],
                  },
                )
                .toList() ??
            [];
        headerSection['id'] = tab.id;
        jsonMap[tab.name] = headerSection;
      } else if (tab.type == 'skills') {
        final List skills = tab.data ?? [];
        jsonMap[tab.name] = {
          'enabled': skills.isNotEmpty ? (skills[0]['enabled'] ?? true) : true,
          'skills':
              skills
                  .map(
                    (s) => {
                      'enabled': s['enabled'],
                      'title': s['title'],
                      'content': s['content'],
                    },
                  )
                  .toList(),
          'id': tab.id,
        };
      } else if (tab.type == 'body') {
        final data = Map<String, dynamic>.from(tab.data ?? {});
        final bodySection = <String, dynamic>{};

        // Place enabled attribute first
        bodySection['enabled'] = data['enabled'] ?? true;

        // Handle instances array
        final instances = data['instances'] as List? ?? [];
        bodySection['instances'] =
            instances.map((instance) {
              final instanceMap = <String, dynamic>{};

              // Add instance-level enabled state
              instanceMap['enabled'] = instance['enabled'] ?? true;

              // Add all body fields for this instance
              for (final key in [
                'mainHeader',
                'extraInfo',
                'link',
                'date',
                'secondaryHeader',
                'location',
              ]) {
                instanceMap[key] = {
                  'enabled': instance[key]?['enabled'] ?? true,
                  'value': instance[key]?['value'] ?? '',
                };
              }

              // Add descriptions array for this instance
              instanceMap['descriptions'] =
                  (instance['descriptions'] as List?)
                      ?.map(
                        (desc) => {
                          'enabled': desc['enabled'] ?? true,
                          'value': desc['value'] ?? '',
                        },
                      )
                      .toList() ??
                  [];

              return instanceMap;
            }).toList();

        bodySection['id'] = tab.id;
        jsonMap[tab.name] = bodySection;
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
    // --- AUTOSAVE: Save draft to provider after every save (auto-save will be triggered automatically) ---
    provider.inputTabsDraft = _tabs.map((t) => t.toMap()).toList();
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
              // Body tab - check if it has the new structured format
              final bodyData = <String, dynamic>{
                'enabled': section['enabled'] ?? true,
              };

              // Check if it's the new multi-instance format with 'instances' array
              if (section['instances'] != null &&
                  section['instances'] is List) {
                // New multi-instance format - parse each instance
                final instances = <Map<String, dynamic>>[];
                for (final instanceData in section['instances']) {
                  final instance = <String, dynamic>{
                    'enabled':
                        instanceData['enabled'] ??
                        true, // Default enabled for loaded data
                    'expanded':
                        instanceData['expanded'] ??
                        true, // Default expanded for loaded data
                  };

                  // Parse each field in the instance
                  for (final key in [
                    'mainHeader',
                    'extraInfo',
                    'link',
                    'date',
                    'secondaryHeader',
                    'location',
                  ]) {
                    instance[key] = {
                      'enabled': instanceData[key]?['enabled'] ?? true,
                      'value': instanceData[key]?['value'] ?? '',
                    };
                  }

                  // Handle descriptions array for this instance
                  instance['descriptions'] =
                      (instanceData['descriptions'] as List?)
                          ?.map(
                            (desc) => {
                              'enabled': desc['enabled'] ?? true,
                              'value': desc['value'] ?? '',
                            },
                          )
                          .toList() ??
                      <Map<String, dynamic>>[];

                  instances.add(instance);
                }
                bodyData['instances'] = instances;
              } else if (section['mainHeader'] != null ||
                  section['extraInfo'] != null ||
                  section['skills'] != null ||
                  section['link'] != null ||
                  section['date'] != null ||
                  section['secondaryHeader'] != null ||
                  section['location'] != null ||
                  section['descriptions'] != null) {
                // Legacy structured format (single instance) - convert to multi-instance format
                final singleInstance = <String, dynamic>{
                  'expanded': true, // Default expanded for legacy data
                };

                // Handle legacy 'skills' field as 'extraInfo'
                final extraInfoValue =
                    section['extraInfo']?['value'] ??
                    section['skills']?['value'] ??
                    '';
                final extraInfoEnabled =
                    section['extraInfo']?['enabled'] ??
                    section['skills']?['enabled'] ??
                    true;

                for (final key in [
                  'mainHeader',
                  'link',
                  'date',
                  'secondaryHeader',
                  'location',
                ]) {
                  singleInstance[key] = {
                    'enabled': section[key]?['enabled'] ?? true,
                    'value': section[key]?['value'] ?? '',
                  };
                }

                // Handle extraInfo (with legacy skills fallback)
                singleInstance['extraInfo'] = {
                  'enabled': extraInfoEnabled,
                  'value': extraInfoValue,
                };

                // Handle descriptions array
                singleInstance['descriptions'] =
                    (section['descriptions'] as List?)
                        ?.map(
                          (desc) => {
                            'enabled': desc['enabled'] ?? true,
                            'value': desc['value'] ?? '',
                          },
                        )
                        .toList() ??
                    <Map<String, dynamic>>[];

                bodyData['instances'] = [singleInstance];
              } else {
                // Minimal format - initialize with default single instance
                final defaultInstance = <String, dynamic>{'expanded': true};

                for (final key in [
                  'mainHeader',
                  'extraInfo',
                  'link',
                  'date',
                  'secondaryHeader',
                  'location',
                ]) {
                  defaultInstance[key] = {'enabled': true, 'value': ''};
                }
                defaultInstance['descriptions'] = <Map<String, dynamic>>[];

                bodyData['instances'] = [defaultInstance];
              }

              newTabs.add(
                _InputTab(
                  type: 'body',
                  name: name,
                  data: bodyData,
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
              // Body tab - check if it has the new structured format
              final bodyData = <String, dynamic>{
                'enabled': section['enabled'] ?? true,
              };

              // Check if it's the new multi-instance format with 'instances' array
              if (section['instances'] != null &&
                  section['instances'] is List) {
                // New multi-instance format - parse each instance
                final instances = <Map<String, dynamic>>[];
                for (final instanceData in section['instances']) {
                  final instance = <String, dynamic>{
                    'enabled':
                        instanceData['enabled'] ??
                        true, // Default enabled for loaded data
                    'expanded':
                        instanceData['expanded'] ??
                        true, // Default expanded for loaded data
                  };

                  // Parse each field in the instance
                  for (final key in [
                    'mainHeader',
                    'extraInfo',
                    'link',
                    'date',
                    'secondaryHeader',
                    'location',
                  ]) {
                    instance[key] = {
                      'enabled': instanceData[key]?['enabled'] ?? true,
                      'value': instanceData[key]?['value'] ?? '',
                    };
                  }

                  // Handle descriptions array for this instance
                  instance['descriptions'] =
                      (instanceData['descriptions'] as List?)
                          ?.map(
                            (desc) => {
                              'enabled': desc['enabled'] ?? true,
                              'value': desc['value'] ?? '',
                            },
                          )
                          .toList() ??
                      <Map<String, dynamic>>[];

                  instances.add(instance);
                }
                bodyData['instances'] = instances;
              } else if (section['mainHeader'] != null ||
                  section['extraInfo'] != null ||
                  section['skills'] != null ||
                  section['link'] != null ||
                  section['date'] != null ||
                  section['secondaryHeader'] != null ||
                  section['location'] != null ||
                  section['descriptions'] != null) {
                // Legacy structured format (single instance) - convert to multi-instance format
                final singleInstance = <String, dynamic>{
                  'expanded': true, // Default expanded for legacy data
                };

                // Handle legacy 'skills' field as 'extraInfo'
                final extraInfoValue =
                    section['extraInfo']?['value'] ??
                    section['skills']?['value'] ??
                    '';
                final extraInfoEnabled =
                    section['extraInfo']?['enabled'] ??
                    section['skills']?['enabled'] ??
                    true;

                for (final key in [
                  'mainHeader',
                  'link',
                  'date',
                  'secondaryHeader',
                  'location',
                ]) {
                  singleInstance[key] = {
                    'enabled': section[key]?['enabled'] ?? true,
                    'value': section[key]?['value'] ?? '',
                  };
                }

                // Handle extraInfo (with legacy skills fallback)
                singleInstance['extraInfo'] = {
                  'enabled': extraInfoEnabled,
                  'value': extraInfoValue,
                };

                // Handle descriptions array
                singleInstance['descriptions'] =
                    (section['descriptions'] as List?)
                        ?.map(
                          (desc) => {
                            'enabled': desc['enabled'] ?? true,
                            'value': desc['value'] ?? '',
                          },
                        )
                        .toList() ??
                    <Map<String, dynamic>>[];

                bodyData['instances'] = [singleInstance];
              } else {
                // Minimal format - initialize with default single instance
                final defaultInstance = <String, dynamic>{'expanded': true};

                for (final key in [
                  'mainHeader',
                  'extraInfo',
                  'link',
                  'date',
                  'secondaryHeader',
                  'location',
                ]) {
                  defaultInstance[key] = {'enabled': true, 'value': ''};
                }
                defaultInstance['descriptions'] = <Map<String, dynamic>>[];

                bodyData['instances'] = [defaultInstance];
              }

              newTabs.add(
                _InputTab(
                  type: 'body',
                  name: name,
                  data: bodyData,
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
                  final isNarrow = constraints.maxWidth < 440;
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
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _clearAllTabs,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _addDefaultTabs,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Default'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
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
                                backgroundColor:
                                    (!isEditing && !isOtherEditing)
                                        ? Colors.blue
                                        : Colors.grey,
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
                                backgroundColor:
                                    (!isEditing && !isOtherEditing)
                                        ? Colors.blue
                                        : Colors.grey,
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
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _clearAllTabs,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _addDefaultTabs,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Default'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
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
    } else if (tab.type == 'body') {
      // Body tabs now use instances structure with initialValue, no controllers needed
      // This simplifies the controller management significantly
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
    } else if (tab.type == 'body') {
      final data = Map<String, dynamic>.from(tab.data ?? {});
      final instances = data['instances'] as List? ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instances (${instances.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Display all instances with drag-and-drop reordering
          if (instances.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: instances.length,
              buildDefaultDragHandles: isEditing,
              onReorder:
                  isEditing
                      ? (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final instance = instances.removeAt(oldIndex);
                        instances.insert(newIndex, instance);
                        widget.onChanged(tab.copy()..data = data);
                        setState(
                          () {},
                        ); // Trigger rebuild to update instance numbers
                      }
                      : (oldIndex, newIndex) {}, // No-op if not editing
              itemBuilder: (context, instanceIndex) {
                final instance = instances[instanceIndex];
                final descriptions = instance['descriptions'] as List? ?? [];

                // Ensure backward compatibility: add 'expanded' field if missing
                final isExpanded = instance['expanded'] ?? true;
                final isInstanceEnabled = instance['enabled'] ?? true;

                // Get enhanced colors for better contrast, especially in dark mode
                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;
                var cardColor =
                    isDark ? theme.colorScheme.surface : theme.cardColor;
                var borderColor =
                    isDark
                        ? theme.colorScheme.outline.withOpacity(0.5)
                        : theme.dividerColor;

                // Apply disabled styling if instance is not enabled
                if (!isInstanceEnabled) {
                  cardColor = cardColor.withOpacity(0.5);
                  borderColor = borderColor.withOpacity(0.3);
                }

                return Card(
                  key: ValueKey(
                    'body-instance-$instanceIndex-${instance.hashCode}',
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: cardColor,
                  elevation: isDark ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: borderColor,
                      width: isDark ? 1.5 : 1.0,
                    ),
                  ),
                  child: Opacity(
                    opacity: isInstanceEnabled ? 1.0 : 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instance header with expand/collapse, enabled checkbox, drag handle and delete button
                          Row(
                            children: [
                              if (isEditing && instances.length > 1)
                                Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey[600],
                                ),
                              if (isEditing && instances.length > 1)
                                const SizedBox(width: 8),
                              // Instance enabled checkbox
                              if (isEditing)
                                Tooltip(
                                  message: 'Enable/disable this instance',
                                  child: Checkbox(
                                    value: instance['enabled'] ?? true,
                                    onChanged: (value) {
                                      instance['enabled'] = value ?? true;
                                      widget.onChanged(tab.copy()..data = data);
                                      setState(() {});
                                    },
                                  ),
                                ),
                              if (isEditing) const SizedBox(width: 8),
                              // Expand/collapse button
                              InkWell(
                                onTap: () {
                                  instance['expanded'] = !isExpanded;
                                  widget.onChanged(tab.copy()..data = data);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Instance ${instanceIndex + 1}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (isEditing && instances.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    instances.removeAt(instanceIndex);
                                    widget.onChanged(tab.copy()..data = data);
                                    setState(
                                      () {},
                                    ); // Only needed for add/remove
                                  },
                                ),
                            ],
                          ),

                          // Collapsible content
                          if (isExpanded) ...[
                            const SizedBox(height: 16),

                            // Main Header field
                            _buildInstanceField(
                              context,
                              label: 'Main Header',
                              instance: instance,
                              fieldKey: 'mainHeader',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Extra Info field
                            _buildInstanceField(
                              context,
                              label: 'Extra Info',
                              instance: instance,
                              fieldKey: 'extraInfo',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Link field
                            _buildInstanceField(
                              context,
                              label: 'Link',
                              instance: instance,
                              fieldKey: 'link',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Date field
                            _buildInstanceField(
                              context,
                              label: 'Date',
                              instance: instance,
                              fieldKey: 'date',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Secondary Header field
                            _buildInstanceField(
                              context,
                              label: 'Secondary Header',
                              instance: instance,
                              fieldKey: 'secondaryHeader',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Location field
                            _buildInstanceField(
                              context,
                              label: 'Location',
                              instance: instance,
                              fieldKey: 'location',
                              instanceIndex: instanceIndex,
                              isEditing: isEditing,
                              onChanged:
                                  () =>
                                      widget.onChanged(tab.copy()..data = data),
                            ),
                            const SizedBox(height: 8),

                            // Descriptions section
                            Text(
                              'Descriptions',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            ...List.generate(descriptions.length, (i) {
                              final desc = descriptions[i];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: desc['enabled'] ?? true,
                                      onChanged:
                                          isEditing
                                              ? (val) {
                                                desc['enabled'] = val;
                                                widget.onChanged(
                                                  tab.copy()..data = data,
                                                );
                                              }
                                              : null,
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'body-description-$instanceIndex-$i',
                                        ),
                                        initialValue: desc['value'] ?? '',
                                        enabled: isEditing,
                                        decoration: InputDecoration(
                                          labelText: 'Description ${i + 1}',
                                          border: const OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          desc['value'] = value;
                                        },
                                      ),
                                    ),
                                    if (isEditing)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          descriptions.removeAt(i);
                                          widget.onChanged(
                                            tab.copy()..data = data,
                                          );
                                          setState(
                                            () {},
                                          ); // Only needed for add/remove
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (isEditing)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Description'),
                                  onPressed: () {
                                    descriptions.add({
                                      'enabled': true,
                                      'value': '',
                                    });
                                    widget.onChanged(tab.copy()..data = data);
                                    setState(
                                      () {},
                                    ); // Only needed for add/remove
                                  },
                                ),
                              ),
                          ], // Close the if (isExpanded) conditional content
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Add instance button
          if (isEditing)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Create a new instance with default field states based on the first instance
                  final firstInstance =
                      instances.isNotEmpty ? instances[0] : null;
                  final newInstance = <String, dynamic>{
                    'enabled': true, // New instances start enabled
                    'expanded': true, // New instances start expanded
                  };

                  for (final key in [
                    'mainHeader',
                    'extraInfo',
                    'link',
                    'date',
                    'secondaryHeader',
                    'location',
                  ]) {
                    newInstance[key] = {
                      'enabled': firstInstance?[key]?['enabled'] ?? true,
                      'value': '',
                    };
                  }
                  newInstance['descriptions'] = <Map<String, dynamic>>[];

                  instances.add(newInstance);
                  widget.onChanged(tab.copy()..data = data);
                  setState(() {}); // Only needed for add/remove
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Instance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      );
    } else {
      return const Text('Unknown tab type.');
    }
  }

  // Helper method to build instance fields
  Widget _buildInstanceField(
    BuildContext context, {
    required String label,
    required Map<String, dynamic> instance,
    required String fieldKey,
    required int instanceIndex,
    required bool isEditing,
    required VoidCallback onChanged,
  }) {
    final fieldData = instance[fieldKey] ?? {'enabled': true, 'value': ''};

    return Row(
      children: [
        Checkbox(
          value: fieldData['enabled'] ?? true,
          onChanged:
              isEditing
                  ? (val) {
                    fieldData['enabled'] = val;
                    onChanged();
                  }
                  : null,
        ),
        Expanded(
          child: TextFormField(
            key: ValueKey('body-$fieldKey-$instanceIndex'),
            initialValue: fieldData['value'] ?? '',
            enabled: isEditing,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              fieldData['value'] = value;
            },
          ),
        ),
      ],
    );
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
