import WidgetKit
import SwiftUI

/// Datos del widget leídos desde UserDefaults (App Group)
struct VictoryWidgetData {
    let title: String
    let line1: String
    let line2: String
    let streakValue: Int
    let showStreak: Bool
    let showVerse: Bool
    let showCTA: Bool
    let isLightTheme: Bool
    let isDiscreetMode: Bool
    
    /// Valores por defecto (fallback neutral)
    static let placeholder = VictoryWidgetData(
        title: "Rutina diaria",
        line1: "Respira. Sigue hoy.",
        line2: "Abre la app cuando puedas.",
        streakValue: 0,
        showStreak: false,
        showVerse: false,
        showCTA: true,
        isLightTheme: true,
        isDiscreetMode: true
    )
    
    /// Lee datos desde UserDefaults (App Group)
    static func fromUserDefaults() -> VictoryWidgetData {
        let defaults = UserDefaults(suiteName: "group.com.example.appquitar")
        
        return VictoryWidgetData(
            title: defaults?.string(forKey: "widget_title") ?? placeholder.title,
            line1: defaults?.string(forKey: "widget_line1") ?? placeholder.line1,
            line2: defaults?.string(forKey: "widget_line2") ?? placeholder.line2,
            streakValue: defaults?.integer(forKey: "widget_streak") ?? 0,
            showStreak: defaults?.bool(forKey: "widget_show_streak") ?? false,
            showVerse: defaults?.bool(forKey: "widget_show_verse") ?? false,
            showCTA: defaults?.bool(forKey: "widget_show_cta") ?? true,
            isLightTheme: defaults?.bool(forKey: "widget_is_light") ?? true,
            isDiscreetMode: defaults?.bool(forKey: "widget_is_discreet") ?? true
        )
    }
}

/// Timeline Entry para el widget
struct VictoryEntry: TimelineEntry {
    let date: Date
    let data: VictoryWidgetData
}

/// Timeline Provider
struct VictoryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VictoryEntry {
        VictoryEntry(date: Date(), data: .placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (VictoryEntry) -> Void) {
        let data = VictoryWidgetData.fromUserDefaults()
        let entry = VictoryEntry(date: Date(), data: data)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<VictoryEntry>) -> Void) {
        let data = VictoryWidgetData.fromUserDefaults()
        let currentDate = Date()
        
        // Crear entrada actual
        let entry = VictoryEntry(date: currentDate, data: data)
        
        // Refrescar a medianoche (cuando cambia el día)
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

/// Vista del Widget
struct VictoryWidgetView: View {
    var entry: VictoryEntry
    
    var backgroundColor: Color {
        entry.data.isLightTheme ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.18)
    }
    
    var textColor: Color {
        entry.data.isLightTheme ? Color.black.opacity(0.87) : Color.white
    }
    
    var subtitleColor: Color {
        entry.data.isLightTheme ? Color.black.opacity(0.54) : Color.white.opacity(0.7)
    }
    
    var accentColor: Color {
        entry.data.isLightTheme ? Color(red: 0.42, green: 0.31, blue: 0.90) : Color(red: 1, green: 0.84, blue: 0.31)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 10) {
                // Ícono
                Image(systemName: entry.data.isDiscreetMode ? "calendar" : "trophy.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Circle())
                
                // Título
                Text(entry.data.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Línea 1
            if !entry.data.line1.isEmpty {
                Text(entry.data.line1)
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)
                    .lineLimit(2)
            }
            
            // Línea 2
            if !entry.data.line2.isEmpty {
                Text(entry.data.line2)
                    .font(.system(size: 11))
                    .foregroundColor(subtitleColor.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // CTA
            if entry.data.showCTA {
                Text(entry.data.isDiscreetMode ? "Abrir" : "Ver más")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Widget principal
@main
struct VictoryWidget: Widget {
    let kind: String = "VictoryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VictoryWidgetProvider()) { entry in
            VictoryWidgetView(entry: entry)
        }
        .configurationDisplayName("Recordatorio")
        .description("Widget discreto para tu rutina diaria")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Preview
struct VictoryWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VictoryWidgetView(entry: VictoryEntry(date: Date(), data: .placeholder))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Light")
            
            VictoryWidgetView(entry: VictoryEntry(
                date: Date(),
                data: VictoryWidgetData(
                    title: "Rutina diaria",
                    line1: "Respira. Sigue hoy.",
                    line2: "3 días de progreso",
                    streakValue: 3,
                    showStreak: true,
                    showVerse: false,
                    showCTA: true,
                    isLightTheme: false,
                    isDiscreetMode: true
                )
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Dark")
        }
    }
}
