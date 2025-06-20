// Desktop-specific implementation for import/export/history using dart:io
// To be filled with logic moved from main_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
    try {
      // Check if we're on mobile (Android/iOS) vs desktop
      if (Platform.isAndroid || Platform.isIOS) {
        // Use share functionality for mobile
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/cv_export.json');
        await file.writeAsString(jsonData);

        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'CV Data Export',
          subject: 'CV Export',
        );

        if (result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CV exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Use file picker for desktop
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export JSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Future<List<String>> getHistoryKeys(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().whereType<File>();
    final historyFiles =
        files
            .where(
              (f) => f.path.contains('cv_history_') && f.path.endsWith('.json'),
            )
            .toList();

    // Sort by file modification time (newest first)
    historyFiles.sort((a, b) {
      try {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return bTime.compareTo(aTime); // Newest first (larger timestamp first)
      } catch (_) {
        // Fallback to reverse alphabetical sort if file times can't be read
        return b.path.compareTo(a.path);
      }
    });

    return historyFiles
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

  // Temp data: use app support directory for desktop (within app files)
  static const String _tempFileName = 'cv_temp_autosave.json';
  static const String _tempPdfFileName = 'cv_temp_autosave.pdf';
  static const String _tempPdfMetaFileName = 'cv_temp_autosave_pdf.meta';

  @override
  Future<void> loadTempData(BuildContext context) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final tempFile = File('${appDir.path}/$_tempFileName');
      if (await tempFile.exists()) {
        final jsonData = await tempFile.readAsString();
        try {
          json.decode(jsonData);
          context.read<CVDataProvider>().updateJsonData(jsonData);
          context.read<CVDataProvider>().setAutosaveDataLoaded();
          print('DEBUG: Loaded autosave data from: ${tempFile.path}');
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Future<void> saveTempData(BuildContext context) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final tempFile = File('${appDir.path}/$_tempFileName');
      final provider = context.read<CVDataProvider>();
      // Use inputTabsJson if available (latest from InputView), otherwise fall back to jsonData
      final jsonData =
          provider.inputTabsJson.isNotEmpty
              ? provider.inputTabsJson
              : provider.jsonData;
      await tempFile.writeAsString(jsonData);
      print('DEBUG: Saved autosave data to: ${tempFile.path}');
    } catch (_) {}
  }

  @override
  Future<void> loadTempPdfData(BuildContext context) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final tempPdfFile = File('${appDir.path}/$_tempPdfFileName');
      final tempMetaFile = File('${appDir.path}/$_tempPdfMetaFileName');

      if (await tempPdfFile.exists() && await tempMetaFile.exists()) {
        final pdfBytes = await tempPdfFile.readAsBytes();
        final metaData = await tempMetaFile.readAsString();
        final isTemplate = metaData.trim() == 'template';

        if (pdfBytes.isNotEmpty) {
          context.read<CVDataProvider>().updateTempPdfData(
            pdfBytes,
            isTemplate,
          );
          debugPrint(
            'DEBUG: Loaded temp PDF data from: ${tempPdfFile.path} (isTemplate: $isTemplate)',
          );
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error loading temp PDF data: $e');
    }
  }

  @override
  Future<void> saveTempPdfData(
    BuildContext context,
    Uint8List? pdfBytes,
    bool isTemplate,
  ) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final tempPdfFile = File('${appDir.path}/$_tempPdfFileName');
      final tempMetaFile = File('${appDir.path}/$_tempPdfMetaFileName');

      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        await tempPdfFile.writeAsBytes(pdfBytes);
        await tempMetaFile.writeAsString(isTemplate ? 'template' : 'generated');
        debugPrint(
          'DEBUG: Saved temp PDF data to: ${tempPdfFile.path} (isTemplate: $isTemplate)',
        );
      } else {
        // Delete temp files if no PDF data
        if (await tempPdfFile.exists()) await tempPdfFile.delete();
        if (await tempMetaFile.exists()) await tempMetaFile.delete();
        debugPrint('DEBUG: Deleted temp PDF files (no data to save)');
      }
    } catch (e) {
      debugPrint('DEBUG: Error saving temp PDF data: $e');
    }
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerDesktop();
