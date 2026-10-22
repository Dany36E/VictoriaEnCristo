import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/services/bible/bible_user_data_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/vec/vec_widgets.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_checks.dart';

/// Prepara Firebase simulado, preferencias vacías y las fuentes reales, para
/// que las capturas se vean como en el teléfono (no con cuadros de prueba).
void setUpThemeMatrix() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Firebase.initializeApp();
    // Auth escucha cambios de sesión por canales nativos; sin plugin se
    // simulan para que se comporte como un usuario sin sesión.
    final mensajero =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const api =
        'dev.flutter.pigeon.firebase_auth_platform_interface'
        '.FirebaseAuthHostApi';
    const eventos = 'pruebas/firebase_auth/eventos';
    for (final metodo in [
      'registerIdTokenListener',
      'registerAuthStateListener',
    ]) {
      mensajero.setMockMessageHandler(
        '$api.$metodo',
        (_) async => const StandardMessageCodec().encodeMessage([eventos]),
      );
    }
    mensajero.setMockMethodCallHandler(
      const MethodChannel(eventos),
      (_) async => null,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    mensajero.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // Familia de pubspec.yaml que usan las plantillas clásicas para compartir
    // (google_fonts la registra aparte como «Crimson Pro»).
    await (FontLoader('CrimsonPro')..addFont(
          rootBundle.load('google_fonts/CrimsonPro-VariableFont_wght.ttf'),
        ))
        .load();
    // Letras del kit del tema «Papel recortado».
    for (final (familia, archivo) in [
      ('LilitaOne', 'LilitaOne-Regular.ttf'),
      ('PatrickHand', 'PatrickHand-Regular.ttf'),
      ('CaveatBrush', 'CaveatBrush-Regular.ttf'),
    ]) {
      await (FontLoader(
        familia,
      )..addFont(rootBundle.load('assets/vec/fuentes/$archivo'))).load();
    }
    // Solo los pesos que existen en google_fonts/: pedir otro hace que
    // google_fonts intente descargarlo y la prueba falle.
    const medios = [FontWeight.w400, FontWeight.w500, FontWeight.w600];
    for (final (familia, archivo, pesos) in [
      ('Manrope', 'Manrope', FontWeight.values),
      ('Cinzel', 'Cinzel', FontWeight.values),
      ('Lora', 'Lora', [...medios, FontWeight.w700]),
      ('Crimson Pro', 'CrimsonPro', [...medios, FontWeight.w700]),
    ]) {
      final fuente = 'google_fonts/$archivo-VariableFont_wght.ttf';
      await (FontLoader(familia)..addFont(rootBundle.load(fuente))).load();
      for (final peso in pesos) {
        // La cursiva no está en google_fonts/: se dibuja inclinando la normal.
        for (final estilo in FontStyle.values) {
          final nombre = GoogleFonts.getFont(
            familia,
            fontWeight: peso,
            fontStyle: estilo,
          ).fontFamily!;
          await (FontLoader(nombre)..addFont(rootBundle.load(fuente))).load();
        }
      }
    }
  });
}

