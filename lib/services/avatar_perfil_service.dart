import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_pref_cloud_sync_service.dart';

/// Un avatar de perfil dibujado en estilo «papel recortado».
class AvatarPerfil {
  final String id;
  final String nombre;
  final bool esMujer;

  const AvatarPerfil(this.id, this.nombre, {this.esMujer = false});

  String get ruta => AvatarPerfilService.rutaDe(id);
}

/// Avatar de perfil elegido por el usuario. Se guarda en SharedPreferences y
/// se sincroniza con la nube vía [UserPrefCloudSyncService].
class AvatarPerfilService {
  AvatarPerfilService._();
  static final AvatarPerfilService I = AvatarPerfilService._();

  static const String clave = 'profile_avatar_id';

  static const List<AvatarPerfil> hombres = [
    AvatarPerfil('h01', 'Cabello corto y camisa azul'),
    AvatarPerfil('h02', 'Peinado de lado y barba de pocos días'),
    AvatarPerfil('h03', 'Cabello rizado y playera mostaza'),
    AvatarPerfil('h04', 'Barba completa y sudadera'),
    AvatarPerfil('h05', 'Abuelo con lentes y barba blanca'),
    AvatarPerfil('h06', 'Cabello rubio y lentes'),
    AvatarPerfil('h07', 'Afro y candado'),
    AvatarPerfil('h08', 'Bigote y playera azul noche'),
    AvatarPerfil('h09', 'Rizos cobrizos y overol'),
    AvatarPerfil('h10', 'Lentes redondos y sudadera verde'),
  ];

  static const List<AvatarPerfil> mujeres = [
    AvatarPerfil('m01', 'Cabello largo y cruz', esMujer: true),
    AvatarPerfil('m02', 'Cola de caballo', esMujer: true),
    AvatarPerfil('m03', 'Chongo y suéter mostaza', esMujer: true),
    AvatarPerfil('m04', 'Corte bob y lentes', esMujer: true),
    AvatarPerfil('m05', 'Cabello ondulado cobrizo', esMujer: true),
    AvatarPerfil('m06', 'Trenzas y overol', esMujer: true),
    AvatarPerfil('m07', 'Dos chongos y blusa roja', esMujer: true),
    AvatarPerfil('m08', 'Abuela con lentes', esMujer: true),
    AvatarPerfil('m09', 'Cabello rubio largo', esMujer: true),
    AvatarPerfil('m10', 'Rizos largos y sudadera', esMujer: true),
  ];

  static String rutaDe(String id) => 'assets/vec/personajes/avatar_$id.webp';

  static bool esValido(String? id) =>
      id != null && [...hombres, ...mujeres].any((a) => a.id == id);

  /// Id del avatar elegido, o `null` si el usuario no ha elegido ninguno.
  final ValueNotifier<String?> avatarId = ValueNotifier<String?>(null);

  /// Lee la elección guardada (al arrancar y tras restaurar preferencias de
  /// la nube al iniciar sesión).
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(clave);
    avatarId.value = esValido(id) ? id : null;
  }

  /// Guarda el avatar elegido; `null` vuelve a la foto/ícono por defecto.
  Future<void> elegir(String? id) async {
    if (id != null && !esValido(id)) return;
    avatarId.value = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(clave);
    } else {
      await prefs.setString(clave, id);
    }
    UserPrefCloudSyncService.I.markDirty();
  }
}
