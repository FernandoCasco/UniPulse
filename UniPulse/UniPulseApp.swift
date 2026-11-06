//
//  UniPulseApp.swift
//  UniPulse
//
//  Created by Fernando Perez on 5/11/26.
//

import SwiftUI

@main
struct UniPulseApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
