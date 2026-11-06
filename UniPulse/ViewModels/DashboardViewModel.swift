//
//  DashboardViewModel.swift
//  UniPulse
//
//  Coordina HealthKit y Core Data: pide permisos, sincroniza y genera datos de prueba.
//

import Foundation
import HealthKit

final class DashboardViewModel: ObservableObject {
    @Published var trabajando = false
    @Published var mensaje: String?
    @Published var ultimaSincronizacion: Date?

    private let hk = HealthKitManager()
    private let persistencia: PersistenceController

    init(persistencia: PersistenceController = .shared) {
        self.persistencia = persistencia
    }

    /// Se llama al abrir la app: pide permisos (solo la primera vez aparece la hoja) y sincroniza.
    @MainActor
    func iniciar() async {
        if await solicitarPermisos() {
            await sincronizar()
        }
    }

    @MainActor
    @discardableResult
    func solicitarPermisos() async -> Bool {
        do {
            try await hk.solicitarPermisos()
            mensaje = nil
            return true
        } catch {
            mensaje = "No se pudo pedir acceso a Salud: \(error.localizedDescription)"
            print("HealthKit – error de permisos: \(error)")
            return false
        }
    }

    /// `manual` = el usuario tocó "Sincronizar ahora" y espera una confirmación.
    @MainActor
    func sincronizar(manual: Bool = false) async {
        guard HealthKitManager.disponible else {
            mensaje = "HealthKit no está disponible en este dispositivo."
            return
        }
        trabajando = true
        defer { trabajando = false }
        do {
            try await leerYGuardarSemana()
            ultimaSincronizacion = Date()
            mensaje = manual ? "Datos sincronizados con Salud." : nil
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            mensaje = "Aún no has autorizado el acceso a Salud. Ve a Ajustes › Solicitar permisos."
        } catch {
            mensaje = "Error al sincronizar: \(error.localizedDescription)"
        }
    }

    @MainActor
    func generarDatosDePrueba() async {
        trabajando = true
        defer { trabajando = false }
        do {
            try await hk.solicitarPermisos()
            // Primero se borran los datos de prueba anteriores para no duplicarlos.
            try await hk.borrarDatosDePrueba()
            persistencia.limpiarDatosDePrueba()
            let minutos = try await hk.generarDatosDePrueba()
            for (dia, valor) in minutos {
                persistencia.guardarMinutosDePrueba(fecha: dia, minutos: valor)
            }
            try await leerYGuardarSemana()
            persistencia.generarAnimosDePrueba()
            ultimaSincronizacion = Date()
            mensaje = "Se generaron \(Sincronizacion.dias) días de datos de prueba."
        } catch {
            mensaje = "No se pudieron generar los datos: \(error.localizedDescription)"
        }
    }

    @MainActor
    func borrarDatosDePrueba() async {
        trabajando = true
        defer { trabajando = false }
        do {
            try await hk.borrarDatosDePrueba()
            persistencia.limpiarDatosDePrueba()
            try await leerYGuardarSemana()
            ultimaSincronizacion = Date()
            mensaje = "Se borraron los datos de prueba."
        } catch {
            mensaje = "No se pudieron borrar los datos: \(error.localizedDescription)"
        }
    }

    func estadoEscritura(_ tipo: HKSampleType) -> String {
        switch hk.estadoEscritura(tipo) {
        case .sharingAuthorized: return "Autorizado"
        case .sharingDenied: return "Denegado"
        default: return "Sin solicitar"
        }
    }

    // MARK: - Perfil, metas y ánimo (Core Data)

    func crearPerfil(nombre: String, carrera: String) {
        persistencia.crearPerfil(nombre: nombre, carrera: carrera)
    }

    func actualizarPerfil(_ perfil: PerfilEstudiante, nombre: String, carrera: String) {
        persistencia.actualizarPerfil(perfil, nombre: nombre, carrera: carrera)
    }

    func actualizarMeta(_ meta: Meta, valor: Double, activa: Bool) {
        persistencia.actualizarMeta(meta, valor: valor, activa: activa)
    }

    func guardarAnimo(fecha: Date, nivelAnimo: Int, nivelEstres: Int, nota: String) {
        persistencia.guardarAnimo(fecha: fecha, nivelAnimo: nivelAnimo,
                                  nivelEstres: nivelEstres, nota: nota)
    }

    func eliminarAnimo(_ registro: RegistroAnimo) {
        persistencia.eliminarAnimo(registro)
    }

    func exportarCSV() -> URL? {
        persistencia.exportarCSV()
    }

    func cantidadDeDias() -> Int {
        persistencia.cantidadDeDias()
    }

    /// Lee los últimos 30 días de HealthKit y actualiza un ResumenDiario por fecha.
    @MainActor
    private func leerYGuardarSemana() async throws {
        let dias = Sincronizacion.dias
        let pasos = try await hk.totalesDiarios(.stepCount, unidad: .count(), dias: dias)
        let distancia = try await hk.totalesDiarios(.distanceWalkingRunning,
                                                    unidad: .meterUnit(with: .kilo), dias: dias)
        let minutos = try await hk.totalesDiarios(.appleExerciseTime, unidad: .minute(), dias: dias)
        let sueno = try await hk.horasDeSueno(dias: dias)

        let calendario = Calendar.current
        for d in 0..<dias {
            let dia = calendario.date(byAdding: .day, value: -d,
                                      to: calendario.startOfDay(for: Date()))!
            persistencia.guardarResumen(fecha: dia,
                                        pasos: pasos[dia] ?? 0,
                                        distanciaKm: distancia[dia] ?? 0,
                                        horasSueno: sueno[dia] ?? 0,
                                        minutosActivos: minutos[dia] ?? 0)
        }
    }
}
