import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dataWithTimestamp = json.encode({
        'data': jsonData,
        'timestamp': timestamp,
        'name': sanitized,
      });
      html.window.localStorage[key] = dataWithTimestamp;
      // Update latest history reference
      html.window.localStorage['cv_latest_history'] = key;
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
    final keys =
        html.window.localStorage.keys
            .where((k) => k.startsWith('cv_history_'))
            .toList();

    // Sort by timestamp (newest first) if available
    keys.sort((a, b) {
      try {
        final aData = html.window.localStorage[a];
        final bData = html.window.localStorage[b];

        if (aData != null && bData != null) {
          final aParsed = json.decode(aData);
          final bParsed = json.decode(bData);

          if (aParsed is Map &&
              bParsed is Map &&
              aParsed['timestamp'] != null &&
              bParsed['timestamp'] != null) {
            final aTime = aParsed['timestamp'] as int;
            final bTime = bParsed['timestamp'] as int;
            // Ensure newest comes first by comparing bTime to aTime
            final result = bTime.compareTo(aTime);
            return result; // Newest first (larger timestamp first)
          }
        }
      } catch (_) {
        // Fallback to reverse alphabetical sort for old format (newer names tend to be later)
        return b.compareTo(a);
      }
      // Default: reverse alphabetical to get newer entries first
      return b.compareTo(a);
    });

    return keys;
  }

  @override
  Future<void> removeHistoryKey(BuildContext context, String key) async {
    html.window.localStorage.remove(key);
  }

  @override
  Future<String?> loadHistoryItem(BuildContext context, String key) async {
    final rawData = html.window.localStorage[key];
    if (rawData == null) return null;

    try {
      // Try to parse as new format with timestamp
      final parsed = json.decode(rawData);
      if (parsed is Map && parsed['data'] != null) {
        return parsed['data'] as String;
      }
    } catch (_) {
      // If parsing fails, assume it's old format (just the JSON data)
    }

    // Return as-is for old format
    return rawData;
  }

  // Helper method to get the latest history data
  Future<String?> _getLatestHistoryData() async {
    // First check for explicitly marked latest
    final latestKey = html.window.localStorage['cv_latest_history'];
    if (latestKey != null) {
      final rawData = html.window.localStorage[latestKey];
      if (rawData != null) {
        try {
          // Try to parse as new format with timestamp
          final parsed = json.decode(rawData);
          if (parsed is Map && parsed['data'] != null) {
            return parsed['data'] as String;
          }
        } catch (_) {
          // If parsing fails, assume it's old format (just the JSON data)
        }
        // Return as-is for old format
        return rawData;
      }
    }

    // Fallback: find the most recent by checking all history items
    final allKeys =
        html.window.localStorage.keys
            .where((k) => k.startsWith('cv_history_'))
            .toList();

    if (allKeys.isEmpty) return null;

    String? mostRecentKey;
    int mostRecentTimestamp = 0;

    for (final key in allKeys) {
      final rawData = html.window.localStorage[key];
      if (rawData != null) {
        try {
          final parsed = json.decode(rawData);
          if (parsed is Map && parsed['timestamp'] != null) {
            final timestamp = parsed['timestamp'] as int;
            if (timestamp > mostRecentTimestamp) {
              mostRecentTimestamp = timestamp;
              mostRecentKey = key;
            }
          }
        } catch (_) {
          // Old format without timestamp, skip
        }
      }
    }

    if (mostRecentKey != null) {
      final rawData = html.window.localStorage[mostRecentKey];
      if (rawData != null) {
        try {
          final parsed = json.decode(rawData);
          if (parsed is Map && parsed['data'] != null) {
            return parsed['data'] as String;
          }
        } catch (_) {
          // Old format
        }
        return rawData;
      }
    }

    return null;
  }

  // Temp data: use localStorage for web
  static const String _tempFileName = 'cv_temp_autosave.json';

  @override
  Future<void> loadTempData(BuildContext context) async {
    // First try to load temp autosave data
    final tempData = html.window.localStorage[_tempFileName];
    if (tempData != null) {
      try {
        json.decode(tempData);
        // ignore: use_build_context_synchronously
        context.read<CVDataProvider>().updateJsonData(tempData);
        context.read<CVDataProvider>().setAutosaveDataLoaded();
        return; // Found temp data, don't load from history
      } catch (_) {
        // Invalid temp data, continue to try history
      }
    }

    // No valid temp data found, try to load the latest history item
    final latestHistoryData = await _getLatestHistoryData();
    if (latestHistoryData != null) {
      try {
        json.decode(latestHistoryData);
        // ignore: use_build_context_synchronously
        context.read<CVDataProvider>().updateJsonDataFromImport(
          latestHistoryData,
        );
        context.read<CVDataProvider>().setAutosaveDataLoaded();

        // Show a message that we loaded from history
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loaded latest CV from history'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (_) {
        // Invalid history data
      }
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
  Future<void> loadTempPdfData(BuildContext context) async {
    try {
      final pdfDataB64 = html.window.localStorage['cv_temp_pdf_data'];
      final pdfMeta = html.window.localStorage['cv_temp_pdf_meta'];

      if (pdfDataB64 != null && pdfDataB64.isNotEmpty && pdfMeta != null) {
        final pdfBytes = base64Decode(pdfDataB64);
        final isTemplate = pdfMeta.trim() == 'template';

        if (pdfBytes.isNotEmpty) {
          context.read<CVDataProvider>().updateTempPdfData(
            pdfBytes,
            isTemplate,
          );
          debugPrint(
            'DEBUG: Loaded temp PDF data from localStorage (isTemplate: $isTemplate)',
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
      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        final pdfDataB64 = base64Encode(pdfBytes);
        html.window.localStorage['cv_temp_pdf_data'] = pdfDataB64;
        html.window.localStorage['cv_temp_pdf_meta'] =
            isTemplate ? 'template' : 'generated';
        debugPrint(
          'DEBUG: Saved temp PDF data to localStorage (isTemplate: $isTemplate)',
        );
      } else {
        // Remove temp data if no PDF
        html.window.localStorage.remove('cv_temp_pdf_data');
        html.window.localStorage.remove('cv_temp_pdf_meta');
        debugPrint(
          'DEBUG: Removed temp PDF data from localStorage (no data to save)',
        );
      }
    } catch (e) {
      debugPrint('DEBUG: Error saving temp PDF data: $e');
    }
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerWeb();
