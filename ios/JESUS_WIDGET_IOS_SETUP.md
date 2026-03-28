# Jesus Widget - iOS Widget Extension Setup

## Pasos manuales en Xcode

### 1. Crear Widget Extension

1. Abrir `ios/Runner.xcworkspace` en Xcode
2. File → New → Target → **Widget Extension**
3. Nombre: `JesusWidget`
4. ❌ Desmarcar "Include Live Activity"
5. ❌ Desmarcar "Include Configuration App Intent"
6. Finish → Activate scheme

### 2. Configurar App Group

1. Seleccionar target **Runner** → Signing & Capabilities → + Capability → App Groups
2. Agregar: `group.com.example.appquitar`
3. Seleccionar target **JesusWidgetExtension** → Signing & Capabilities → + Capability → App Groups
4. Agregar el mismo: `group.com.example.appquitar`

### 3. Configurar Deployment Target

1. Seleccionar target **JesusWidgetExtension** → General
2. Minimum Deployments: **iOS 17.0**

### 4. Reemplazar código Swift

Reemplazar el contenido de `JesusWidget/JesusWidget.swift` con:

```swift
import WidgetKit
import SwiftUI

// MARK: - Entry

struct JesusEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let completedToday: Bool
    let message: String
}

// MARK: - Provider

struct JesusProvider: TimelineProvider {
    let appGroupId = "group.com.example.appquitar"
    
    func placeholder(in context: Context) -> JesusEntry {
        JesusEntry(date: Date(), streakDays: 7, completedToday: true, message: "¡Victoria de hoy registrada!")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (JesusEntry) -> Void) {
        completion(getEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<JesusEntry>) -> Void) {
        let entry = getEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getEntry() -> JesusEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let streak = defaults?.integer(forKey: "jesus_streak_days") ?? 0
        let completed = defaults?.bool(forKey: "jesus_completed_today") ?? false
        let message = defaults?.string(forKey: "jesus_widget_message") ?? "¡Registra tu primera victoria!"
        
        return JesusEntry(
            date: Date(),
            streakDays: streak,
            completedToday: completed,
            message: message
        )
    }
}

// MARK: - Widget View

struct JesusWidgetView: View {
    var entry: JesusEntry
    
    var streakColor: Color {
        switch entry.streakDays {
        case 0: return Color(hex: "888780")
        case 1...6: return Color(hex: "C0C0C0")
        case 7...29: return Color(hex: "4FC3F7")
        case 30...99: return Color(hex: "7C4DFF")
        case 100...364: return Color(hex: "FF6D00")
        default: return Color(hex: "D4AF37")
        }
    }
    
    var badgeText: String {
        if entry.completedToday { return "✓ Día de victoria" }
        if entry.streakDays > 0 { return "⚔ En batalla" }
        return "Empieza hoy"
    }
    
    var badgeColor: Color {
        if entry.completedToday { return .green }
        if entry.streakDays > 0 { return Color(hex: "D4AF37") }
        return .gray
    }
    
    var body: some View {
        ZStack {
            // Fondo oscuro
            Color(hex: "0A0A12")
            
            VStack(spacing: 6) {
                // Número de racha
                Text("\(entry.streakDays)")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundColor(streakColor)
                
                // Label
                Text("DÍAS DE RACHA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.5)
                
                // Mensaje
                Text(entry.message.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                
                Spacer()
                
                // Badge
                Text(badgeText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                Capsule()
                                    .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
                            )
                    )
            }
            .padding(.vertical, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Widget Definition

@main
struct JesusWidget: Widget {
    let kind: String = "JesusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JesusProvider()) { entry in
            JesusWidgetView(entry: entry)
                .containerBackground(Color(hex: "0A0A12"), for: .widget)
        }
        .configurationDisplayName("Victoria en Cristo")
        .description("Tu racha de victoria y progreso espiritual")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    JesusWidget()
} timeline: {
    JesusEntry(date: .now, streakDays: 0, completedToday: false, message: "¡Registra tu primera victoria!")
    JesusEntry(date: .now, streakDays: 7, completedToday: true, message: "¡Una semana completa! ¡Sigue adelante!")
    JesusEntry(date: .now, streakDays: 100, completedToday: false, message: "¡100 días de racha! No te detengas ahora")
}
```

### 5. Verificar

1. Build & Run en simulador iOS
2. Long-press home → buscar "Victoria en Cristo"
3. Agregar widget Medium
4. Verificar que muestra datos de SharedPreferences (grupo compartido)

### Notas

- Las claves SharedPreferences (`jesus_streak_days`, `jesus_completed_today`, `jesus_widget_message`) se sincronizan desde Flutter vía `HomeWidget.saveWidgetData()` en `WidgetSyncService`
- El App Group debe coincidir con `kIOSAppGroup` en `widget_constants.dart`: `group.com.example.appquitar`
- El `kind` ("JesusWidget") debe coincidir con `kIOSJesusWidgetName` en `widget_constants.dart`
