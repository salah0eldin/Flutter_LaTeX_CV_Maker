// Desktop-specific implementation for import/export/history using dart:io
// To be filled with logic moved from main_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cv_data_provider.dart';
import 'cv_file_handler.dart';

class CVFileHandlerDesktop implements CVFileHandler {
  @override
  Future<void> saveToHistory(BuildContext context, String jsonData) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save to History'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter a name for your CV',
              labelText: 'CV Name',
            ),
            autofocus: true,
            onSubmitted: (value) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cv_history_$sanitized.json');
      await file.writeAsString(jsonData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$sanitized" to history'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Future<String?> importFromFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      try {
        json.decode(content);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imported JSON file!'),
            backgroundColor: Colors.green,
          ),
        );
        return content;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON file'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> exportToFile(BuildContext context, String jsonData) async {
    final directory = await getApplicationDocumentsDirectory();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save JSON File',
      fileName: 'cv.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: directory.path,
    );
    if (outputFile != null) {
      if (!outputFile.endsWith('.json')) {
        outputFile = '$outputFile.json';
      }
      final file = File(outputFile);
      await file.writeAsString(jsonData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exported JSON file!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Future<List<String>> getHistoryKeys(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().whereType<File>();
    return files
        .where(
          (f) => f.path.contains('cv_history_') && f.path.endsWith('.json'),
        )
        .map((f) => f.path.split('/').last.replaceAll('.json', ''))
        .toList();
  }

  @override
  Future<void> removeHistoryKey(BuildContext context, String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$key.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String?> loadHistoryItem(BuildContext context, String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$key.json');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  // Temp data: use temp directory for desktop
  static const String _tempFileName = 'cv_temp_autosave.json';
  static const String _tempLatexFileName = 'cv_temp_autosave.tex';

  @override
  Future<void> loadTempData(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempFileName');
      if (await tempFile.exists()) {
        final jsonData = await tempFile.readAsString();
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Future<void> saveTempData(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempFileName');
      final jsonData = context.read<CVDataProvider>().jsonData;
      await tempFile.writeAsString(jsonData);
    } catch (_) {}
  }

  @override
  Future<void> loadTempLatexData(BuildContext context) async {
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

  @override
  Future<void> saveTempLatexData(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_tempLatexFileName');
      final latexData = context.read<CVDataProvider>().latexOutput;
      await tempFile.writeAsString(latexData);
    } catch (_) {}
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerDesktop();
