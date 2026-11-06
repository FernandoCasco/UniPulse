//
//  TipoDato.swift
//  UniPulse
//
//  Los tres datos de salud que maneja la app, con su presentación y meta por defecto.
//

import SwiftUI
import CoreData

enum TipoDato: String, CaseIterable, Identifiable {
    case pasos
    case sueno
    case minutosActivos

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .pasos: return "Pasos"
        case .sueno: return "Sueño"
        case .minutosActivos: return "Minutos activos"
        }
    }

    var tituloCorto: String {
        switch self {
        case .pasos: return "Pasos"
        case .sueno: return "Sueño"
        case .minutosActivos: return "Activos"
        }
    }

    var unidad: String {
        switch self {
        case .pasos: return "pasos"
        case .sueno: return "horas"
        case .minutosActivos: return "min"
        }
    }

    var icono: String {
        switch self {
        case .pasos: return "figure.walk"
        case .sueno: return "bed.double.fill"
        case .minutosActivos: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .pasos: return Tema.pasos
        case .sueno: return Tema.sueno
        case .minutosActivos: return Tema.activos
        }
    }

    /// Identificador del dato en HealthKit (se muestra en el detalle con fines didácticos).
    var identificadorHealthKit: String {
        switch self {
        case .pasos: return "HKQuantityTypeIdentifier.stepCount"
        case .sueno: return "HKCategoryTypeIdentifier.sleepAnalysis"
        case .minutosActivos: return "HKQuantityTypeIdentifier.appleExerciseTime"
        }
    }

    var descripcion: String {
        switch self {
        case .pasos:
            return "Pasos que registra el iPhone o el Apple Watch. Se recomienda caminar al menos 8 000 al día; en semanas de estudio intenso conviene hacer pausas activas."
        case .sueno:
            return "Horas dormidas la noche anterior. Dormir entre 7 y 9 horas mejora la memoria y la concentración para estudiar."
        case .minutosActivos:
            return "Minutos de actividad física moderada o intensa. La OMS recomienda al menos 150 minutos a la semana, unos 30 al día."
        }
    }

    var metaPorDefecto: Double {
        switch self {
        case .pasos: return 8_000
        case .sueno: return 7.5
        case .minutosActivos: return 30
        }
    }

    /// Paso del Stepper al editar la meta.
    var incremento: Double {
        switch self {
        case .pasos: return 500
        case .sueno: return 0.5
        case .minutosActivos: return 5
        }
    }

    var rango: ClosedRange<Double> {
        switch self {
        case .pasos: return 1_000...30_000
        case .sueno: return 4...12
        case .minutosActivos: return 5...180
        }
    }

    func valor(de resumen: ResumenDiario) -> Double {
        switch self {
        case .pasos: return Double(resumen.pasos)
        case .sueno: return resumen.horasSueno
        case .minutosActivos: return Double(resumen.minutosActivos)
        }
    }

    func formatear(_ valor: Double) -> String {
        self == .sueno ? Formato.decimal(valor) : Formato.entero(valor)
    }

    /// Versión corta para etiquetas sobre las barras: 9032 → "9.0k".
    func formatearCorto(_ valor: Double) -> String {
        if self == .pasos && valor >= 1_000 {
            return Formato.decimal(valor / 1_000) + "k"
        }
        return formatear(valor)
    }

    /// Texto de una meta: "8 000 pasos", "7.5 h", "30 min".
    func textoMeta(_ valor: Double) -> String {
        switch self {
        case .pasos: return "\(Formato.entero(valor)) pasos"
        case .sueno: return "\(Formato.decimal(valor)) h"
        case .minutosActivos: return "\(Formato.entero(valor)) min"
        }
    }
}

// MARK: - Cálculos sobre metas y resúmenes

enum Calculos {
    /// Objetivo vigente de un tipo: la meta activa del estudiante, o la meta por defecto si aún no hay metas.
    /// Devuelve nil si el estudiante desactivó esa meta.
    static func objetivo(_ tipo: TipoDato, metas: [Meta]) -> Double? {
        guard let meta = metas.first(where: { $0.tipo == tipo.rawValue }) else {
            return tipo.metaPorDefecto
        }
        return meta.activa ? meta.valorObjetivo : nil
    }

    /// Los últimos 7 días, incluido hoy (la misma ventana que usan las gráficas).
    static var ultimos7Dias: DateInterval {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let inicio = calendario.date(byAdding: .day, value: -6, to: hoy)!
        let fin = calendario.date(byAdding: .day, value: 1, to: hoy)!
        return DateInterval(start: inicio, end: fin)
    }

    /// Cuántos de los últimos 7 días se alcanzó el objetivo.
    static func diasCumplidos(_ tipo: TipoDato, objetivo: Double, resumenes: [ResumenDiario]) -> Int {
        let ventana = ultimos7Dias
        return resumenes.filter { resumen in
            guard let fecha = resumen.fecha else { return false }
            let valor = tipo.valor(de: resumen)
            return ventana.contains(fecha) && valor > 0 && valor >= objetivo
        }.count
    }
}

// MARK: - Escalas de bienestar

/// Escala de 1 a 5 con una carita y una palabra por nivel, para que el registro se entienda sin números.
struct Escala {
    let emojis: [String]
    let textos: [String]

    static let animo = Escala(emojis: ["😞", "🙁", "😐", "🙂", "😄"],
                              textos: ["Muy bajo", "Bajo", "Normal", "Bien", "Excelente"])
    static let estres = Escala(emojis: ["😌", "🙂", "😐", "😟", "😫"],
                               textos: ["Tranquilo", "Leve", "Moderado", "Alto", "Muy alto"])

    private func indice(_ nivel: Int) -> Int { min(max(nivel, 1), 5) - 1 }

    func emoji(_ nivel: Int) -> String { emojis[indice(nivel)] }
    func texto(_ nivel: Int) -> String { textos[indice(nivel)] }
}

extension RegistroAnimo {
    var emojiAnimo: String { Escala.animo.emoji(Int(nivelAnimo)) }
    var textoAnimo: String { Escala.animo.texto(Int(nivelAnimo)) }
    var textoEstres: String { Escala.estres.texto(Int(nivelEstres)) }
}
