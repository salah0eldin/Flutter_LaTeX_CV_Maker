// cv_file_handler_stub.dart
// Platform-agnostic interface for import/export/history

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'cv_file_handler.dart';

// Fallback implementation (should never be used)
class CVFileHandlerStub implements CVFileHandler {
  @override
  Future<void> saveToHistory(BuildContext context, String jsonData) async {
    throw UnimplementedError('No platform implementation for saveToHistory.');
  }

  @override
  Future<String?> importFromFile(BuildContext context) async {
    throw UnimplementedError('No platform implementation for importFromFile.');
  }

  @override
  Future<void> exportToFile(BuildContext context, String jsonData) async {
    throw UnimplementedError('No platform implementation for exportToFile.');
  }

  @override
  Future<List<String>> getHistoryKeys(BuildContext context) async {
    throw UnimplementedError('No platform implementation for getHistoryKeys.');
  }

  @override
  Future<void> removeHistoryKey(BuildContext context, String key) async {
    throw UnimplementedError(
      'No platform implementation for removeHistoryKey.',
    );
  }

  @override
  Future<String?> loadHistoryItem(BuildContext context, String key) async {
    throw UnimplementedError('No platform implementation for loadHistoryItem.');
  }

  @override
  Future<void> loadTempData(BuildContext context) async {
    throw UnimplementedError('No platform implementation for loadTempData.');
  }

  @override
  Future<void> saveTempData(BuildContext context) async {
    throw UnimplementedError('No platform implementation for saveTempData.');
  }

  @override
  Future<void> loadTempPdfData(BuildContext context) async {
    throw UnimplementedError('No platform implementation for loadTempPdfData.');
  }

  @override
  Future<void> saveTempPdfData(
    BuildContext context,
    Uint8List? pdfBytes,
    bool isTemplate,
  ) async {
    throw UnimplementedError('No platform implementation for saveTempPdfData.');
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerStub();
