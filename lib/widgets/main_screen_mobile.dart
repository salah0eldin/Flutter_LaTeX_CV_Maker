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
  // Unified folder structure in Documents (same as desktop)
  static const String _cvMakerFolderName = 'cv_maker';
  static const String _tempFolderName = 'temp';
  static const String _historyFolderName = 'history';
  static const String _tempFileName = 'cv_temp_autosave.json';
  static const String _tempPdfFileName = 'cv_temp_autosave.pdf';
  static const String _tempPdfMetaFileName = 'cv_temp_autosave_pdf.meta';

  // Helper method to get the cv_maker directory in Documents
  Future<Directory> _getCVMakerDirectory() async {
    Directory documentsDir;

    if (Platform.isAndroid) {
      // For Android, use external storage app-specific directory
      // This doesn't require MANAGE_EXTERNAL_STORAGE permission
      // Path: /storage/emulated/0/Android/data/com.example.app/files/Documents
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          documentsDir = Directory('${externalDir.path}/Documents');
          if (!await documentsDir.exists()) {
            await documentsDir.create(recursive: true);
          }
        } else {
          // Fallback to app documents if external storage is not available
          documentsDir = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        // Fallback to app documents if external storage fails
        documentsDir = await getApplicationDocumentsDirectory();
      }
    } else {
      // For iOS, use app documents directory (sandboxed)
      documentsDir = await getApplicationDocumentsDirectory();
    }

    final cvMakerDir = Directory('${documentsDir.path}/$_cvMakerFolderName');
    if (!await cvMakerDir.exists()) {
      await cvMakerDir.create(recursive: true);
    }

    // Debug: Print the actual path being used
    debugPrint('DEBUG: CV Maker directory: ${cvMakerDir.path}');

    return cvMakerDir;
  }

  // Helper method to get temp directory
  Future<Directory> _getTempDirectory() async {
    final cvMakerDir = await _getCVMakerDirectory();
    final tempDir = Directory('${cvMakerDir.path}/$_tempFolderName');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  // Helper method to get history directory
  Future<Directory> _getHistoryDirectory() async {
    final cvMakerDir = await _getCVMakerDirectory();
    final historyDir = Directory('${cvMakerDir.path}/$_historyFolderName');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir;
  }

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
    debugPrint('DEBUG: Mobile handler saveToHistory called');
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

    debugPrint('DEBUG: Dialog returned name: $name');

    if (name != null && name.isNotEmpty) {
      try {
        final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final historyDir = await _getHistoryDirectory();
        final file = File('${historyDir.path}/cv_history_$sanitized.json');
        await file.writeAsString(jsonData);

        debugPrint('DEBUG: Successfully saved to history: $sanitized');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$sanitized" to history'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('DEBUG: Error saving to history: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      debugPrint('DEBUG: Save cancelled or empty name');
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
      final historyDir = await _getHistoryDirectory();

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
      final historyDir = await _getHistoryDirectory();
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
      final historyDir = await _getHistoryDirectory();
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
    try {
      final tempDir = await _getTempDirectory();
      final file = File('${tempDir.path}/$_tempFileName');

      // Get current data from provider
      final provider = context.read<CVDataProvider>();
      final jsonData =
          provider.inputTabsJson.isNotEmpty
              ? provider.inputTabsJson
              : provider.jsonData;

      await file.writeAsString(jsonData);
      debugPrint('DEBUG: Saved temp data to: ${file.path}');
      debugPrint('DEBUG: Data length: ${jsonData.length}');

      // Verify the file was actually written
      if (await file.exists()) {
        final savedData = await file.readAsString();
        debugPrint('DEBUG: Verified saved data length: ${savedData.length}');
      } else {
        debugPrint('DEBUG: ERROR - File does not exist after saving!');
      }
    } catch (e) {
      debugPrint('DEBUG: Error saving temp data: $e');
    }
  }

  @override
  Future<void> loadTempData(BuildContext context) async {
    try {
      // Debug storage paths for troubleshooting
      await debugStoragePaths();

      final tempDir = await _getTempDirectory();
      final file = File('${tempDir.path}/$_tempFileName');

      debugPrint('DEBUG: Looking for temp file at: ${file.path}');
      debugPrint('DEBUG: Temp file exists: ${await file.exists()}');

      if (await file.exists()) {
        final jsonData = await file.readAsString();
        debugPrint('DEBUG: Loaded temp data length: ${jsonData.length}');

        final provider = context.read<CVDataProvider>();
        provider.updateJsonData(jsonData);
        provider.setAutosaveDataLoaded();
        debugPrint('DEBUG: Successfully loaded temp data from mobile storage');
      } else {
        debugPrint('DEBUG: No temp file found at: ${file.path}');
      }
    } catch (e) {
      debugPrint('DEBUG: Error loading temp data: $e');
    }
  }

  @override
  Future<void> loadTempPdfData(BuildContext context) async {
    // For mobile, we'll use the same unified temp directory
    try {
      final tempDir = await _getTempDirectory();
      final tempPdfFile = File('${tempDir.path}/$_tempPdfFileName');
      final tempMetaFile = File('${tempDir.path}/$_tempPdfMetaFileName');

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
      final tempDir = await _getTempDirectory();
      final tempPdfFile = File('${tempDir.path}/$_tempPdfFileName');
      final tempMetaFile = File('${tempDir.path}/$_tempPdfMetaFileName');

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

  // Debug method to print all storage paths (for troubleshooting)
  Future<void> debugStoragePaths() async {
    try {
      debugPrint('=== MOBILE STORAGE DEBUG ===');

      // App documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      debugPrint('App Documents Directory: ${appDocsDir.path}');

      if (Platform.isAndroid) {
        // External storage directory
        final externalDir = await getExternalStorageDirectory();
        debugPrint(
          'External Storage Directory: ${externalDir?.path ?? "null"}',
        );

        // Our CV maker directory
        final cvMakerDir = await _getCVMakerDirectory();
        debugPrint('CV Maker Directory: ${cvMakerDir.path}');

        final tempDir = await _getTempDirectory();
        debugPrint('Temp Directory: ${tempDir.path}');

        final historyDir = await _getHistoryDirectory();
        debugPrint('History Directory: ${historyDir.path}');

        // Check if temp file exists
        final tempFile = File('${tempDir.path}/$_tempFileName');
        debugPrint('Temp file path: ${tempFile.path}');
        debugPrint('Temp file exists: ${await tempFile.exists()}');

        if (await tempFile.exists()) {
          final stat = await tempFile.stat();
          debugPrint('Temp file size: ${stat.size} bytes');
          debugPrint('Temp file modified: ${stat.modified}');
        }
      }

      debugPrint('=== END STORAGE DEBUG ===');
    } catch (e) {
      debugPrint('ERROR in storage debug: $e');
    }
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerMobile();
