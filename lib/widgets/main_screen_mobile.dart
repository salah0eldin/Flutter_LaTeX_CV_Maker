// Mobile-specific file handler for Android and iOS
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/cv_data_provider.dart';
import 'cv_file_handler.dart';

class CVFileHandlerMobile implements CVFileHandler {
  static const String _historyFolderName = 'cv_history';

  // Helper method to request storage permission
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission for app documents
  }

  @override
  Future<void> saveToHistory(BuildContext context, String jsonData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/$_historyFolderName');

      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${historyDir.path}/cv_$timestamp.json');
      await file.writeAsString(jsonData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CV saved to history!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save to history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Future<String?> importFromFile(BuildContext context) async {
    try {
      // Use file picker to let user choose a JSON file to import
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Import CV Data',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonData = await file.readAsString();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CV data imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        return jsonData;
      } else {
        // User cancelled the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import cancelled by user'),
            backgroundColor: Colors.grey,
          ),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import CV: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  @override
  Future<void> exportToFile(BuildContext context, String jsonData) async {
    try {
      // Request storage permission
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to save files'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Use file picker to let user choose location and name
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export CV Data',
        fileName: 'cv_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CV exported to: $result'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // User cancelled the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export cancelled by user'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Future<List<String>> getHistoryKeys(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/$_historyFolderName');

      if (!await historyDir.exists()) {
        return [];
      }

      final files =
          await historyDir
              .list()
              .where(
                (entity) => entity is File && entity.path.endsWith('.json'),
              )
              .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aFile = a as File;
        final bFile = b as File;
        return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
      });

      return files
          .map((file) => file.path.split('/').last.split('.').first)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> removeHistoryKey(BuildContext context, String key) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/$_historyFolderName');
      final file = File('${historyDir.path}/$key.json');

      if (await file.exists()) {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History item deleted!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete history item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Future<String?> loadHistoryItem(BuildContext context, String key) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${directory.path}/$_historyFolderName');
      final file = File('${historyDir.path}/$key.json');

      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history item: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  @override
  Future<void> saveTempData(BuildContext context) async {
    // For mobile, we can save temp data to a specific temp file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cv_temp.json');

      // Get current data from provider
      final provider = context.read<CVDataProvider>();
      final jsonData = provider.jsonData;

      await file.writeAsString(jsonData);
    } catch (e) {
      // Silently fail for temp data
    }
  }

  @override
  Future<void> loadTempData(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cv_temp.json');

      if (await file.exists()) {
        final jsonData = await file.readAsString();
        final provider = context.read<CVDataProvider>();
        provider.updateJsonDataFromImport(jsonData);
      }
    } catch (e) {
      // Silently fail for temp data
    }
  }

  @override
  Future<void> loadTempPdfData(BuildContext context) async {
    // For mobile, we'll use the same app temp directory
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPdfFile = File('${tempDir.path}/cv_temp_autosave.pdf');
      final tempMetaFile = File('${tempDir.path}/cv_temp_autosave_pdf.meta');

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
      final tempDir = await getTemporaryDirectory();
      final tempPdfFile = File('${tempDir.path}/cv_temp_autosave.pdf');
      final tempMetaFile = File('${tempDir.path}/cv_temp_autosave_pdf.meta');

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

CVFileHandler getCVFileHandler() => CVFileHandlerMobile();
