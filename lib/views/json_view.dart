// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/json.dart';
import 'dart:convert';
import '../providers/cv_data_provider.dart';

// =====================================
// JsonView Widget
// =====================================
class JsonView extends StatefulWidget {
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  const JsonView({super.key, this.onSave, this.onCancel});

  @override
  State<JsonView> createState() => _JsonViewState();
}

// =====================================
// _JsonViewState
// =====================================
class _JsonViewState extends State<JsonView> {
  bool _editing = false;
  late TextEditingController _controller;
  late CodeController _codeController;
  String? _originalData;
  bool _dirtyFromInput = false;

  // =====================================
  // initState & dispose
  // =====================================
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _codeController = CodeController(text: '', language: json);
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // =====================================
  // Edit/Cancel/Save/Update Logic
  // =====================================
  void _startEdit(CVDataProvider provider) {
    // Save the current selection before editing
    final oldSelection = _codeController.selection;
    setState(() {
      _editing = true;
      _originalData = provider.jsonData;
      // Pretty-print JSON for editing
      String prettyJson;
      try {
        final decoded =
            provider.jsonData.isNotEmpty ? jsonDecode(provider.jsonData) : null;
        prettyJson =
            decoded != null
                ? const JsonEncoder.withIndent('  ').convert(decoded)
                : '';
      } catch (e) {
        // Fallback: use raw data if parsing fails
        prettyJson = provider.jsonData;
      }
      _codeController.text = prettyJson;
      // Try to restore the selection if possible
      int offset = oldSelection.baseOffset;
      if (offset > prettyJson.length) offset = prettyJson.length;
      _codeController.selection = TextSelection.collapsed(offset: offset);
      provider.setEditMode(EditMode.json);
      // Show a quick pop down message about lag workaround
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'If editing lags, copy and paste the whole file to refresh the editor. This is a Flutter limitation.',
            style: TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.lightBlue,
        ),
      );
    });
  }

  void _cancelEdit(CVDataProvider provider) async {
    // Only confirm if there are unsaved changes
    final currentText = _codeController.text;
    final originalText = _originalData ?? provider.jsonData;
    if (currentText == originalText) {
      setState(() {
        _editing = false;
        provider.cancelEdit();
      });
      if (widget.onCancel != null) widget.onCancel!();
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
        _editing = false;
        _controller.text = originalText;
        provider.cancelEdit();
      });
      if (widget.onCancel != null) widget.onCancel!();
    }
  }

  void _saveEdit(CVDataProvider provider) {
    provider.updateJsonData(_codeController.text);
    provider.setEditMode(EditMode.none);
    setState(() {
      _editing = false;
      _dirtyFromInput = false;
    });
    provider.setInputDirtyFromJson();
    // Mark InputView as dirty so its Edit button is disabled
    // (Assumes InputView checks provider.inputDirtyFromJson)
    if (mounted) {
      // Notify InputView to update its dirty state if needed
      // (No direct call, but provider flag is set)
    }
    if (widget.onSave != null) widget.onSave!();
  }

  void _updateView(CVDataProvider provider) {
    // If input view is dirty, convert its tabs to JSON and update provider.jsonData
    if (provider.jsonDirtyFromInput) {
      provider.updateJsonData(provider.inputTabsJson);
      provider.clearJsonDirtyFromInput();
    }
    setState(() {
      _controller.text = provider.jsonData;
    });
  }

  // =====================================
  // Build Method
  // =====================================
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.json;
    final isOtherEditing = provider.editMode == EditMode.input;
    final jsonData = provider.jsonData;
    final inputDirty = provider.jsonDirtyFromInput;
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
          // =====================================
          // Action Buttons Row
          // =====================================
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
                              isOtherEditing || inputDirty
                                  ? null
                                  : () => _startEdit(provider),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      if (isEditing) ...[
                        ElevatedButton.icon(
                          onPressed: () => _cancelEdit(provider),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _saveEdit(provider),
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
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
                              isOtherEditing || inputDirty
                                  ? null
                                  : () => _startEdit(provider),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed:
                              (!isEditing && !isOtherEditing)
                                  ? () => _updateView(provider)
                                  : null,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Update'),
                        ),
                      ],
                      if (isEditing) ...[
                        ElevatedButton.icon(
                          onPressed: () => _cancelEdit(provider),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _saveEdit(provider),
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ],
                    ],
                  );
            },
          ),
          const SizedBox(height: 8),
          // =====================================
          // Editor/Viewer
          // =====================================
          if (isEditing)
            // Use CodeField for editing JSON with syntax highlighting and better performance
            Expanded(
              child: CodeField(
                controller: _codeController,
                textStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5, // Increased line spacing
                ),
                expands: true,
                maxLines: null,
                minLines: null,
                background: Theme.of(context).scaffoldBackgroundColor,
                cursorColor: Theme.of(context).colorScheme.primary,
                lineNumberStyle: LineNumberStyle(
                  textStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.7),
                    height: 1.6, // Increased line spacing for line numbers
                  ),
                ),
                // No language param here, syntax highlighting is set via CodeController
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
                        height: 1.6, // Increased line spacing
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
