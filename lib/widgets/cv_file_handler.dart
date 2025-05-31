// cv_file_handler.dart
import 'package:flutter/material.dart';

abstract class CVFileHandler {
  Future<void> saveToHistory(BuildContext context, String jsonData);
  Future<String?> importFromFile(BuildContext context);
  Future<void> exportToFile(BuildContext context, String jsonData);
  Future<List<String>> getHistoryKeys(BuildContext context);
  Future<void> removeHistoryKey(BuildContext context, String key);
  Future<String?> loadHistoryItem(BuildContext context, String key);
  Future<void> loadTempData(BuildContext context);
  Future<void> saveTempData(BuildContext context);
  Future<void> loadTempLatexData(BuildContext context);
  Future<void> saveTempLatexData(BuildContext context);
}
