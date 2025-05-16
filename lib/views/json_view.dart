import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import '../providers/cv_data_provider.dart';

class JsonView extends StatefulWidget {
  const JsonView({super.key});

  @override
  State<JsonView> createState() => _JsonViewState();
}

class _JsonViewState extends State<JsonView> {
  bool _editing = false;
  late TextEditingController _controller;
  String? _originalData;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit(CVDataProvider provider) {
    setState(() {
      _editing = true;
      _originalData = provider.jsonData;
      _controller.text = provider.jsonData;
      provider.setEditMode(EditMode.json);
    });
  }

  void _cancelEdit(CVDataProvider provider) async {
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
        _editing = false;
        _controller.text = _originalData ?? provider.jsonData;
        provider.cancelEdit();
      });
    }
  }

  void _saveEdit(CVDataProvider provider) {
    provider.updateJsonData(_controller.text);
    provider.setEditMode(EditMode.none);
    setState(() {
      _editing = false;
    });
  }

  void _updateView(CVDataProvider provider) {
    if (!_editing) {
      setState(() {
        _controller.text = provider.jsonData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.json;
    final isOtherEditing = provider.editMode == EditMode.input;
    final jsonData = provider.jsonData;
    // Only update the controller if not editing
    if (!isEditing && !_editing && _controller.text != jsonData) {
      _controller.value = TextEditingValue(
        text: jsonData,
        selection: TextSelection.collapsed(offset: jsonData.length),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              if (!isEditing)
                ElevatedButton.icon(
                  onPressed: isOtherEditing ? null : () => _startEdit(provider),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              if (isEditing)
                ElevatedButton.icon(
                  onPressed: () => _cancelEdit(provider),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isEditing ? () => _saveEdit(provider) : null,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _updateView(provider),
                icon: const Icon(Icons.refresh),
                label: const Text('Update'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing)
            // Use Expanded to provide constraints inside Column, with a plain TextField for best performance
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'No JSON loaded.',
                  hintStyle: TextStyle(color: Colors.black26),
                  contentPadding: EdgeInsets.zero,
                ),
                autofocus: true,
                cursorColor: Colors.blue,
              ),
            )
          else
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800, width: 1),
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: HighlightView(
                      jsonData.isEmpty ? 'No JSON loaded.' : jsonData,
                      language: 'json',
                      theme: vs2015Theme,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
