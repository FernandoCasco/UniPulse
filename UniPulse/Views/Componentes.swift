//
//  Componentes.swift
//  UniPulse
//
//  Colores, formatos y vistas reutilizables.
//

import SwiftUI

enum Tema {
    /// Color de acento de Assets (vino #7A1F3D; más claro en modo oscuro).
    static let vino = Color.accentColor
    static let pasos = Color.green
    static let sueno = Color.purple
    static let activos = Color.orange
    static let animo = Color.blue
}

enum Formato {
    static func entero(_ valor: Double) -> String {
        valor.formatted(.number.precision(.fractionLength(0)))
    }
    static func decimal(_ valor: Double) -> String {
        valor.formatted(.number.precision(.fractionLength(1)))
    }
    static func diaCorto(_ fecha: Date?) -> String {
        guard let fecha else { return "" }
        return fecha.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).inicialMayuscula
    }
    static func diaLargo(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.weekday(.wide).day().month(.wide)).inicialMayuscula
    }
}

extension String {
    /// "domingo, 1 de noviembre" → "Domingo, 1 de noviembre"
    var inicialMayuscula: String {
        prefix(1).uppercased() + dropFirst()
    }
}

/// Tarjeta con el valor de hoy, la meta y una barra de progreso.
struct TarjetaMetrica: View {
    let titulo: String
    let icono: String
    let color: Color
    let valor: String
    let unidad: String
    let meta: String?
    let progreso: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(valor)
                            .font(.title2.bold())
                        Text(unidad)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(meta.map { "meta \($0)" } ?? "sin meta")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            if meta != nil {
                ProgressView(value: min(max(progreso, 0), 1))
                    .tint(color)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Selector táctil de 1 a 5 con caritas; debajo muestra la palabra del nivel elegido.
struct EscalaSelector: View {
    @Binding var valor: Int
    let escala: Escala
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { nivel in
                    Button {
                        valor = nivel
                        Haptico.toque()
                    } label: {
                        Text(escala.emoji(nivel))
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(valor == nivel ? color.opacity(0.22) : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(valor == nivel ? color : .clear, lineWidth: 2)
                            )
                            .scaleEffect(valor == nivel ? 1.06 : 1)
                            .animation(.spring(response: 0.25), value: valor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(escala.texto(nivel))
                }
            }
            Text(escala.texto(valor))
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

/// Etiqueta pequeña tipo cápsula.
struct Etiqueta: View {
    let texto: String
    let color: Color

    var body: some View {
        Text(texto)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundColor(color)
    }
}

// MARK: - Anillos de actividad

/// Un anillo de progreso al estilo de la app Actividad del iPhone.
struct Anillo: View {
    let progreso: Double
    let color: Color
    var grosor: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: grosor)
            Circle()
                .trim(from: 0, to: min(max(progreso, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progreso)
        }
    }
}

/// Tres anillos concéntricos: pasos (exterior), minutos activos y sueño (interior).
struct AnillosActividad: View {
    let pasos: Double
    let activos: Double
    let sueno: Double
    var grosor: CGFloat = 16

    var body: some View {
        ZStack {
            Anillo(progreso: pasos, color: Tema.pasos, grosor: grosor)
            Anillo(progreso: activos, color: Tema.activos, grosor: grosor)
                .padding(grosor + 4)
            Anillo(progreso: sueno, color: Tema.sueno, grosor: grosor)
                .padding((grosor + 4) * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progreso de hoy: pasos \(Int(pasos * 100)) por ciento, minutos activos \(Int(activos * 100)) por ciento, sueño \(Int(sueno * 100)) por ciento")
    }
}

/// Círculo con la inicial del estudiante, como el avatar de la app Salud.
struct Avatar: View {
    let nombre: String?
    var tamano: CGFloat = 34

    var body: some View {
        Text(String(nombre?.first ?? "U").uppercased())
            .font(.system(size: tamano * 0.45, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: tamano, height: tamano)
            .background(Tema.vino.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Respuesta háptica

enum Haptico {
    static func exito() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func toque() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Apariencia

/// Preferencia de modo claro u oscuro, guardada en AppStorage.
enum Apariencia: String, CaseIterable, Identifiable {
    case sistema, claro, oscuro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .sistema: return "Sistema"
        case .claro: return "Claro"
        case .oscuro: return "Oscuro"
        }
    }

    /// nil = seguir la configuración del iPhone.
    var esquema: ColorScheme? {
        switch self {
        case .sistema: return nil
        case .claro: return .light
        case .oscuro: return .dark
        }
    }
}
