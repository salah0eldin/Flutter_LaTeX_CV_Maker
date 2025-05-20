import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cv_data_provider.dart';

class InputView extends StatefulWidget {
  const InputView({super.key});

  @override
  State<InputView> createState() => _InputViewState();
}

class _InputViewState extends State<InputView> {
  void _startEdit(CVDataProvider provider) {
    provider.setEditMode(EditMode.input);
  }

  void _cancelEdit(CVDataProvider provider) {
    provider.cancelEdit();
  }

  void _saveEdit(CVDataProvider provider) {
    provider.setEditMode(EditMode.none);
  }

  void _updateView(CVDataProvider provider) {
    // Implement update logic if needed
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CVDataProvider>();
    final isEditing = provider.editMode == EditMode.input;
    final isOtherEditing = provider.editMode == EditMode.json;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              return isNarrow
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            isOtherEditing ? null : () => _startEdit(provider),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _cancelEdit(provider),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isEditing ? () => _saveEdit(provider) : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
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
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            isOtherEditing ? null : () => _startEdit(provider),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                      if (isEditing) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _cancelEdit(provider),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isEditing ? () => _saveEdit(provider) : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
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
                  );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                isEditing
                    ? 'Input Form Editing...'
                    : 'Input Form View - Coming Soon',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
