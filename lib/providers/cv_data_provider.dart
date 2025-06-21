// =====================================
// Imports and Dependencies
// =====================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// =====================================
// EditMode Enum
// =====================================
enum EditMode { none, json, input }

// =====================================
// CVDataProvider Class
// =====================================
class CVDataProvider extends ChangeNotifier {
  // =====================================
  // State Variables
  // =====================================
  String _jsonData = '{}';
  dynamic _parsedJsonData = {};
  EditMode _editMode = EditMode.none;
  ThemeMode _themeMode = ThemeMode.system;
  bool _jsonDirtyFromInput = false;
  bool _inputDirtyFromJson = false;
  String _inputTabsJson = '{}';
  List<Map<String, dynamic>>? _inputTabsDraft;
  bool _autosaveDataLoaded = false; // Track when autosave data is loaded
  bool _jsonImported = false; // Track when JSON data has been imported

  // Track which view was most recently edited
  DateTime _jsonDataLastModified = DateTime.now();
  DateTime _inputTabsJsonLastModified = DateTime.now();

  // PDF temp state
  Uint8List? _tempPdfBytes;
  bool _tempPdfIsTemplate = false;

  // =====================================
  // Getters
  // =====================================
  String get jsonData => _jsonData;
  dynamic get parsedJsonData => _parsedJsonData;
  EditMode get editMode => _editMode;
  ThemeMode get themeMode => _themeMode;
  bool get jsonDirtyFromInput => _jsonDirtyFromInput;
  bool get inputDirtyFromJson => _inputDirtyFromJson;
  String get inputTabsJson => _inputTabsJson;
  List<Map<String, dynamic>>? get inputTabsDraft => _inputTabsDraft;
  bool get autosaveDataLoaded => _autosaveDataLoaded;
  bool get jsonImported => _jsonImported;

  // PDF temp getters
  Uint8List? get tempPdfBytes => _tempPdfBytes;
  bool get tempPdfIsTemplate => _tempPdfIsTemplate;

  // Get the most recently edited data (either jsonData or inputTabsJson)
  String get mostRecentEditData {
    if (_inputTabsJsonLastModified.isAfter(_jsonDataLastModified)) {
      return _inputTabsJson;
    } else {
      return _jsonData;
    }
  }

  // =====================================
  // Setters
  // =====================================
  set inputTabsJson(String value) {
    _inputTabsJson = value;
    _inputTabsJsonLastModified = DateTime.now();
    notifyListeners();
    _triggerAutoSave(); // Auto-save when input tabs JSON changes
  }

  set inputTabsDraft(List<Map<String, dynamic>>? value) {
    _inputTabsDraft = value;
    notifyListeners();
    _triggerAutoSave(); // Auto-save when input tabs draft changes
  }

  // PDF temp setters
  void updateTempPdfData(Uint8List? pdfBytes, bool isTemplate) {
    _tempPdfBytes = pdfBytes;
    _tempPdfIsTemplate = isTemplate;
    notifyListeners();
    _triggerAutoSavePdf(); // Auto-save PDF data when it changes
  }

  // =====================================
  // JSON Data Update
  // =====================================
  void updateJsonData(String newData) {
    _jsonData = newData;
    _jsonDataLastModified = DateTime.now();
    try {
      _parsedJsonData = json.decode(newData);
    } catch (e) {
      _parsedJsonData = null; // Invalid JSON
    }
    notifyListeners();
    _triggerAutoSave(); // Auto-save on data change
  }

  // Update JSON data from import (external source)
  void updateJsonDataFromImport(String newData) {
    updateJsonData(newData);
    _jsonImported = true;
    // Reset edit mode since we've imported fresh data
    _editMode = EditMode.none;
    // Synchronize inputTabsJson with the imported data
    _inputTabsJson = newData;
    _inputTabsJsonLastModified = DateTime.now();
    // Clear dirty flags since both views are now synchronized
    _jsonDirtyFromInput = false;
    _inputDirtyFromJson = false;
    // Clear any existing draft data to start fresh
    _inputTabsDraft = null;
    notifyListeners();
    // Note: updateJsonData already calls _triggerAutoSave()
  }

  // =====================================
  // Parsed JSON Data Update
  // =====================================
  void updateParsedJsonData(dynamic newParsedData) {
    _parsedJsonData = newParsedData;
    _jsonDataLastModified = DateTime.now();
    try {
      _jsonData = json.encode(newParsedData);
    } catch (e) {
      _jsonData = '';
    }
    notifyListeners();
    _triggerAutoSave(); // Auto-save on data change
  }

  // =====================================
  // Edit Mode
  // =====================================
  void setEditMode(EditMode mode) {
    _editMode = mode;
    notifyListeners();
  }

  void cancelEdit() {
    _editMode = EditMode.none;
    notifyListeners();
  }

  // =====================================
  // Theme Mode
  // =====================================
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void setJsonDirtyFromInput() {
    _jsonDirtyFromInput = true;
    notifyListeners();
  }

  void clearJsonDirtyFromInput() {
    _jsonDirtyFromInput = false;
    notifyListeners();
  }

  void setInputDirtyFromJson() {
    _inputDirtyFromJson = true;
    notifyListeners();
  }

  void clearInputDirtyFromJson() {
    _inputDirtyFromJson = false;
    notifyListeners();
  }

  void setAutosaveDataLoaded() {
    _autosaveDataLoaded = true;
    notifyListeners();
  }

  void clearJsonImported() {
    _jsonImported = false;
    notifyListeners();
  }

  // =====================================
  // Auto-save functionality
  // =====================================
  VoidCallback? _autoSaveCallback;
  VoidCallback? _autoSavePdfCallback;

  void setAutoSaveCallback(VoidCallback? callback) {
    _autoSaveCallback = callback;
  }

  void setAutoSavePdfCallback(VoidCallback? callback) {
    _autoSavePdfCallback = callback;
  }

  void _triggerAutoSave() {
    if (_autoSaveCallback != null && !kIsWeb) {
      // Don't auto-save on web to avoid potential issues
      _autoSaveCallback!();
    }
  }

  void _triggerAutoSavePdf() {
    if (_autoSavePdfCallback != null && !kIsWeb) {
      // Don't auto-save PDF on web to avoid potential issues
      _autoSavePdfCallback!();
    }
  }
}
