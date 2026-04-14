/// ═══════════════════════════════════════════════════════════════════════════
/// OFFLINE BANNER - Indicador sutil de modo sin conexión
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Banner sutil que se muestra cuando el dispositivo está sin conexión.
/// Usar envuelto en un Column o Stack en las pantallas principales.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.I.isOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: Colors.orange.shade900.withValues(alpha: 0.9),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Sin conexión — los cambios se sincronizarán al reconectar',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
