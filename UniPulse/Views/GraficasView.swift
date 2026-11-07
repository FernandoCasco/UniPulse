//
//  GraficasView.swift
//  UniPulse
//
//  Gráfica de barras de los últimos 7 días con la línea de meta (Swift Charts).
//

import SwiftUI
import Charts

struct PuntoDia: Identifiable {
    let fecha: Date
    let valor: Double
    var id: Date { fecha }
}

struct GraficasView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)])
    private var resumenes: FetchedResults<ResumenDiario>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Meta.tipo, ascending: true)])
    private var metas: FetchedResults<Meta>

    @State private var tipo: TipoDato = .pasos
    /// Día que el estudiante tocó en la gráfica (nil = se muestra el promedio).
    @State private var seleccion: Date?

    private var puntoSeleccionado: PuntoDia? {
        guard let seleccion else { return nil }
        return puntos.first { $0.fecha == seleccion }
    }

    /// Siempre 7 puntos, del más antiguo a hoy; los días sin datos valen 0.
    private var puntos: [PuntoDia] {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        return (0..<7).reversed().map { d in
            let dia = calendario.date(byAdding: .day, value: -d, to: hoy)!
            let resumen = resumenes.first { $0.fecha == dia }
            return PuntoDia(fecha: dia, valor: resumen.map { tipo.valor(de: $0) } ?? 0)
        }
    }

    private var objetivo: Double? { Calculos.objetivo(tipo, metas: Array(metas)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Dato", selection: $tipo) {
                        ForEach(TipoDato.allCases) { tipo in
                            Text(tipo.tituloCorto).tag(tipo)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: tipo) { _ in seleccion = nil }

                    tarjetaGrafica
                    tarjetaEstadisticas
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gráficas")
        }
    }

    private var tarjetaGrafica: some View {
        let promedio = puntos.map(\.valor).reduce(0, +) / Double(puntos.count)
        let elegido = puntoSeleccionado
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(elegido.map { Formato.diaLargo($0.fecha).uppercased() }
                     ?? "PROMEDIO DIARIO · ÚLTIMOS 7 DÍAS")
                    .font(.caption)
                    .foregroundColor(elegido == nil ? .secondary : tipo.color)
                Spacer()
                if elegido != nil {
                    Button {
                        withAnimation { seleccion = nil }
                    } label: {
                        Label("Ver promedio", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(tipo.formatear(elegido?.valor ?? promedio))
                    .font(.title.bold())
                    .contentTransition(.numericText())
                Text(tipo.unidad)
                    .foregroundColor(.secondary)
                Spacer()
                if let objetivo {
                    if let elegido {
                        Etiqueta(texto: cumple(elegido.valor) ? "✓ meta cumplida"
                                 : "faltó \(tipo.textoMeta(max(objetivo - elegido.valor, 0)))",
                                 color: cumple(elegido.valor) ? .green : .orange)
                    } else {
                        Etiqueta(texto: "meta \(tipo.textoMeta(objetivo))", color: .orange)
                    }
                }
            }

            Chart {
                ForEach(puntos) { punto in
                    BarMark(x: .value("Día", punto.fecha, unit: .day),
                            y: .value(tipo.titulo, punto.valor))
                    .foregroundStyle(cumple(punto.valor) ? tipo.color : tipo.color.opacity(0.35))
                    .cornerRadius(6)
                    .opacity(seleccion == nil || seleccion == punto.fecha ? 1 : 0.35)
                    .annotation(position: .top, spacing: 4) {
                        if punto.valor > 0 {
                            Text(tipo.formatearCorto(punto.valor))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if let objetivo {
                    RuleMark(y: .value("Meta", objetivo))
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { valor in
                    AxisValueLabel(centered: true) {
                        if let fecha = valor.as(Date.self) {
                            Text(Calendar.current.isDateInToday(fecha)
                                 ? "Hoy" : fecha.formatted(.dateTime.weekday(.narrow)))
                        }
                    }
                }
            }
            // Tocar o deslizar el dedo sobre la gráfica selecciona un día.
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesto in
                                    let x = gesto.location.x - geo[proxy.plotAreaFrame].origin.x
                                    guard let fecha: Date = proxy.value(atX: x) else { return }
                                    let dia = Calendar.current.startOfDay(for: fecha)
                                    guard puntos.contains(where: { $0.fecha == dia }),
                                          dia != seleccion else { return }
                                    withAnimation(.easeOut(duration: 0.15)) { seleccion = dia }
                                    Haptico.toque()
                                }
                        )
                }
            }
            .frame(height: 240)
            .accessibilityLabel("Gráfica de \(tipo.titulo.lowercased()) de los últimos 7 días")

            Text(seleccion == nil ? "Toca o desliza sobre las barras para ver cada día"
                                  : "Desliza para cambiar de día")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private var tarjetaEstadisticas: some View {
        let cumplidos = puntos.filter { cumple($0.valor) }.count
        let mejor = puntos.max { $0.valor < $1.valor }
        let hoy = puntos.last?.valor ?? 0
        return HStack(alignment: .top) {
            estadistica("Hoy", valor: tipo.formatear(hoy), detalle: tipo.unidad, color: tipo.color)
            Divider()
            estadistica("Meta cumplida", valor: objetivo == nil ? "—" : "\(cumplidos) de 7",
                        detalle: "días")
            Divider()
            estadistica("Mejor día", valor: mejor.map { tipo.formatear($0.valor) } ?? "—",
                        detalle: mejor.map { Formato.diaCorto($0.fecha) } ?? "")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func estadistica(_ titulo: String, valor: String, detalle: String,
                             color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(titulo)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(valor)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(detalle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func cumple(_ valor: Double) -> Bool {
        guard let objetivo else { return true }
        return valor >= objetivo && valor > 0
    }
}

struct GraficasView_Previews: PreviewProvider {
    static var previews: some View {
        GraficasView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
