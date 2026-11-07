//
//  ContentView.swift
//  UniPulse
//
//  Decide qué mostrar: bienvenida (primer uso), permisos o la app principal.
//

import SwiftUI

struct ContentView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PerfilEstudiante.fechaRegistro, ascending: true)])
    private var perfiles: FetchedResults<PerfilEstudiante>

    @AppStorage("permisosSolicitados") private var permisosSolicitados = false
    @AppStorage("apariencia") private var apariencia: Apariencia = .sistema

    var body: some View {
        Group {
            if perfiles.isEmpty {
                BienvenidaView()
            } else if !permisosSolicitados {
                PermisosView()
            } else {
                PrincipalView()
            }
        }
        .animation(.default, value: perfiles.isEmpty)
        .animation(.default, value: permisosSolicitados)
        .preferredColorScheme(apariencia.esquema)
    }
}

/// Barra de pestañas con las cinco secciones de la app.
struct PrincipalView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.scenePhase) private var fase

    var body: some View {
        TabView {
            InicioView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }
            GraficasView()
                .tabItem { Label("Gráficas", systemImage: "chart.bar.fill") }
            MetasView()
                .tabItem { Label("Metas", systemImage: "target") }
            HistorialView()
                .tabItem { Label("Historial", systemImage: "calendar") }
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .tint(Tema.vino)
        .task { await vm.iniciar() }
        // Al volver a la app desde otra (por ejemplo, Salud) se vuelve a sincronizar.
        .onChange(of: fase) { nueva in
            if nueva == .active {
                Task { await vm.sincronizar() }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
