//
//  PerfilView.swift
//  UniPulse
//
//  Perfil del estudiante, abierto al tocar el avatar de Inicio (como en la app Salud).
//

import SwiftUI

struct PerfilView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PerfilEstudiante.fechaRegistro, ascending: true)])
    private var perfiles: FetchedResults<PerfilEstudiante>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Meta.tipo, ascending: true)])
    private var metas: FetchedResults<Meta>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)])
    private var resumenes: FetchedResults<ResumenDiario>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \RegistroAnimo.fecha, ascending: false)])
    private var registros: FetchedResults<RegistroAnimo>

    @State private var editando = false

    private var perfil: PerfilEstudiante? { perfiles.first }

    private var animoPromedio: String {
        guard !registros.isEmpty else { return "—" }
        let promedio = registros.map { Double($0.nivelAnimo) }.reduce(0, +) / Double(registros.count)
        let nivel = Int(promedio.rounded())
        return "\(Escala.animo.emoji(nivel)) \(Escala.animo.texto(nivel)) (\(Formato.decimal(promedio))/5)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Avatar(nombre: perfil?.nombre, tamano: 96)
                        Text(perfil?.nombre ?? "Estudiante")
                            .font(.title2.bold())
                        if let carrera = perfil?.carrera, !carrera.isEmpty {
                            Text(carrera)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Perfil") {
                    Button {
                        editando = true
                    } label: {
                        Label("Editar nombre y carrera", systemImage: "person.text.rectangle")
                    }
                    if let fecha = perfil?.fechaRegistro {
                        LabeledContent("Usas UniPulse desde",
                                       value: fecha.formatted(date: .long, time: .omitted))
                    }
                }

                Section("Mis metas diarias") {
                    ForEach(TipoDato.allCases) { tipo in
                        LabeledContent {
                            Text(Calculos.objetivo(tipo, metas: Array(metas)).map { tipo.textoMeta($0) }
                                 ?? "Desactivada")
                        } label: {
                            Label(tipo.titulo, systemImage: tipo.icono)
                                .foregroundColor(tipo.color)
                        }
                    }
                }

                Section("Mis datos") {
                    LabeledContent("Días guardados", value: "\(resumenes.count)")
                    LabeledContent("Registros de ánimo", value: "\(registros.count)")
                    LabeledContent("Ánimo promedio", value: animoPromedio)
                }

                Section {
                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            openURL(url)
                        }
                    } label: {
                        Label("Abrir la app Salud", systemImage: "heart.fill")
                            .foregroundColor(.pink)
                    }
                } footer: {
                    Text("Tus datos de UniPulse se guardan solo en este iPhone con Core Data. Los datos de salud se leen desde la app Salud con tu permiso.")
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $editando) {
                if let perfil {
                    EditarPerfilView(perfil: perfil)
                        .environmentObject(vm)
                }
            }
        }
    }
}

struct PerfilView_Previews: PreviewProvider {
    static var previews: some View {
        PerfilView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
