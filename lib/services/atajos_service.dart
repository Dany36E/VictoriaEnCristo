import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_pref_cloud_sync_service.dart';

/// Un acceso directo que el usuario puede poner en Inicio.
class Atajo {
  final String id;
  final String titulo;
  final IconData icono;

  /// Dibujo de papel para el tema «Papel recortado».
  final String dibujo;

  const Atajo(this.id, this.titulo, this.icono, this.dibujo);
}

/// Atajos elegidos por el usuario para Inicio. Se guardan en
/// SharedPreferences y se sincronizan con la nube vía
/// [UserPrefCloudSyncService].
class AtajosService {
  AtajosService._();
  static final AtajosService I = AtajosService._();

  static const String clave = 'home_shortcuts_v1';
  static const int maximo = 6;

  /// Biblia, Estudio bíblico y Apuntes: lo que más se usa de la app.
  static const List<String> predeterminados = ['biblia', 'estudio', 'apuntes'];

  static const List<Atajo> catalogo = [
    Atajo(
      'biblia',
      'Biblia',
      Icons.menu_book_rounded,
      'assets/vec/objetos/atajo_biblia.webp',
    ),
    Atajo(
      'estudio',
      'Estudio bíblico',
      Icons.manage_search_rounded,
      'assets/vec/objetos/atajo_estudio.webp',
    ),
    Atajo(
      'apuntes',
      'Apuntes',
      Icons.edit_note_rounded,
      'assets/vec/objetos/atajo_apuntes.webp',
    ),
    Atajo(
      'escuela',
      'Escuela del Reino',
      Icons.school_rounded,
      'assets/vec/objetos/star.png',
    ),
    Atajo(
      'diario',
      'Diario',
      Icons.book_rounded,
      'assets/vec/objetos/letter_small.png',
    ),
    Atajo(
      'devocional',
      'Devocional',
      Icons.wb_sunny_outlined,
      'assets/vec/objetos/flame.png',
    ),
    Atajo(
      'oracion',
      'Oraciones',
      Icons.volunteer_activism_rounded,
      'assets/vec/objetos/heart_clean.png',
    ),
    Atajo(
      'versiculos',
      'Versículos',
      Icons.format_quote_rounded,
      'assets/vec/objetos/bubble.png',
    ),
    Atajo(
      'progreso',
      'Mi progreso',
      Icons.calendar_month_rounded,
      'assets/vec/objetos/calendar.png',
    ),
    Atajo(
      'muro',
      'Muro',
      Icons.mail_outline_rounded,
      'assets/vec/objetos/envelope.png',
    ),
  ];

  static Atajo? porId(String id) {
    for (final a in catalogo) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Ids elegidos, en el orden en que se muestran.
  final ValueNotifier<List<String>> elegidos = ValueNotifier<List<String>>(
    predeterminados,
  );

  /// Quita ids desconocidos o repetidos y respeta el máximo.
  static List<String> limpiar(Iterable<String> ids) {
    final vistos = <String>{};
    return ids
        .where((id) => porId(id) != null && vistos.add(id))
        .take(maximo)
        .toList(growable: false);
  }

  /// Lee la elección guardada (al arrancar y tras restaurar preferencias de
  /// la nube al iniciar sesión). Sin elección guardada se usan los
  /// predeterminados.
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(clave);
    elegidos.value = ids == null ? predeterminados : limpiar(ids);
  }

  Future<void> guardar(List<String> ids) async {
    final limpios = limpiar(ids);
    elegidos.value = limpios;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(clave, limpios);
    UserPrefCloudSyncService.I.markDirty();
  }
}
