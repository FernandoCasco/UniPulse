//
//  PersistenceController.swift
//  UniPulse
//
//  Contenedor de Core Data y operaciones de guardado del historial.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Instancia en memoria con datos de ejemplo para las vistas previas de Xcode.
    static var preview: PersistenceController = {
        let controlador = PersistenceController(inMemory: true)
        controlador.crearPerfil(nombre: "Fernando Pérez", carrera: "Ing. en Sistemas y Computación")
        let calendario = Calendar.current
        for d in 0..<7 {
            let dia = calendario.date(byAdding: .day, value: -d, to: calendario.startOfDay(for: Date()))!
            controlador.guardarResumen(fecha: dia,
                                       pasos: Double.random(in: 4_000...12_000),
                                       distanciaKm: Double.random(in: 3...9),
                                       horasSueno: Double.random(in: 5...8.5),
                                       minutosActivos: Double.random(in: 10...50))
        }
        controlador.guardarAnimo(fecha: Date(), nivelAnimo: 4, nivelEstres: 3,
                                 nota: "Semana de parciales")
        return controlador
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "UniPulse")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Error al cargar Core Data: \(error)")
            }
        }
        // Si una fecha ya existe, se actualiza en lugar de duplicarse.
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var contexto: NSManagedObjectContext { container.viewContext }

    // MARK: - ResumenDiario

    /// Busca el resumen de un día (la fecha debe ser el inicio del día).
    func resumen(para fecha: Date) -> ResumenDiario? {
        let solicitud: NSFetchRequest<ResumenDiario> = ResumenDiario.fetchRequest()
        solicitud.predicate = NSPredicate(format: "fecha == %@", fecha as NSDate)
        solicitud.fetchLimit = 1
        return (try? contexto.fetch(solicitud))?.first
    }

    func resumenExistenteONuevo(para fecha: Date) -> ResumenDiario {
        if let existente = resumen(para: fecha) { return existente }
        let nuevo = ResumenDiario(context: contexto)
        nuevo.id = UUID()
        nuevo.fecha = fecha
        return nuevo
    }

    /// Guarda los totales leídos de HealthKit sin duplicar fechas.
    func guardarResumen(fecha: Date, pasos: Double, distanciaKm: Double,
                        horasSueno: Double, minutosActivos: Double) {
        let resumen = resumenExistenteONuevo(para: fecha)
        resumen.pasos = Int32(pasos)
        resumen.distanciaKm = distanciaKm
        resumen.horasSueno = horasSueno
        // Los minutos de prueba se guardan aquí directamente, así que no se reemplazan por 0.
        resumen.minutosActivos = max(resumen.minutosActivos, Int32(minutosActivos))
        if resumen.fuente == nil { resumen.fuente = Fuente.healthKit }
        resumen.fechaSincronizacion = Date()
        guardar()
    }

    /// appleExerciseTime es de solo lectura en HealthKit:
    /// los minutos activos de prueba se guardan directamente en Core Data.
    func guardarMinutosDePrueba(fecha: Date, minutos: Double) {
        let resumen = resumenExistenteONuevo(para: fecha)
        resumen.minutosActivos = Int32(minutos)
        resumen.fuente = Fuente.prueba
        guardar()
    }

    /// Quita la marca de prueba y los minutos simulados; la siguiente sincronización
    /// deja solo lo que realmente exista en HealthKit.
    func limpiarDatosDePrueba() {
        let solicitud: NSFetchRequest<ResumenDiario> = ResumenDiario.fetchRequest()
        solicitud.predicate = NSPredicate(format: "fuente == %@", Fuente.prueba)
        for resumen in (try? contexto.fetch(solicitud)) ?? [] {
            resumen.minutosActivos = 0
            resumen.fuente = Fuente.healthKit
        }
        let animos: NSFetchRequest<RegistroAnimo> = RegistroAnimo.fetchRequest()
        animos.predicate = NSPredicate(format: "nota == %@", Fuente.notaPrueba)
        for registro in (try? contexto.fetch(animos)) ?? [] {
            contexto.delete(registro)
        }
        guardar()
    }

    /// Crea registros de ánimo de prueba coherentes con el sueño de cada día
    /// (dormir poco → ánimo más bajo y más estrés). No toca los registros del estudiante.
    func generarAnimosDePrueba() {
        let solicitud: NSFetchRequest<ResumenDiario> = ResumenDiario.fetchRequest()
        solicitud.predicate = NSPredicate(format: "animo == nil AND horasSueno > 0")
        for resumen in (try? contexto.fetch(solicitud)) ?? [] {
            let sueno = resumen.horasSueno
            let animo = sueno >= 7.5 ? Int.random(in: 4...5) : sueno >= 6.5 ? Int.random(in: 3...4) : Int.random(in: 1...3)
            let estres = sueno >= 7.5 ? Int.random(in: 1...2) : sueno >= 6.5 ? Int.random(in: 2...3) : Int.random(in: 4...5)
            let registro = RegistroAnimo(context: contexto)
            registro.id = UUID()
            registro.fecha = resumen.fecha
            registro.nivelAnimo = Int16(animo)
            registro.nivelEstres = Int16(estres)
            registro.nota = Fuente.notaPrueba
            registro.resumen = resumen
        }
        guardar()
    }

    // MARK: - Exportación

    /// Escribe todo el historial en un archivo CSV temporal y devuelve su ubicación.
    func exportarCSV() -> URL? {
        let solicitud: NSFetchRequest<ResumenDiario> = ResumenDiario.fetchRequest()
        solicitud.sortDescriptors = [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: true)]
        let resumenes = (try? contexto.fetch(solicitud)) ?? []

        let formatoFecha = DateFormatter()
        formatoFecha.locale = Locale(identifier: "en_US_POSIX")
        formatoFecha.dateFormat = "yyyy-MM-dd"

        func campo(_ texto: String) -> String {
            "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        // El BOM inicial hace que Excel lea bien las tildes.
        var csv = "\u{FEFF}fecha,pasos,distancia_km,horas_sueno,minutos_activos,fuente,animo,estres,nota\n"
        for r in resumenes {
            let fila: [String] = [
                r.fecha.map { formatoFecha.string(from: $0) } ?? "",
                String(r.pasos),
                String(format: "%.2f", r.distanciaKm),
                String(format: "%.1f", r.horasSueno),
                String(r.minutosActivos),
                campo(r.fuente ?? ""),
                r.animo.map { String($0.nivelAnimo) } ?? "",
                r.animo.map { String($0.nivelEstres) } ?? "",
                campo(r.animo?.nota ?? "")
            ]
            csv += fila.joined(separator: ",") + "\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("UniPulse_historial.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("No se pudo exportar el CSV: \(error)")
            return nil
        }
    }

    func cantidadDeDias() -> Int {
        let solicitud: NSFetchRequest<ResumenDiario> = ResumenDiario.fetchRequest()
        return (try? contexto.count(for: solicitud)) ?? 0
    }

    // MARK: - Perfil y metas

    func perfil() -> PerfilEstudiante? {
        let solicitud: NSFetchRequest<PerfilEstudiante> = PerfilEstudiante.fetchRequest()
        solicitud.fetchLimit = 1
        return (try? contexto.fetch(solicitud))?.first
    }

    /// Crea el perfil del estudiante con una meta por defecto para cada tipo de dato.
    func crearPerfil(nombre: String, carrera: String) {
        let perfil = PerfilEstudiante(context: contexto)
        perfil.id = UUID()
        perfil.nombre = nombre
        perfil.carrera = carrera
        perfil.fechaRegistro = Date()

        let semana = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        for tipo in TipoDato.allCases {
            let meta = Meta(context: contexto)
            meta.id = UUID()
            meta.tipo = tipo.rawValue
            meta.valorObjetivo = tipo.metaPorDefecto
            meta.semanaInicio = semana
            meta.activa = true
            meta.perfil = perfil
        }
        guardar()
    }

    func actualizarPerfil(_ perfil: PerfilEstudiante, nombre: String, carrera: String) {
        perfil.nombre = nombre
        perfil.carrera = carrera
        guardar()
    }

    func actualizarMeta(_ meta: Meta, valor: Double, activa: Bool) {
        meta.valorObjetivo = valor
        meta.activa = activa
        meta.semanaInicio = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        guardar()
    }

    // MARK: - RegistroAnimo

    /// Crea o actualiza el registro de ánimo del día, enlazado a su ResumenDiario.
    func guardarAnimo(fecha: Date, nivelAnimo: Int, nivelEstres: Int, nota: String) {
        let dia = Calendar.current.startOfDay(for: fecha)
        let resumen = resumenExistenteONuevo(para: dia)
        let registro = resumen.animo ?? RegistroAnimo(context: contexto)
        if registro.id == nil { registro.id = UUID() }
        registro.fecha = dia
        registro.nivelAnimo = Int16(nivelAnimo)
        registro.nivelEstres = Int16(nivelEstres)
        let limpia = nota.trimmingCharacters(in: .whitespacesAndNewlines)
        registro.nota = limpia.isEmpty ? nil : limpia
        registro.resumen = resumen
        guardar()
    }

    func eliminarAnimo(_ registro: RegistroAnimo) {
        contexto.delete(registro)
        guardar()
    }

    func guardar() {
        guard contexto.hasChanges else { return }
        do {
            try contexto.save()
        } catch {
            print("Error al guardar en Core Data: \(error)")
        }
    }
}

enum Fuente {
    static let healthKit = "HealthKit"
    static let prueba = "Datos de prueba"
    /// Nota con la que se marcan los registros de ánimo generados para la demostración.
    static let notaPrueba = "Registro generado con datos de prueba"
}

enum Sincronizacion {
    /// Días que se leen de HealthKit y se guardan en Core Data en cada sincronización.
    static let dias = 30
}
