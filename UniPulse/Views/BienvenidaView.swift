//
//  BienvenidaView.swift
//  UniPulse
//
//  Pantallas de primer uso: registro del perfil y explicación de permisos.
//

import SwiftUI

struct BienvenidaView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @State private var nombre = ""
    @State private var carrera = ""

    private var nombreValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LogoUniPulse()
                    .padding(.top, 60)
                Text("UniPulse")
                    .font(.largeTitle.bold())
                Text("Equilibra tu actividad, tu descanso y tus estudios.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    TextField("Nombre", text: $nombre)
                        .textContentType(.name)
                    TextField("Carrera", text: $carrera)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 24)

                Button {
                    vm.crearPerfil(nombre: nombre.trimmingCharacters(in: .whitespaces),
                                   carrera: carrera.trimmingCharacters(in: .whitespaces))
                } label: {
                    Text("Continuar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tema.vino)
                .disabled(!nombreValido)
                .padding(.top, 8)

                Label("Tus datos se guardan solo en este iPhone.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct PermisosView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @AppStorage("permisosSolicitados") private var permisosSolicitados = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 50)
                Text("Conecta con Salud")
                    .font(.largeTitle.bold())
                Text("UniPulse necesita leer estos datos para mostrar tu resumen diario.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    filaPermiso(.pasos, detalle: "Pasos y distancia del día")
                    Divider().padding(.leading, 60)
                    filaPermiso(.sueno, detalle: "Horas dormidas")
                    Divider().padding(.leading, 60)
                    filaPermiso(.minutosActivos, detalle: "Minutos de ejercicio")
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14))

                Text("Puedes cambiar estos permisos en cualquier momento desde la app Salud. Los datos nunca salen de tu iPhone.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { @MainActor in
                        await vm.solicitarPermisos()
                        permisosSolicitados = true
                    }
                } label: {
                    Text("Permitir acceso")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Ahora no") {
                    permisosSolicitados = true
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func filaPermiso(_ tipo: TipoDato, detalle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tipo.icono)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(tipo.color, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading) {
                Text(tipo.titulo)
                Text(detalle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Leer")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
        }
        .padding(12)
    }
}

/// Logotipo: cuadro vino con una línea de pulso.
struct LogoUniPulse: View {
    var tamano: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: tamano * 0.25)
            .fill(Tema.vino)
            .frame(width: tamano, height: tamano)
            .overlay(
                Pulso()
                    .stroke(.white, style: StrokeStyle(lineWidth: tamano * 0.06,
                                                      lineCap: .round, lineJoin: .round))
                    .padding(tamano * 0.14)
            )
            .accessibilityHidden(true)
    }
}

private struct Pulso: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.85))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.58))
        p.addLine(to: CGPoint(x: w, y: h * 0.58))
        return p
    }
}

struct BienvenidaView_Previews: PreviewProvider {
    static var previews: some View {
        BienvenidaView()
            .environmentObject(DashboardViewModel(persistencia: .preview))
        PermisosView()
            .environmentObject(DashboardViewModel(persistencia: .preview))
    }
}
