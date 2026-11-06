//
//  RecordatorioManager.swift
//  UniPulse
//
//  Notificación local diaria para recordar registrar el ánimo.
//

import UserNotifications

final class RecordatorioManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RecordatorioManager()

    private let centro = UNUserNotificationCenter.current()
    private let identificador = "unipulse.recordatorio.diario"

    /// Se llama al iniciar la app para poder mostrar la notificación aunque la app esté abierta.
    func configurar() {
        centro.delegate = self
    }

    func solicitarPermiso() async -> Bool {
        (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Programa (o reprograma) el recordatorio todos los días a la hora indicada.
    func programar(hora: Int, minuto: Int) async -> Bool {
        guard await solicitarPermiso() else { return false }
        centro.removePendingNotificationRequests(withIdentifiers: [identificador])

        var componentes = DateComponents()
        componentes.hour = hora
        componentes.minute = minuto
        let disparador = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: true)
        let solicitud = UNNotificationRequest(identifier: identificador,
                                              content: contenido(),
                                              trigger: disparador)
        do {
            try await centro.add(solicitud)
            return true
        } catch {
            print("No se pudo programar el recordatorio: \(error)")
            return false
        }
    }

    func cancelar() {
        centro.removePendingNotificationRequests(withIdentifiers: [identificador])
    }

    /// Envía el recordatorio en 5 segundos, para probarlo en la demostración.
    func probar() async {
        guard await solicitarPermiso() else { return }
        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let solicitud = UNNotificationRequest(identifier: "unipulse.recordatorio.prueba",
                                              content: contenido(),
                                              trigger: disparador)
        try? await centro.add(solicitud)
    }

    private func contenido() -> UNMutableNotificationContent {
        let contenido = UNMutableNotificationContent()
        contenido.title = "¿Cómo estuvo tu día?"
        contenido.body = "Registra tu ánimo y tu nivel de estrés en UniPulse. Solo toma 10 segundos."
        contenido.sound = .default
        return contenido
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Muestra el aviso como banner también cuando la app está abierta.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
