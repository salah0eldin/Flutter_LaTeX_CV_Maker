import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/cv_data_provider.dart';
import 'cv_file_handler.dart';

class CVFileHandlerWeb implements CVFileHandler {
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
      final key = 'cv_history_$sanitized';
      html.window.localStorage[key] = jsonData;
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
    final input = html.FileUploadInputElement();
    input.accept = '.json,application/json';
    final completer = Completer<String?>();
    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file != null) {
        final reader = html.FileReader();
        reader.readAsText(file);
        reader.onLoadEnd.listen((event) {
          completer.complete(reader.result as String?);
        });
      } else {
        completer.complete(null);
      }
    });
    input.click();
    final result = await completer.future;
    if (result != null) {
      try {
        json.decode(result);
        // Success message now handled in main_screen.dart _importJson() method
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
    return result;
  }

  @override
  Future<void> exportToFile(BuildContext context, String jsonData) async {
    final bytes = utf8.encode(jsonData);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'cv.json')
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported JSON file (check your downloads)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Future<List<String>> getHistoryKeys(BuildContext context) async {
    return html.window.localStorage.keys
        .where((k) => k.startsWith('cv_history_'))
        .toList();
  }

  @override
  Future<void> removeHistoryKey(BuildContext context, String key) async {
    html.window.localStorage.remove(key);
  }

  @override
  Future<String?> loadHistoryItem(BuildContext context, String key) async {
    return html.window.localStorage[key];
  }

  // Temp data: use localStorage for web
  static const String _tempFileName = 'cv_temp_autosave.json';
  static const String _tempLatexFileName = 'cv_temp_autosave.tex';

  @override
  Future<void> loadTempData(BuildContext context) async {
    final jsonData = html.window.localStorage[_tempFileName];
    if (jsonData != null) {
      try {
        json.decode(jsonData);
        // ignore: use_build_context_synchronously
        context.read<CVDataProvider>().updateJsonData(jsonData);
        context.read<CVDataProvider>().setAutosaveDataLoaded();
      } catch (_) {}
    }
  }

  @override
  Future<void> saveTempData(BuildContext context) async {
    final provider = context.read<CVDataProvider>();
    // Use inputTabsJson if available (latest from InputView), otherwise fall back to jsonData
    final jsonData =
        provider.inputTabsJson.isNotEmpty
            ? provider.inputTabsJson
            : provider.jsonData;
    html.window.localStorage[_tempFileName] = jsonData;
  }

  @override
  Future<void> loadTempLatexData(BuildContext context) async {
    final latexData = html.window.localStorage[_tempLatexFileName];
    if (latexData != null && latexData.isNotEmpty) {
      // ignore: use_build_context_synchronously
      context.read<CVDataProvider>().updateLatexOutput(latexData);
    }
  }

  @override
  Future<void> saveTempLatexData(BuildContext context) async {
    final latexData = context.read<CVDataProvider>().latexOutput;
    html.window.localStorage[_tempLatexFileName] = latexData;
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerWeb();
