import 'package:flutter/foundation.dart';

enum EditMode { none, json, input }

class CVDataProvider extends ChangeNotifier {
  String _jsonData = '{}';
  String _latexOutput = '';
  EditMode _editMode = EditMode.none;

  String get jsonData => _jsonData;
  String get latexOutput => _latexOutput;
  EditMode get editMode => _editMode;

  void updateJsonData(String newData) {
    _jsonData = newData;
    notifyListeners();
  }

  void updateLatexOutput(String newLatex) {
    _latexOutput = newLatex;
    notifyListeners();
  }

  void setEditMode(EditMode mode) {
    _editMode = mode;
    notifyListeners();
  }

  void cancelEdit() {
    _editMode = EditMode.none;
    notifyListeners();
  }
}
