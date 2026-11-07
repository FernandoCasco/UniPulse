//
//  NuevoRegistroView.swift
//  UniPulse
//
//  Formulario de ánimo y estrés del día (entidad RegistroAnimo).
//

import SwiftUI
import CoreData

struct NuevoRegistroView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.managedObjectContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let fecha: Date

    @State private var nivelAnimo = 3
    @State private var nivelEstres = 3
    @State private var nota = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EscalaSelector(valor: $nivelAnimo, escala: .animo, color: Tema.animo)
                        .padding(.vertical, 6)
                } header: {
                    Text("¿Cómo te sientes?")
                }

                Section {
                    EscalaSelector(valor: $nivelEstres, escala: .estres, color: Tema.activos)
                        .padding(.vertical, 6)
                } header: {
                    Text("¿Qué tanto estrés tienes?")
                } footer: {
                    Text("Se guarda en Core Data junto con los datos de salud de este día.")
                }

                Section("Nota (opcional)") {
                    TextField("Ej.: semana de parciales, dormí poco", text: $nota, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(Formato.diaLargo(fecha))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        vm.guardarAnimo(fecha: fecha, nivelAnimo: nivelAnimo,
                                        nivelEstres: nivelEstres, nota: nota)
                        Haptico.exito()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: cargarRegistro)
        }
    }

    /// Si ya existe un registro para ese día, se cargan sus valores para editarlo.
    private func cargarRegistro() {
        let dia = Calendar.current.startOfDay(for: fecha)
        let solicitud: NSFetchRequest<RegistroAnimo> = RegistroAnimo.fetchRequest()
        solicitud.predicate = NSPredicate(format: "fecha == %@", dia as NSDate)
        solicitud.fetchLimit = 1
        guard let registro = (try? contexto.fetch(solicitud))?.first else { return }
        nivelAnimo = Int(registro.nivelAnimo)
        nivelEstres = Int(registro.nivelEstres)
        nota = registro.nota ?? ""
    }
}

struct NuevoRegistroView_Previews: PreviewProvider {
    static var previews: some View {
        NuevoRegistroView(fecha: Date())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
