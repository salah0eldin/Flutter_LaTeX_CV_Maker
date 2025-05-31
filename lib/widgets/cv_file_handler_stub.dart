// cv_file_handler_stub.dart
// Platform-agnostic interface for import/export/history

import 'package:flutter/material.dart';
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
  Future<void> loadTempLatexData(BuildContext context) async {
    throw UnimplementedError(
      'No platform implementation for loadTempLatexData.',
    );
  }

  @override
  Future<void> saveTempLatexData(BuildContext context) async {
    throw UnimplementedError(
      'No platform implementation for saveTempLatexData.',
    );
  }
}

CVFileHandler getCVFileHandler() => CVFileHandlerStub();
