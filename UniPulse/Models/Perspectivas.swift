//
//  Perspectivas.swift
//  UniPulse
//
//  Cruza los datos guardados en Core Data para encontrar relaciones entre
//  el sueño, la actividad, el ánimo y el estrés del estudiante.
//

import SwiftUI
import CoreData

struct Perspectiva: Identifiable {
    let id: String
    let icono: String
    let color: Color
    let titulo: String
    let detalle: String
}

enum Perspectivas {
    /// Mínimo de días con ánimo registrado para poder comparar.
    static let minimoRegistros = 3

    static func generar(resumenes: [ResumenDiario], metaPasos: Double?) -> [Perspectiva] {
        let conAnimo = resumenes.filter { $0.animo != nil }
        var resultado: [Perspectiva] = []

        if conAnimo.count < minimoRegistros {
            let faltan = minimoRegistros - conAnimo.count
            resultado.append(Perspectiva(
                id: "faltan-datos", icono: "sparkles", color: Tema.animo,
                titulo: "Registra tu ánimo \(faltan) \(faltan == 1 ? "día" : "días") más",
                detalle: "Con al menos \(minimoRegistros) días registrados, UniPulse te mostrará cómo se relaciona tu ánimo con tu sueño y tu actividad."))
        } else {
            if let p = suenoYAnimo(conAnimo) { resultado.append(p) }
            if let p = estresYPasos(conAnimo) { resultado.append(p) }
        }
        if let p = racha(resumenes, meta: metaPasos) { resultado.append(p) }
        if let p = promedioSueno(resumenes) { resultado.append(p) }
        return resultado
    }

    // MARK: - Reglas

    /// Compara el ánimo promedio de los días con 7 h de sueño o más contra los demás.
    private static func suenoYAnimo(_ dias: [ResumenDiario]) -> Perspectiva? {
        let conSueno = dias.filter { $0.horasSueno > 0 }
        let descansados = conSueno.filter { $0.horasSueno >= 7 }
        let cansados = conSueno.filter { $0.horasSueno < 7 }
        guard !descansados.isEmpty, !cansados.isEmpty else { return nil }

        let animoA = promedio(descansados.map { Double($0.animo?.nivelAnimo ?? 0) })
        let animoB = promedio(cansados.map { Double($0.animo?.nivelAnimo ?? 0) })
        let textoA = Escala.animo.texto(Int(animoA.rounded())).lowercased()
        let textoB = Escala.animo.texto(Int(animoB.rounded())).lowercased()
        let detalle = "Cuando duermes 7 h o más, en promedio te sientes \(textoA) (\(Formato.decimal(animoA))/5); cuando duermes menos, \(textoB) (\(Formato.decimal(animoB))/5)."

        if animoA - animoB >= 0.5 {
            return Perspectiva(id: "sueno-animo", icono: "bed.double.fill", color: Tema.sueno,
                               titulo: "Dormir bien mejora tu ánimo", detalle: detalle)
        }
        return Perspectiva(id: "sueno-animo", icono: "bed.double.fill", color: Tema.sueno,
                           titulo: "Tu ánimo no cambia mucho con el sueño", detalle: detalle)
    }

    /// Compara los pasos de los días con estrés alto (4–5) contra los días con estrés bajo (1–3).
    private static func estresYPasos(_ dias: [ResumenDiario]) -> Perspectiva? {
        let altos = dias.filter { ($0.animo?.nivelEstres ?? 0) >= 4 }
        let bajos = dias.filter { ($0.animo?.nivelEstres ?? 0) <= 3 }
        guard !altos.isEmpty, !bajos.isEmpty else { return nil }

        let pasosAltos = promedio(altos.map { Double($0.pasos) })
        let pasosBajos = promedio(bajos.map { Double($0.pasos) })
        guard pasosBajos > 0 else { return nil }
        let diferencia = (pasosBajos - pasosAltos) / pasosBajos

        if diferencia >= 0.1 {
            return Perspectiva(
                id: "estres-pasos", icono: "figure.walk", color: Tema.activos,
                titulo: "Con estrés alto te mueves menos",
                detalle: "Los días de estrés alto caminaste un \(diferencia.formatted(.percent.precision(.fractionLength(0)))) menos (\(Formato.entero(pasosAltos)) frente a \(Formato.entero(pasosBajos)) pasos). Una caminata corta entre clases puede ayudarte a bajarlo.")
        }
        return Perspectiva(
            id: "estres-pasos", icono: "figure.walk", color: Tema.activos,
            titulo: "El estrés no frena tu actividad",
            detalle: "Caminas parecido con estrés alto (\(Formato.entero(pasosAltos))) y con estrés bajo (\(Formato.entero(pasosBajos)) pasos).")
    }

    /// Días seguidos cumpliendo la meta de pasos. Si hoy aún no se cumple, se cuenta desde ayer.
    private static func racha(_ resumenes: [ResumenDiario], meta: Double?) -> Perspectiva? {
        guard let meta, meta > 0 else { return nil }
        let calendario = Calendar.current
        var dia = calendario.startOfDay(for: Date())
        func pasos(_ fecha: Date) -> Double {
            Double(resumenes.first { $0.fecha == fecha }?.pasos ?? 0)
        }
        if pasos(dia) < meta {
            dia = calendario.date(byAdding: .day, value: -1, to: dia)!
        }
        var cuenta = 0
        while pasos(dia) >= meta && cuenta < 60 {
            cuenta += 1
            dia = calendario.date(byAdding: .day, value: -1, to: dia)!
        }
        guard cuenta >= 2 else { return nil }
        return Perspectiva(id: "racha", icono: "flame.fill", color: Tema.pasos,
                           titulo: "¡Racha de \(cuenta) días!",
                           detalle: "Llevas \(cuenta) días seguidos cumpliendo tu meta de \(Formato.entero(meta)) pasos.")
    }

    /// Promedio de sueño de los últimos 7 días frente a lo recomendado (7 h).
    private static func promedioSueno(_ resumenes: [ResumenDiario]) -> Perspectiva? {
        let ventana = Calculos.ultimos7Dias
        let horas = resumenes
            .filter { ($0.fecha.map { ventana.contains($0) } ?? false) && $0.horasSueno > 0 }
            .map(\.horasSueno)
        guard horas.count >= 3 else { return nil }
        let media = promedio(horas)
        if media < 7 {
            return Perspectiva(id: "sueno-semana", icono: "moon.zzz.fill", color: Tema.sueno,
                               titulo: "Esta semana dormiste \(Formato.decimal(media)) h por noche",
                               detalle: "Te faltan \(Formato.decimal(7 - media)) h para lo recomendado. Dormir bien mejora la memoria antes de un examen.")
        }
        return Perspectiva(id: "sueno-semana", icono: "moon.stars.fill", color: Tema.sueno,
                           titulo: "Buen descanso esta semana",
                           detalle: "Dormiste \(Formato.decimal(media)) h por noche en promedio, dentro de lo recomendado (7 a 9 h).")
    }

    private static func promedio(_ valores: [Double]) -> Double {
        valores.isEmpty ? 0 : valores.reduce(0, +) / Double(valores.count)
    }
}

/// Tarjeta para mostrar una perspectiva en Inicio.
struct TarjetaPerspectiva: View {
    let perspectiva: Perspectiva

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: perspectiva.icono)
                .font(.headline)
                .foregroundColor(perspectiva.color)
                .frame(width: 36, height: 36)
                .background(perspectiva.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(perspectiva.titulo)
                    .font(.headline)
                Text(perspectiva.detalle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
