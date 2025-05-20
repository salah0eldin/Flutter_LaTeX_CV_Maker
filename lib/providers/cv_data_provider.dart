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
  String _latexOutput = '';
  EditMode _editMode = EditMode.none;
  ThemeMode _themeMode = ThemeMode.system;

  // =====================================
  // Getters
  // =====================================
  String get jsonData => _jsonData;
  dynamic get parsedJsonData => _parsedJsonData;
  String get latexOutput => _latexOutput;
  EditMode get editMode => _editMode;
  ThemeMode get themeMode => _themeMode;

  // =====================================
  // JSON Data Update
  // =====================================
  void updateJsonData(String newData) {
    _jsonData = newData;
    try {
      _parsedJsonData = json.decode(newData);
    } catch (e) {
      _parsedJsonData = null; // Invalid JSON
    }
    notifyListeners();
  }

  // =====================================
  // Parsed JSON Data Update
  // =====================================
  void updateParsedJsonData(dynamic newParsedData) {
    _parsedJsonData = newParsedData;
    try {
      _jsonData = json.encode(newParsedData);
    } catch (e) {
      _jsonData = '';
    }
    notifyListeners();
  }

  // =====================================
  // LaTeX Output Update
  // =====================================
  void updateLatexOutput(String newLatex) {
    _latexOutput = newLatex;
    notifyListeners();
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
}
