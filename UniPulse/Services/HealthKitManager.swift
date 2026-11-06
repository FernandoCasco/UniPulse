//
//  HealthKitManager.swift
//  UniPulse
//
//  Encapsula todo el acceso a HealthKit: permisos, consultas y datos de prueba.
//

import HealthKit

final class HealthKitManager {
    let store = HKHealthStore()

    static var disponible: Bool { HKHealthStore.isHealthDataAvailable() }

    private let tiposLectura: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.appleExerciseTime),
        HKCategoryType(.sleepAnalysis)
    ]

    // appleExerciseTime es de solo lectura: no se incluye en escritura.
    private let tiposEscritura: Set<HKSampleType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKCategoryType(.sleepAnalysis)
    ]

    // MARK: - Permisos

    func solicitarPermisos() async throws {
        guard Self.disponible else {
            throw HKError(.errorHealthDataUnavailable)
        }
        try await store.requestAuthorization(toShare: tiposEscritura, read: tiposLectura)
    }

    /// HealthKit solo informa el estado de los permisos de escritura.
    /// El de lectura se oculta por privacidad: si se niega, las consultas simplemente devuelven 0.
    func estadoEscritura(_ tipo: HKSampleType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: tipo)
    }

    // MARK: - Consultas

    /// Suma las muestras de cada día de los últimos `dias` días.
    /// La clave del diccionario es el inicio de cada día.
    func totalesDiarios(_ id: HKQuantityTypeIdentifier, unidad: HKUnit,
                        dias: Int = 7) async throws -> [Date: Double] {
        let calendario = Calendar.current
        let fin = Date()
        let inicio = calendario.date(byAdding: .day, value: -(dias - 1),
                                     to: calendario.startOfDay(for: fin))!
        let rango = HKQuery.predicateForSamples(withStart: inicio, end: fin)
        let consulta = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: rango),
            options: .cumulativeSum,
            anchorDate: inicio,
            intervalComponents: DateComponents(day: 1))

        let coleccion = try await consulta.result(for: store)
        var totales: [Date: Double] = [:]
        coleccion.enumerateStatistics(from: inicio, to: fin) { estadistica, _ in
            totales[estadistica.startDate] =
                estadistica.sumQuantity()?.doubleValue(for: unidad) ?? 0
        }
        return totales
    }

    /// Horas dormidas por día. El sueño se asigna al día en que termina (la mañana).
    func horasDeSueno(dias: Int = 7) async throws -> [Date: Double] {
        let calendario = Calendar.current
        // Se empieza un día antes para incluir la noche previa al primer día.
        let inicio = calendario.date(byAdding: .day, value: -dias,
                                     to: calendario.startOfDay(for: Date()))!
        let consulta = HKSampleQueryDescriptor(
            predicates: [.categorySample(
                type: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: inicio, end: Date()))],
            sortDescriptors: [SortDescriptor(\.startDate)])

        let muestras = try await consulta.result(for: store)
        let dormido = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        var horas: [Date: Double] = [:]
        for muestra in muestras where dormido.contains(muestra.value) {
            let dia = calendario.startOfDay(for: muestra.endDate)
            horas[dia, default: 0] += muestra.endDate.timeIntervalSince(muestra.startDate) / 3600
        }
        return horas
    }

    // MARK: - Datos de prueba

    /// Escribe 7 días de pasos, distancia y sueño en HealthKit.
    /// Devuelve minutos activos simulados por día, que se guardan en Core Data.
    func generarDatosDePrueba(dias: Int = Sincronizacion.dias) async throws -> [Date: Double] {
        let calendario = Calendar.current
        var muestras: [HKObject] = []
        var minutos: [Date: Double] = [:]

        for d in 0..<dias {
            let dia = calendario.date(byAdding: .day, value: -d,
                                      to: calendario.startOfDay(for: Date()))!
            // El sueño se decide primero: los días que se duerme poco se camina menos
            // y hay menos minutos activos, como suele pasar en semanas de parciales.
            let horas = Double.random(in: 5...8.5)
            let descansado = horas >= 7
            let inicio = d == 0 ? Date().addingTimeInterval(-3600)
                                : calendario.date(byAdding: .hour, value: 12, to: dia)!
            let fin = inicio.addingTimeInterval(1800)
            let pasos = (descansado ? Double.random(in: 7_000...12_000)
                                    : Double.random(in: 3_500...8_000)).rounded()

            muestras.append(HKQuantitySample(
                type: HKQuantityType(.stepCount),
                quantity: HKQuantity(unit: .count(), doubleValue: pasos),
                start: inicio, end: fin))

            let km = HKQuantity(unit: .meterUnit(with: .kilo),
                                doubleValue: pasos * 0.00075)
            muestras.append(HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning), quantity: km,
                start: inicio, end: fin))

            // Despertar a las 6:00; si aún no son las 6 de hoy, se usa la hora actual.
            let despertar = min(calendario.date(byAdding: .hour, value: 6, to: dia)!,
                                Date().addingTimeInterval(-60))
            muestras.append(HKCategorySample(
                type: HKCategoryType(.sleepAnalysis),
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: despertar.addingTimeInterval(-horas * 3600), end: despertar))

            minutos[dia] = (descansado ? Double.random(in: 25...55)
                                       : Double.random(in: 5...30)).rounded()
        }

        try await store.save(muestras)
        return minutos
    }

    /// Borra de HealthKit todas las muestras que escribió UniPulse (solo las de esta app).
    func borrarDatosDePrueba() async throws {
        let deEstaApp = HKQuery.predicateForObjects(from: HKSource.default())
        for tipo in tiposEscritura {
            try await withCheckedThrowingContinuation { (continuacion: CheckedContinuation<Void, Error>) in
                store.deleteObjects(of: tipo, predicate: deEstaApp) { _, _, error in
                    if let error {
                        continuacion.resume(throwing: error)
                    } else {
                        continuacion.resume()
                    }
                }
            }
        }
    }
}
