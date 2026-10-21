import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_pref_cloud_sync_service.dart';

/// Un acceso directo que el usuario puede poner en Inicio.
class Atajo {
  final String id;
  final String titulo;

  /// Nombre corto para el widget y los accesos del ícono de Android.
  final String tituloCorto;
  final IconData icono;
  final String grupo;

  const Atajo(this.id, this.titulo, this.tituloCorto, this.icono, this.grupo);

  /// Dibujo de papel (tema «Papel recortado»). En Android el mismo dibujo
  /// está en `drawable-nodpi/atajo_<id>.webp`.
  String get dibujo => 'assets/vec/objetos/atajo_$id.webp';
}

/// Atajos elegidos por el usuario para Inicio. Los primeros
/// [maximoTelefono] también salen en el widget y en los accesos del ícono de
/// Android. Se guardan en SharedPreferences y se sincronizan con la nube vía
/// [UserPrefCloudSyncService].
class AtajosService {
  AtajosService._();
  static final AtajosService I = AtajosService._();

  static const String clave = 'home_shortcuts_v1';
  static const int maximo = 9;
  static const int maximoTelefono = 4;

  /// Biblia, Estudio bíblico y Apuntes: lo que más se usa de la app.
  static const List<String> predeterminados = ['biblia', 'estudio', 'apuntes'];

  static const String _biblia = 'Biblia y estudio';
  static const String _vida = 'Vida espiritual';
  static const String _escuela = 'Escuela del Reino y juegos';
  static const String _comunidad = 'Comunidad y ayuda';

  /// Grupos en el orden en que aparecen en el editor.
  static const List<String> grupos = [_biblia, _vida, _escuela, _comunidad];

  static const List<Atajo> catalogo = [
    Atajo('biblia', 'Biblia', 'Biblia', Icons.menu_book, _biblia),
    Atajo(
      'estudio',
      'Estudio bíblico',
      'Estudio',
      Icons.manage_search_rounded,
      _biblia,
    ),
    Atajo('apuntes', 'Apuntes', 'Apuntes', Icons.edit_note_rounded, _biblia),
    Atajo(
      'guardados',
      'Versículos guardados',
      'Guardados',
      Icons.bookmark_rounded,
      _biblia,
    ),
    Atajo('mapas', 'Mapas bíblicos', 'Mapas', Icons.public_rounded, _biblia),
    Atajo(
      'mapa_oracion',
      'Mapa de oración',
      'Mapa oración',
      Icons.map_outlined,
      _vida,
    ),
    Atajo(
      'versiculos',
      'Versículos',
      'Versículos',
      Icons.format_quote_rounded,
      _vida,
    ),
    Atajo(
      'frasco',
      'Frasco de versículos',
      'Frasco',
      Icons.auto_awesome_rounded,
      _vida,
    ),
    Atajo(
      'devocional',
      'Devocional',
      'Devocional',
      Icons.auto_stories_rounded,
      _vida,
    ),
    Atajo(
      'oraciones',
      'Oraciones',
      'Oraciones',
      Icons.volunteer_activism_rounded,
      _vida,
    ),
    Atajo('progreso', 'Mi progreso', 'Progreso', Icons.show_chart, _vida),
    Atajo('favoritos', 'Mis favoritos', 'Favoritos', Icons.star_rounded, _vida),
    Atajo(
      'escuela',
      'Escuela del Reino',
      'Escuela',
      Icons.school_rounded,
      _escuela,
    ),
    Atajo(
      'juegos',
      'Juegos',
      'Juegos',
      Icons.sports_esports_rounded,
      _escuela,
    ),
    Atajo(
      'carrera',
      'Carrera de la Fe',
      'Carrera',
      Icons.directions_run_rounded,
      _escuela,
    ),
    Atajo('duelo', 'Duelo Relámpago', 'Duelo', Icons.bolt_rounded, _escuela),
    Atajo(
      'quien_soy',
      '¿Quién soy?',
      '¿Quién soy?',
      Icons.theater_comedy_rounded,
      _escuela,
    ),
    Atajo('preguntas', 'Preguntas', 'Preguntas', Icons.quiz_rounded, _escuela),
    Atajo(
      'orden_biblia',
      'Orden de la Biblia',
      'Orden Biblia',
      Icons.format_list_numbered_rounded,
      _escuela,
    ),
    Atajo(
      'companero',
      'Compañero de batalla',
      'Compañero',
      Icons.shield,
      _comunidad,
    ),
    Atajo('muro', 'Muro de batalla', 'Muro', Icons.forum_rounded, _comunidad),
    Atajo(
      'sos',
      'Necesito ayuda',
      'Ayuda',
      Icons.emergency_outlined,
      _comunidad,
    ),
    Atajo(
      'campanas',
      'Campanas sagradas',
      'Campanas',
      Icons.notifications_active_rounded,
      _comunidad,
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
