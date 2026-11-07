//
//  UniPulseApp.swift
//  UniPulse
//
//  Punto de entrada de la aplicación.
//

import SwiftUI

@main
struct UniPulseApp: App {
    let persistencia = PersistenceController.shared
    @StateObject private var dashboard = DashboardViewModel()

    init() {
        RecordatorioManager.shared.configurar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistencia.container.viewContext)
                .environmentObject(dashboard)
        }
    }
}
