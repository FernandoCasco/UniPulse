//
//  HistorialView.swift
//  UniPulse
//
//  Lista de días guardados en Core Data y detalle de cada día.
//

import SwiftUI

struct HistorialView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)],
                  animation: .default)
    private var resumenes: FetchedResults<ResumenDiario>

    var body: some View {
        NavigationStack {
            List {
                if resumenes.isEmpty {
                    Text("Todavía no hay días guardados. Sincroniza o genera datos de prueba en Ajustes.")
                        .foregroundColor(.secondary)
                } else {
                    Section {
                        ForEach(resumenes) { resumen in
                            NavigationLink {
                                DetalleDiarioView(resumen: resumen)
                            } label: {
                                FilaResumen(resumen: resumen)
                            }
                        }
                    } footer: {
                        Text("\(resumenes.count) días guardados en Core Data")
                    }
                }
            }
            .navigationTitle("Historial")
            .refreshable { await vm.sincronizar() }
        }
    }
}

struct FilaResumen: View {
    @ObservedObject var resumen: ResumenDiario

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Formato.diaCorto(resumen.fecha))
                        .font(.subheadline.weight(.semibold))
                    if resumen.fuente == Fuente.prueba {
                        Etiqueta(texto: "Prueba", color: .orange)
                    }
                }
                HStack(spacing: 10) {
                    Label(Formato.entero(Double(resumen.pasos)), systemImage: TipoDato.pasos.icono)
                    Label("\(Formato.decimal(resumen.horasSueno)) h", systemImage: TipoDato.sueno.icono)
                    Label("\(resumen.minutosActivos) min", systemImage: TipoDato.minutosActivos.icono)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .labelStyle(EtiquetaCompacta())
            }
            Spacer(minLength: 0)
            if let animo = resumen.animo {
                EtiquetaAnimo(animo: animo)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Icono pequeño pegado al texto, para que las tres cifras quepan en una línea.
struct EtiquetaCompacta: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .imageScale(.small)
            configuration.title
                .lineLimit(1)
        }
    }
}

/// Carita del ánimo del día; observa el registro para actualizarse cuando se edita.
struct EtiquetaAnimo: View {
    @ObservedObject var animo: RegistroAnimo

    var body: some View {
        VStack(spacing: 0) {
            Text(animo.emojiAnimo)
                .font(.title2)
            Text(animo.textoAnimo)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 56)
        .accessibilityElement(children: .combine)
    }
}

struct FilasAnimo: View {
    @ObservedObject var animo: RegistroAnimo

    var body: some View {
        LabeledContent("Ánimo",
                       value: "\(animo.emojiAnimo) \(animo.textoAnimo) (\(animo.nivelAnimo)/5)")
        LabeledContent("Estrés",
                       value: "\(Escala.estres.emoji(Int(animo.nivelEstres))) \(animo.textoEstres) (\(animo.nivelEstres)/5)")
        if let nota = animo.nota {
            Text(nota)
                .foregroundColor(.secondary)
        }
    }
}

struct DetalleDiarioView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @ObservedObject var resumen: ResumenDiario
    @State private var mostrarRegistro = false
    @State private var confirmarEliminar = false

    var body: some View {
        List {
            Section("Actividad") {
                ForEach(TipoDato.allCases) { tipo in
                    LabeledContent {
                        Text("\(tipo.formatear(tipo.valor(de: resumen))) \(tipo.unidad)")
                    } label: {
                        Label(tipo.titulo, systemImage: tipo.icono)
                            .foregroundColor(tipo.color)
                    }
                }
                LabeledContent {
                    Text("\(Formato.decimal(resumen.distanciaKm)) km")
                } label: {
                    Label("Distancia", systemImage: "map")
                        .foregroundColor(Tema.pasos)
                }
            }

            Section("Ánimo") {
                if let animo = resumen.animo {
                    FilasAnimo(animo: animo)
                    Button("Editar registro") { mostrarRegistro = true }
                    Button("Eliminar registro", role: .destructive) { confirmarEliminar = true }
                } else {
                    Button {
                        mostrarRegistro = true
                    } label: {
                        Label("Registrar ánimo de este día", systemImage: "plus.circle")
                    }
                }
            }

            Section("Origen de los datos") {
                LabeledContent("Fuente", value: resumen.fuente ?? "—")
                if let fecha = resumen.fechaSincronizacion {
                    LabeledContent("Última lectura",
                                   value: fecha.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle(Formato.diaCorto(resumen.fecha))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar el registro de ánimo de este día?",
                            isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let animo = resumen.animo {
                    vm.eliminarAnimo(animo)
                    Haptico.toque()
                }
            }
        }
        .sheet(isPresented: $mostrarRegistro) {
            NuevoRegistroView(fecha: resumen.fecha ?? Date())
                .environmentObject(vm)
        }
    }
}

struct HistorialView_Previews: PreviewProvider {
    static var previews: some View {
        HistorialView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
