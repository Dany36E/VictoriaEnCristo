import 'dart:async';

import 'package:flutter/material.dart';

/// Widget que captura errores de build en sus hijos y muestra un fallback.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails error, VoidCallback retry)? onError;

  /// Tiempo tras el cual el fallback se auto-dismissa intentando rehacer build.
  /// Si el error vuelve, el boundary lo volverá a mostrar.
  final Duration autoDismissAfter;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.autoDismissAfter = const Duration(seconds: 10),
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    _autoDismissTimer?.cancel();
    setState(() => _error = null);
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.autoDismissAfter, () {
      if (!mounted) return;
      setState(() => _error = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!, _retry);
      }
      return _DefaultErrorWidget(onRetry: _retry);
    }

    ErrorWidget.builder = (details) {
      debugPrint('⚠️ [ErrorBoundary] ${details.exception}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Solo activar el fallback si ESTA ruta es la visible actualmente.
        // Evita que un error en una pantalla pusheada encima (p.ej.
        // DevotionalScreen) deje al Home en estado de error tras pop().
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        setState(() => _error = details);
        _scheduleAutoDismiss();
      });
      return const SizedBox.shrink();
    };

    return widget.child;
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _DefaultErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.white.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Algo salió mal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hubo un error al mostrar esta sección.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
