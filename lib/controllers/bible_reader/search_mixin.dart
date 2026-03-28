import '../../services/bible/bible_search_service.dart';
import 'reader_state.dart';

/// Búsqueda dentro del capítulo actual (in-reader search).
mixin SearchMixin on ReaderState {
  void runInReaderSearch(String query) {
    searchQuery = query;
    searchMatchIndices = [];
    currentMatchIndex = -1;

    if (query.trim().length < 2) {
      notifyListeners();
      return;
    }

    final normalizedQuery = BibleSearchService.normalize(query);
    final matches = <int>[];
    for (int i = 0; i < verses.length; i++) {
      if (BibleSearchService.normalize(verses[i].text)
          .contains(normalizedQuery)) {
        matches.add(i);
      }
    }
    searchMatchIndices = matches;
    currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  void goToMatch(int matchIdx) {
    if (matchIdx < 0 || matchIdx >= searchMatchIndices.length) return;
    currentMatchIndex = matchIdx;
    notifyListeners();
  }

  void closeSearch() {
    showSearch = false;
    searchQuery = '';
    searchMatchIndices = [];
    currentMatchIndex = -1;
    notifyListeners();
  }

  void toggleSearch() {
    showSearch = !showSearch;
    notifyListeners();
  }
}