/// Dibuja [pantalla] en cada tema de [AppThemeData.all] (claros y oscuros) a
/// 360×800, guarda la captura en `build/qa/<nombre>_<tema>.png` y revisa
/// desbordes y errores, fondos de botones que no cubren su texto y contraste
/// WCAG del texto contra lo que realmente está pintado detrás.
///
/// Los problemas que ya existían están en
/// `test/visual/problemas_conocidos/<nombre>.txt` y no hacen fallar la prueba;
/// cualquier problema nuevo sí. Al corregir uno, regenera la lista con
/// `ACTUALIZAR_PROBLEMAS_CONOCIDOS=1 flutter test test/visual/`.
///
/// [contenidoDelDia]: la pantalla muestra textos que cambian con la fecha
/// (versículo o devocional del día). En la lista de conocidos sus textos
/// con poco contraste se guardan por su orden en la pantalla, no por lo que
/// dicen, para que la prueba no falle solo porque cambió el día.
///
/// [esperarCarga]: antes de capturar, dar tiempo real para que termine lo que
/// la pantalla lee de assets o preferencias (si no, el primer tema se captura
/// a veces con el indicador de carga).
void themeMatrix(
  String nombre,
  Widget Function() pantalla, {
  bool contenidoDelDia = false,
  bool esperarCarga = true,
}) {
  final archivo = File('test/visual/problemas_conocidos/$nombre.txt');
  final conocidos = archivo.existsSync()
      ? archivo
            .readAsLinesSync()
            .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
            .toSet()
      : <String>{};
  final actualizar =
      Platform.environment['ACTUALIZAR_PROBLEMAS_CONOCIDOS'] == '1';
  final encontrados = <String>[];
  var temasRevisados = 0;

  if (actualizar) {
    tearDownAll(() {
      // Con un filtro (--plain-name) no corren todos los temas: no tocar la
      // lista, o se perderían los problemas de los temas que no se vieron.
      if (temasRevisados != AppThemeData.all.length) return;
      if (encontrados.isEmpty) {
        if (archivo.existsSync()) archivo.deleteSync();
        return;
      }
      archivo.parent.createSync(recursive: true);
      archivo.writeAsStringSync(
        '# Problemas visuales que ya existían en "$nombre". No agregues\n'
        '# líneas a mano: corrige el problema. Se regenera con\n'
        '# ACTUALIZAR_PROBLEMAS_CONOCIDOS=1 flutter test test/visual/\n'
        '${(encontrados..sort()).join('\n')}\n',
      );
    });
  }

  for (final theme in AppThemeData.all) {
    testWidgets('$nombre en tema ${theme.id}: botones y contraste', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Las pantallas de la Biblia usan su propio tema de lectura (mismos ids).
      BibleUserDataService.I.readerThemeNotifier.value = theme.id;
      // AppFonts elige las letras del kit según el tema activo del servicio.
      await tester.runAsync(() => ThemeService().setTheme(theme.id));
      final boundaryKey = GlobalKey();
      final fondo = theme.isPaper
          ? FondoPapel.decoracion
          : const BoxDecoration();
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            // Igual que main.dart: el tema papel tiene su propio ThemeData y
            // el papel con textura detrás de todas las rutas.
            theme: theme.isPaper ? AppTheme.paperTheme : AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => AppThemeData.provider(
              theme: theme,
              child: DecoratedBox(decoration: fondo, child: child!),
            ),
            // El papel también dentro de la captura: las pantallas del tema
            // papel son transparentes y sin él saldría negro.
            home: RepaintBoundary(
              key: boundaryKey,
              child: DecoratedBox(decoration: fondo, child: pantalla()),
            ),
          ),
        );
        // Sin pumpAndSettle: varias pantallas tienen animaciones infinitas.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Lo que se lee de assets o preferencias termina con E/S real, que el
        // reloj falso no avanza: sin esta espera el primer tema capturaba
        // solo el indicador de carga. pump() sin duración dibuja lo cargado
        // sin mover las animaciones, para que todos los temas se capturen en
        // el mismo momento.
        for (var i = 0; i < (esperarCarga ? 3 : 0); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }

        final limite =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        // Guardar la captura antes de las comprobaciones, aunque fallen.
        final (imagen, pixeles) = (await tester.runAsync(() async {
          final captura = await capturarPixeles(limite);
          final png = await captura.$1.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File('build/qa/${nombre}_${theme.id}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          return captura;
        }))!;

        final excepcion = tester.takeException();
        final problemas = {
          if (excepcion != null)
            'error: ${excepcion.toString().split('\n').first.trim()}',
          ...problemasDeBotones(tester),
          ...problemasDeContraste(limite, imagen, pixeles),
        }.map((p) => '${theme.id}: ${p.replaceAll('\n', ' ')}').toList();
        imagen.dispose();

        var n = 0;
        final claves = [
          for (final p in problemas)
            contenidoDelDia && p.contains('" contraste ')
                ? _clave(p).replaceFirst(RegExp(r'"[^"]*"'), '"texto #${++n}"')
                : _clave(p),
        ];
        if (actualizar) {
          encontrados.addAll(claves);
          temasRevisados++;
          return;
        }
        final nuevos = [
          for (var i = 0; i < problemas.length; i++)
            if (!conocidos.contains(claves[i])) problemas[i],
        ];
        for (final viejo in conocidos.where(
          (c) => c.startsWith('${theme.id}: ') && !claves.contains(c),
        )) {
          debugPrint('Ya corregido, quítalo de ${archivo.path}: $viejo');
        }
        expect(
          nuevos,
          isEmpty,
          reason:
              'Problemas visuales nuevos en $nombre (captura en '
              'build/qa/${nombre}_${theme.id}.png). Corrígelos; no los '
              'agregues a la lista de conocidos.',
        );
      } finally {
        // Desmontar y avanzar el reloj para que no queden timers pendientes.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      }
    });
  }
}

/// Lo que se guarda en la lista de conocidos: qué texto o botón falla y en
/// qué tema, sin medidas exactas, que cambian un poco entre versiones de
/// Flutter (el CI usa la última estable).
String _clave(String problema) => problema
    .replaceAll(RegExp(r'contraste [\d.]+ < '), 'contraste < ')
    .replaceAll(RegExp(r' \((texto|contenido) .*\)$'), '');
