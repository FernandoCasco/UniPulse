//
//  DetalleMetricaView.swift
//  UniPulse
//
//  Detalle de un dato de salud: progreso de hoy, últimos 7 días y su meta.
//

import SwiftUI

struct DetalleMetricaView: View {
    let tipo: TipoDato

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)])
    private var resumenes: FetchedResults<ResumenDiario>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Meta.tipo, ascending: true)])
    private var metas: FetchedResults<Meta>

    private var objetivo: Double? { Calculos.objetivo(tipo, metas: Array(metas)) }

    private var meta: Meta? { metas.first { $0.tipo == tipo.rawValue } }

    /// Los últimos 7 días, de hoy hacia atrás.
    private var dias: [PuntoDia] {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        return (0..<7).map { d in
            let dia = calendario.date(byAdding: .day, value: -d, to: hoy)!
            let resumen = resumenes.first { $0.fecha == dia }
            return PuntoDia(fecha: dia, valor: resumen.map { tipo.valor(de: $0) } ?? 0)
        }
    }

    private var valorHoy: Double { dias.first?.valor ?? 0 }
    private var promedio: Double { dias.map(\.valor).reduce(0, +) / 7 }

    private func progreso(_ valor: Double) -> Double {
        guard let objetivo, objetivo > 0 else { return 0 }
        return valor / objetivo
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Anillo(progreso: progreso(valorHoy), color: tipo.color, grosor: 18)
                        VStack(spacing: 2) {
                            Image(systemName: tipo.icono)
                                .font(.title2)
                                .foregroundColor(tipo.color)
                            Text(tipo.formatear(valorHoy))
                                .font(.title.bold())
                            Text(tipo.unidad)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 170, height: 170)
                    .padding(.top, 8)

                    HStack {
                        dato("Hoy", progreso(valorHoy).formatted(.percent.precision(.fractionLength(0))),
                             color: tipo.color)
                        Divider()
                        dato("Meta", objetivo.map { tipo.textoMeta($0) } ?? "—")
                        Divider()
                        dato("Promedio", tipo.formatear(promedio))
                    }
                    .frame(height: 44)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Últimos 7 días") {
                ForEach(dias) { dia in
                    HStack(spacing: 12) {
                        Text(Calendar.current.isDateInToday(dia.fecha) ? "Hoy" : Formato.diaCorto(dia.fecha))
                            .font(.subheadline)
                            .frame(width: 90, alignment: .leading)
                        ProgressView(value: min(progreso(dia.valor), 1))
                            .tint(tipo.color)
                        Text(tipo.formatear(dia.valor))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 56, alignment: .trailing)
                        Image(systemName: cumple(dia.valor) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(cumple(dia.valor) ? .green : Color(.tertiaryLabel))
                    }
                }
            }

            if let meta {
                Section {
                    NavigationLink {
                        EditarMetaView(meta: meta, tipo: tipo)
                    } label: {
                        Label("Editar meta diaria", systemImage: "target")
                    }
                }
            }

            Section {
                Text(tipo.descripcion)
                    .font(.subheadline)
                LabeledContent("Fuente", value: "HealthKit")
                Text(tipo.identificadorHealthKit)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            } header: {
                Text("Acerca de este dato")
            }
        }
        .navigationTitle(tipo.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cumple(_ valor: Double) -> Bool {
        guard let objetivo else { return false }
        return valor > 0 && valor >= objetivo
    }

    private func dato(_ titulo: String, _ valor: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(valor)
                .font(.headline)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetalleMetricaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DetalleMetricaView(tipo: .pasos)
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
