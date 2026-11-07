//
//  MetasView.swift
//  UniPulse
//
//  Metas semanales guardadas en Core Data y su avance en la semana actual.
//

import SwiftUI

struct MetasView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Meta.tipo, ascending: true)],
                  animation: .default)
    private var metas: FetchedResults<Meta>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)])
    private var resumenes: FetchedResults<ResumenDiario>

    private var periodoTexto: String {
        let ventana = Calculos.ultimos7Dias
        let fin = Calendar.current.date(byAdding: .day, value: -1, to: ventana.end) ?? ventana.end
        let formato = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "Últimos 7 días (\(ventana.start.formatted(formato)) – \(fin.formatted(formato)))"
    }

    /// Metas en el orden de TipoDato (pasos, sueño, minutos activos).
    private var metasOrdenadas: [(TipoDato, Meta)] {
        TipoDato.allCases.compactMap { tipo in
            metas.first { $0.tipo == tipo.rawValue }.map { (tipo, $0) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if metasOrdenadas.isEmpty {
                    Text("Aún no tienes metas. Se crean al registrar tu perfil.")
                        .foregroundColor(.secondary)
                } else {
                    Section {
                        ForEach(metasOrdenadas, id: \.0) { tipo, meta in
                            NavigationLink {
                                EditarMetaView(meta: meta, tipo: tipo)
                            } label: {
                                FilaMeta(tipo: tipo, meta: meta, resumenes: Array(resumenes))
                            }
                        }
                    } header: {
                        Text(periodoTexto)
                    } footer: {
                        Text("Una meta se cumple el día en que alcanzas el valor objetivo. Toca una meta para cambiarla o desactivarla.")
                    }
                }
            }
            .navigationTitle("Metas")
        }
    }
}

struct FilaMeta: View {
    let tipo: TipoDato
    @ObservedObject var meta: Meta
    let resumenes: [ResumenDiario]

    var body: some View {
        let dias = Calculos.diasCumplidos(tipo, objetivo: meta.valorObjetivo, resumenes: resumenes)
        let porcentaje = Double(dias) / 7

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: tipo.icono)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(meta.activa ? tipo.color : Color.gray,
                                in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tipo.textoMeta(meta.valorObjetivo) + " diarios")
                        .font(.headline)
                    Text(meta.activa ? "\(dias) de 7 días cumplidos" : "Meta desactivada")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if meta.activa {
                    Text(porcentaje.formatted(.percent.precision(.fractionLength(0))))
                        .font(.headline)
                }
            }
            if meta.activa {
                ProgressView(value: porcentaje)
                    .tint(tipo.color)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditarMetaView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var meta: Meta
    let tipo: TipoDato

    @State private var valor: Double = 0
    @State private var activa = true

    var body: some View {
        Form {
            Section {
                Stepper(value: $valor, in: tipo.rango, step: tipo.incremento) {
                    HStack {
                        Text("Objetivo diario")
                        Spacer()
                        Text(tipo.textoMeta(valor))
                            .font(.headline)
                            .foregroundColor(tipo.color)
                    }
                }
                Toggle("Meta activa", isOn: $activa)
            } header: {
                Text(tipo.titulo)
            } footer: {
                Text("Valor recomendado: \(tipo.textoMeta(tipo.metaPorDefecto)).")
            }

            Section {
                Button("Restablecer valor recomendado") {
                    valor = tipo.metaPorDefecto
                }
            }
        }
        .navigationTitle("Editar meta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    vm.actualizarMeta(meta, valor: valor, activa: activa)
                    Haptico.exito()
                    dismiss()
                }
            }
        }
        .onAppear {
            valor = meta.valorObjetivo
            activa = meta.activa
        }
    }
}

struct MetasView_Previews: PreviewProvider {
    static var previews: some View {
        MetasView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
