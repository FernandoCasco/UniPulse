//
//  AjustesView.swift
//  UniPulse
//
//  Perfil, permisos de HealthKit y datos de prueba para la demostración.
//

import SwiftUI
import HealthKit

struct AjustesView: View {
    @EnvironmentObject private var vm: DashboardViewModel

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PerfilEstudiante.fechaRegistro, ascending: true)])
    private var perfiles: FetchedResults<PerfilEstudiante>

    @State private var editandoPerfil = false
    @State private var confirmarBorrado = false
    @State private var archivoCSV: URL?
    @State private var diasGuardados = 0

    @AppStorage("apariencia") private var apariencia: Apariencia = .sistema
    @AppStorage("recordatorioActivo") private var recordatorioActivo = false
    /// Hora del recordatorio en minutos desde la medianoche (21:00 por defecto).
    @AppStorage("recordatorioMinutos") private var recordatorioMinutos = 21 * 60
    @State private var avisoRecordatorio: String?

    private var horaRecordatorio: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: recordatorioMinutos / 60,
                                  minute: recordatorioMinutos % 60, second: 0, of: Date()) ?? Date()
        } set: { nueva in
            let partes = Calendar.current.dateComponents([.hour, .minute], from: nueva)
            recordatorioMinutos = (partes.hour ?? 21) * 60 + (partes.minute ?? 0)
            Task { await aplicarRecordatorio() }
        }
    }

    private let tiposEscritura: [(String, HKSampleType)] = [
        ("Pasos", HKQuantityType(.stepCount) as HKSampleType),
        ("Distancia", HKQuantityType(.distanceWalkingRunning) as HKSampleType),
        ("Sueño", HKCategoryType(.sleepAnalysis) as HKSampleType)
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let perfil = perfiles.first {
                    Section("Perfil") {
                        LabeledContent("Nombre", value: perfil.nombre ?? "—")
                        LabeledContent("Carrera", value: perfil.carrera ?? "—")
                        Button("Editar perfil") { editandoPerfil = true }
                    }
                }

                Section {
                    ForEach(tiposEscritura, id: \.0) { nombre, tipo in
                        let estado = vm.estadoEscritura(tipo)
                        LabeledContent(nombre) {
                            Text(estado)
                                .foregroundColor(estado == "Autorizado" ? .green : .secondary)
                        }
                    }
                    Button {
                        Task { await vm.solicitarPermisos() }
                    } label: {
                        Label("Solicitar permisos de Salud", systemImage: "heart.text.square")
                    }
                    Button {
                        Task { await vm.sincronizar(manual: true) }
                    } label: {
                        Label("Sincronizar ahora", systemImage: "arrow.clockwise")
                    }
                    if let fecha = vm.ultimaSincronizacion {
                        LabeledContent("Última sincronización",
                                       value: fecha.formatted(date: .omitted, time: .shortened))
                    }
                } header: {
                    Text("Permisos de HealthKit")
                } footer: {
                    Text("Por privacidad, iOS solo informa a la app el estado de los permisos de escritura; el de lectura nunca se revela. Puedes cambiarlos en Salud › Perfil › Apps › UniPulse.")
                }

                Section {
                    Button {
                        Task { await vm.generarDatosDePrueba() }
                    } label: {
                        Label("Generar \(Sincronizacion.dias) días de datos", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) {
                        confirmarBorrado = true
                    } label: {
                        Label("Borrar datos de prueba", systemImage: "trash")
                    }
                } header: {
                    Text("Datos de prueba (demo)")
                } footer: {
                    Text("Escribe pasos, distancia y sueño en Salud y crea registros de ánimo coherentes con el sueño. Los minutos activos se guardan en Core Data porque HealthKit no permite escribirlos. Al generar de nuevo, primero se borran los datos de prueba anteriores.")
                }
                .disabled(vm.trabajando)

                Section {
                    Picker("Apariencia", selection: $apariencia) {
                        ForEach(Apariencia.allCases) { opcion in
                            Text(opcion.titulo).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Apariencia")
                } footer: {
                    Text("«Sistema» sigue el modo claro u oscuro configurado en el iPhone.")
                }

                Section {
                    Toggle(isOn: $recordatorioActivo) {
                        Label("Recordatorio diario", systemImage: "bell.badge")
                    }
                    if recordatorioActivo {
                        DatePicker("Hora", selection: horaRecordatorio, displayedComponents: .hourAndMinute)
                        Button {
                            Task { await RecordatorioManager.shared.probar() }
                        } label: {
                            Label("Probar notificación (en 5 s)", systemImage: "paperplane")
                        }
                    }
                    if let avisoRecordatorio {
                        Text(avisoRecordatorio)
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Recordatorio")
                } footer: {
                    Text("Cada día a esa hora UniPulse te recuerda registrar tu ánimo y tu estrés.")
                }

                Section {
                    LabeledContent("Días guardados", value: "\(diasGuardados)")
                    if let archivoCSV {
                        ShareLink(item: archivoCSV,
                                  preview: SharePreview("Historial de UniPulse (CSV)")) {
                            Label("Exportar historial (CSV)", systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Tus datos")
                } footer: {
                    Text("Exporta el historial guardado en Core Data a un archivo CSV que se abre en Excel o Numbers: fecha, pasos, distancia, sueño, minutos activos, ánimo, estrés y nota.")
                }

                if vm.trabajando || vm.mensaje != nil {
                    Section("Estado") {
                        if vm.trabajando {
                            ProgressView("Trabajando…")
                        }
                        if let mensaje = vm.mensaje {
                            Text(mensaje)
                        }
                    }
                }

                Section {
                    LabeledContent("Versión", value: "1.0")
                    LabeledContent("Almacenamiento", value: "Core Data (local)")
                    LabeledContent("Framework", value: "HealthKit")
                }
            }
            .navigationTitle("Ajustes")
            .confirmationDialog("¿Borrar los datos de prueba?", isPresented: $confirmarBorrado,
                                titleVisibility: .visible) {
                Button("Borrar datos de prueba", role: .destructive) {
                    Task { await vm.borrarDatosDePrueba() }
                }
            } message: {
                Text("Se eliminarán de Salud las muestras que escribió UniPulse y los registros de ánimo de prueba. Tus metas y tus propios registros se conservan.")
            }
            .onAppear(perform: actualizarExportacion)
            .onChange(of: vm.ultimaSincronizacion) { _ in actualizarExportacion() }
            .onChange(of: recordatorioActivo) { _ in
                Task { await aplicarRecordatorio() }
            }
            .sheet(isPresented: $editandoPerfil) {
                if let perfil = perfiles.first {
                    EditarPerfilView(perfil: perfil)
                        .environmentObject(vm)
                }
            }
        }
    }
}

extension AjustesView {
    private func actualizarExportacion() {
        diasGuardados = vm.cantidadDeDias()
        archivoCSV = vm.exportarCSV()
    }

    @MainActor
    private func aplicarRecordatorio() async {
        guard recordatorioActivo else {
            RecordatorioManager.shared.cancelar()
            return
        }
        let programado = await RecordatorioManager.shared.programar(hora: recordatorioMinutos / 60,
                                                                  minuto: recordatorioMinutos % 60)
        if !programado {
            recordatorioActivo = false
            avisoRecordatorio = "Activa las notificaciones de UniPulse en Ajustes del iPhone para usar el recordatorio."
        } else {
            avisoRecordatorio = nil
        }
    }
}

struct EditarPerfilView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    let perfil: PerfilEstudiante

    @State private var nombre = ""
    @State private var carrera = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $nombre)
                TextField("Carrera", text: $carrera)
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        vm.actualizarPerfil(perfil,
                                            nombre: nombre.trimmingCharacters(in: .whitespaces),
                                            carrera: carrera.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                nombre = perfil.nombre ?? ""
                carrera = perfil.carrera ?? ""
            }
        }
    }
}

struct AjustesView_Previews: PreviewProvider {
    static var previews: some View {
        AjustesView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
