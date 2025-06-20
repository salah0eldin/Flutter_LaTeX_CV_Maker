// cv_file_handler.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';

abstract class CVFileHandler {
  Future<void> saveToHistory(BuildContext context, String jsonData);
  Future<String?> importFromFile(BuildContext context);
  Future<void> exportToFile(BuildContext context, String jsonData);
  Future<List<String>> getHistoryKeys(BuildContext context);
  Future<void> removeHistoryKey(BuildContext context, String key);
  Future<String?> loadHistoryItem(BuildContext context, String key);
  Future<void> loadTempData(BuildContext context);
  Future<void> saveTempData(BuildContext context);
  Future<void> loadTempPdfData(BuildContext context);
  Future<void> saveTempPdfData(
    BuildContext context,
    Uint8List? pdfBytes,
    bool isTemplate,
  );
}
