import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_content.dart';

class ContentStorageService {
  static const String contentsKey = 'saved_contents';

  Future<List<SavedContent>> loadContents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(contentsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final contents = SavedContent.decodeList(raw);
      return _sortContents(contents);
    } catch (e, stackTrace) {
      developer.log(
        'Fehler beim Laden gespeicherter Inhalte',
        name: 'ContentStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> saveContents(List<SavedContent> contents) async {
    final prefs = await SharedPreferences.getInstance();
    final sortedContents = _sortContents(contents);
    await prefs.setString(contentsKey, SavedContent.encodeList(sortedContents));
  }

  Future<void> addOrUpdateContent(SavedContent content) async {
    final contents = await loadContents();
    final index = contents.indexWhere((c) => c.id == content.id);

    if (index >= 0) {
      contents[index] = content;
    } else {
      contents.add(content);
    }

    await saveContents(contents);
  }

  Future<void> deleteContent(String id) async {
    final contents = await loadContents();
    contents.removeWhere((c) => c.id == id);
    await saveContents(contents);
  }

  List<SavedContent> _sortContents(List<SavedContent> contents) {
    final sorted = List<SavedContent>.from(contents);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }
}