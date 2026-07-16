import 'package:flutter/foundation.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/enduring_word_service.dart';

// Study mode item types for verse/annotation interleaving
enum StudyItemType { banner, verse, annotation, attribution }

class StudyItem {
  final StudyItemType type;
  final int index;
  const StudyItem(this.type, [this.index = -1]);
}

/// Estado compartido entre todos los mixins del BibleReaderController.
/// Extiende ChangeNotifier para que los mixins puedan llamar notifyListeners().
abstract class ReaderState extends ChangeNotifier {
  // ── Identity ──
  int get bookNumber;
  String get bookName;
  BibleVersion get currentVersion;
  int get currentChapter;

  // ── Verses ──
  List<BibleVerse> verses = [];
  bool loading = true;
  int totalChapters = 1;
  List<BibleBook> allBooks = [];

  // ── UI ──
  double headerOpacity = 1.0;
  bool showTypography = false;

  // ── Selección de versículos (modelo unificado) ──
  // Cada tap agrega/quita el versículo del set; no hay distinción entre
  // selección simple y múltiple. Set vacío = nada seleccionado.
  final Set<int> selectedVerseNumbers = {};
  bool get hasSelection => selectedVerseNumbers.isNotEmpty;

  // ── Selección palabra por palabra ──
  // Cuando != null, ese versículo entra en "modo palabra": su texto se vuelve
  // tappable token por token y [selectedWords] guarda los índices tocados.
  // Reutiliza el sistema de StudyWordHighlight (subrayado granular) para que
  // sea el mismo subrayado que en Modo Estudio / Apuntes.
  int? wordSelectionVerse;
  final Set<int> selectedWords = {};
  bool get inWordSelection => wordSelectionVerse != null;

  /// Hay algo activo que muestra una barra inferior de acciones.
  bool get isSelecting => hasSelection || inWordSelection;

  // ── Search ──
  bool showSearch = false;
  String searchQuery = '';
  List<int> searchMatchIndices = [];
  int currentMatchIndex = -1;

  // ── Audio ──
  bool ttsActive = false;
  bool realAudioActive = false;
  bool get isAnyAudioActive => ttsActive || realAudioActive;

  // ── Red letters ──
  bool redLettersEnabled = true;

  // ── Chapter intro ──
  String? chapterIntro;

  // ── Biblical connections ──
  Set<int> harmonyVerses = {};
  Set<int> quoteVerses = {};

  // ── Study mode (Guzik) ──
  bool _studyModeEnabled = false;
  bool get studyModeEnabled => _studyModeEnabled;
  void setStudyModeEnabled(bool v) => _studyModeEnabled = v;
  EWChapterCommentary? guzikChapter;
  List<StudyItem> studyItems = [];
  final Set<int> collapsedSections = {};

  // ── Methods that mixins may call across boundaries ──
  Future<void> loadGuzikCommentary();
  void buildStudyItems();
}
