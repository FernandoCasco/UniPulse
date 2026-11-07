//
//  InicioView.swift
//  UniPulse
//
//  Resumen del día leído desde Core Data, comparado con las metas del estudiante.
//

import SwiftUI

struct InicioView: View {
    @EnvironmentObject private var vm: DashboardViewModel

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ResumenDiario.fecha, ascending: false)],
                  animation: .default)
    private var resumenes: FetchedResults<ResumenDiario>

    /// Se observan los registros de ánimo directamente: así Inicio se actualiza al editarlos.
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \RegistroAnimo.fecha, ascending: false)],
                  animation: .default)
    private var registros: FetchedResults<RegistroAnimo>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Meta.tipo, ascending: true)])
    private var metas: FetchedResults<Meta>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PerfilEstudiante.fechaRegistro, ascending: true)])
    private var perfiles: FetchedResults<PerfilEstudiante>

    @State private var mostrarRegistro = false
    @State private var mostrarPerfil = false

    private var hoy: ResumenDiario? {
        resumenes.first { Calendar.current.isDateInToday($0.fecha ?? .distantPast) }
    }

    private var saludo: String {
        let nombre = perfiles.first?.nombre?.split(separator: " ").first.map(String.init)
        return nombre.map { "Hola, \($0)" } ?? "Hola"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Formato.diaLargo(Date()))
                        .foregroundColor(.secondary)

                    Text("Progreso de hoy")
                        .font(.title3.bold())
                        .padding(.top, 2)

                    tarjetaAnillos

                    Text("Detalle")
                        .font(.title3.bold())
                        .padding(.top, 6)

                    ForEach(TipoDato.allCases) { tipo in
                        NavigationLink {
                            DetalleMetricaView(tipo: tipo)
                        } label: {
                            tarjeta(tipo)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Bienestar")
                        .font(.title3.bold())
                        .padding(.top, 6)

                    tarjetaAnimo

                    Text("Perspectivas")
                        .font(.title3.bold())
                        .padding(.top, 6)

                    ForEach(perspectivas) { perspectiva in
                        TarjetaPerspectiva(perspectiva: perspectiva)
                    }

                    if let mensaje = vm.mensaje {
                        Text(mensaje)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(saludo)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.trabajando {
                        ProgressView()
                    } else {
                        Button {
                            mostrarPerfil = true
                        } label: {
                            Avatar(nombre: perfiles.first?.nombre)
                        }
                        .accessibilityLabel("Abrir perfil")
                    }
                }
            }
            .refreshable { await vm.sincronizar() }
            .sheet(isPresented: $mostrarPerfil) {
                PerfilView()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $mostrarRegistro) {
                NuevoRegistroView(fecha: Date())
                    .environmentObject(vm)
            }
        }
    }

    /// Avance de hoy hacia la meta (0 si la meta está desactivada).
    private func progreso(_ tipo: TipoDato) -> Double {
        guard let objetivo = Calculos.objetivo(tipo, metas: Array(metas)), objetivo > 0 else { return 0 }
        return (hoy.map { tipo.valor(de: $0) } ?? 0) / objetivo
    }

    private var tarjetaAnillos: some View {
        HStack(spacing: 20) {
            AnillosActividad(pasos: progreso(.pasos),
                             activos: progreso(.minutosActivos),
                             sueno: progreso(.sueno))
                .frame(width: 130, height: 130)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(TipoDato.allCases) { tipo in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tipo.titulo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(progreso(tipo).formatted(.percent.precision(.fractionLength(0))))
                            .font(.title3.bold())
                            .foregroundColor(tipo.color)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func tarjeta(_ tipo: TipoDato) -> some View {
        let valor = hoy.map { tipo.valor(de: $0) } ?? 0
        let objetivo = Calculos.objetivo(tipo, metas: Array(metas))
        var titulo = tipo.titulo
        if tipo == .pasos {
            titulo += " · \(Formato.decimal(hoy?.distanciaKm ?? 0)) km"
        }
        return TarjetaMetrica(titulo: titulo, icono: tipo.icono, color: tipo.color,
                              valor: tipo.formatear(valor), unidad: tipo.unidad,
                              meta: objetivo.map { tipo.textoMeta($0) },
                              progreso: objetivo.map { valor / $0 } ?? 0)
    }

    /// Los últimos 7 días (del más antiguo a hoy) con su registro de ánimo, si existe.
    /// Relaciones encontradas entre sueño, actividad, ánimo y estrés (Models/Perspectivas.swift).
    private var perspectivas: [Perspectiva] {
        Perspectivas.generar(resumenes: Array(resumenes),
                             metaPasos: Calculos.objetivo(.pasos, metas: Array(metas)))
    }

    private var animoHoy: RegistroAnimo? {
        registros.first { Calendar.current.isDateInToday($0.fecha ?? .distantPast) }
    }

    private var semanaAnimo: [(Date, RegistroAnimo?)] {
        let calendario = Calendar.current
        let hoyInicio = calendario.startOfDay(for: Date())
        return (0..<7).reversed().map { d in
            let dia = calendario.date(byAdding: .day, value: -d, to: hoyInicio)!
            return (dia, registros.first { $0.fecha == dia })
        }
    }

    private var tarjetaAnimo: some View {
        Button {
            mostrarRegistro = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    if let animo = animoHoy {
                        Text(animo.emojiAnimo)
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Te sientes \(animo.textoAnimo.lowercased())")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Estrés \(animo.textoEstres.lowercased())")
                                .font(.subheadline)
                                .foregroundColor(Tema.activos)
                            if let nota = animo.nota {
                                Text(nota)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Image(systemName: "face.smiling")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Tema.animo, in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¿Cómo te sientes hoy?")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Registra tu ánimo y nivel de estrés")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: animoHoy == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(Tema.animo)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu ánimo en los últimos 7 días")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        ForEach(semanaAnimo, id: \.0) { dia, animo in
                            VStack(spacing: 4) {
                                if let animo {
                                    Text(animo.emojiAnimo)
                                        .font(.title3)
                                } else {
                                    Circle()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(width: 24, height: 24)
                                        .frame(height: 28)
                                }
                                Text(Calendar.current.isDateInToday(dia)
                                     ? "Hoy" : dia.formatted(.dateTime.weekday(.narrow)))
                                    .font(.caption2.weight(Calendar.current.isDateInToday(dia) ? .bold : .regular))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct InicioView_Previews: PreviewProvider {
    static var previews: some View {
        InicioView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
