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

  // Add new tab (header or body)
  void _addTab(String type) {
    setState(() {
      if (type == 'header') {
        _tabs.add(_InputTab(type: 'header', name: 'Header'));
      } else {
        _tabs.add(_InputTab(type: 'body', name: 'Body Tab'));
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

  void _saveEdit(CVDataProvider provider) {
    _tabsBackup = null;
    provider.setEditMode(EditMode.none);
    // After saving, mark JSON as dirty, but do NOT update provider.jsonData here
    // Instead, update provider.inputTabsJson for JsonView to use on update
    final order = _tabs.map((t) => t.name).toList();
    final jsonMap = {'order': order};
    final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonMap);
    provider.inputTabsJson = prettyJson;
    provider.setJsonDirtyFromInput();
    setState(() {
      _dirtyFromJson = false;
    });
  }

  // Helper to convert _tabs to JSON map
  Map<String, dynamic> _tabsToJson() {
    final order = _tabs.map((t) => t.name).toList();
    return {'order': order};
  }

  void _updateView(CVDataProvider provider) {
    // Parse provider.jsonData and update _tabs
    try {
      final data = provider.parsedJsonData;
      if (data is Map && data['order'] is List) {
        final order = List<String>.from(data['order']);
        setState(() {
          _tabs.clear();
          for (final name in order) {
            _tabs.add(
              _InputTab(type: name == 'Header' ? 'header' : 'body', name: name),
            );
          }
          _dirtyFromJson = false;
        });
        provider.clearInputDirtyFromJson();
        // Also update draft in provider
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.input;
    final isOtherEditing = provider.editMode == EditMode.json;
    final isJsonDirty = provider.inputDirtyFromJson;
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
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (isEditing) ...[
                            ElevatedButton.icon(
                              onPressed: () => _cancelEdit(provider),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _saveEdit(provider),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
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
                                backgroundColor: Colors.deepOrange,
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
                                backgroundColor: Colors.purple,
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
                                backgroundColor: Colors.deepOrange,
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
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _saveEdit(provider),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
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
                        key: ValueKey(_tabs[i]),
                        tab: _tabs[i],
                        onChanged: (tab) {
                          setState(() => _tabs[i] = tab);
                          _setDirty();
                        },
                        onDelete: () {
                          setState(() {
                            _tabs.removeAt(i);
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
  String type; // 'header' or 'body'
  String name;
  bool expanded;
  _InputTab({required this.type, required this.name, this.expanded = false});

  _InputTab copy() => _InputTab(type: type, name: name, expanded: expanded);

  Map<String, dynamic> toMap() => {
    'type': type,
    'name': name,
    'expanded': expanded,
  };
  static _InputTab fromMap(Map<String, dynamic> map) => _InputTab(
    type: map['type'],
    name: map['name'],
    expanded: map['expanded'] ?? false,
  );

  @override
  String toString() => 'type:$type|name:$name|expanded:$expanded';
}

// =====================================
// _InputTabWidget: UI for a single tab
// =====================================
class _InputTabWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final provider = context.read<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.input;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(tab.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEditing && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                Icon(tab.expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap:
                () => onChanged(
                  _InputTab(
                    type: tab.type,
                    name: tab.name,
                    expanded: !tab.expanded,
                  ),
                ),
          ),
          if (tab.expanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Tab content for  ${tab.name} (${tab.type}) goes here.',
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================
// END OF FILE
// =====================================
