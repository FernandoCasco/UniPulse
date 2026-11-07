# UniPulse

Aplicación iOS de bienestar para estudiantes universitarios que usa el **Framework HealthKit** para leer pasos, distancia, sueño y minutos activos, y los guarda en **Core Data** como un historial propio con metas semanales y registro de ánimo.

Proyecto de la materia **ETPS4** – Universidad Tecnológica de El Salvador (Ciclo 02-2026).

## Funcionalidades

| Pantalla | Qué hace |
| --- | --- |
| Bienvenida | Registra el perfil del estudiante (nombre y carrera) |
| Permisos | Explica qué datos se leen y solicita autorización a HealthKit |
| Inicio | Anillos de progreso del día, tarjetas con detalle por dato, bienestar de la semana y perspectivas |
| Gráficas | Barras interactivas de los últimos 7 días con Swift Charts y línea de meta |
| Metas | Metas diarias editables y días cumplidos en la última semana |
| Historial | Días guardados en Core Data con su detalle completo |
| Nuevo registro | Ánimo y estrés con caritas (escala de 1 a 5) y nota opcional |
| Ajustes | Perfil, permisos, recordatorio diario, exportación a CSV y datos de prueba |

### Perspectivas

UniPulse cruza los datos guardados en Core Data para responder preguntas que la app Salud no responde:

- ¿Mi ánimo es mejor los días que duermo 7 horas o más?
- ¿Camino menos los días de estrés alto?
- ¿Cuántos días seguidos llevo cumpliendo mi meta de pasos?
- ¿Cuánto dormí en promedio esta semana frente a lo recomendado?

## Tecnologías

- Swift 5.7 y SwiftUI
- HealthKit (`HKHealthStore`, `HKStatisticsCollectionQueryDescriptor`, `HKSampleQueryDescriptor`)
- Core Data (almacenamiento local en SQLite)
- Swift Charts
- UserNotifications (recordatorio diario local)
- ShareLink (exportación del historial a CSV)
- Arquitectura MVVM

## Requisitos

- Xcode 14.2 o superior
- iOS 16.0 o superior (probado en el simulador iPhone 14 Pro, iOS 16.2)
- No requiere cuenta de desarrollador de pago para ejecutarse en el simulador

## Cómo ejecutar

1. Clonar el repositorio y abrir `UniPulse.xcodeproj`.
2. Elegir un simulador de iPhone y presionar **Cmd + R**.
3. Registrar el perfil y tocar **Permitir acceso** › **Activar todas** › **Permitir**.
4. Como el simulador no tiene sensores, ir a **Ajustes › Generar 30 días de datos** para cargar datos de prueba coherentes (los días con poco sueño tienen menos pasos y más estrés).

## Estructura

```
UniPulse/
├── UniPulseApp.swift          Punto de entrada
├── ContentView.swift          Flujo de primer uso y barra de pestañas
├── Models/                    Modelo de Core Data, PersistenceController, TipoDato y Perspectivas
├── Services/                  HealthKitManager (HealthKit) y RecordatorioManager (notificaciones)
├── ViewModels/                DashboardViewModel (coordina HealthKit y Core Data)
├── Views/                     Pantallas SwiftUI y componentes reutilizables
├── Info.plist                 Textos de permisos de Salud
└── UniPulse.entitlements      Capacidad HealthKit
```

## Modelo de datos (Core Data)

- **PerfilEstudiante**: nombre, carrera y fecha de registro; tiene muchas metas.
- **ResumenDiario**: un registro por día (fecha única) con pasos, distancia, sueño y minutos activos.
- **Meta**: tipo, valor objetivo y si está activa.
- **RegistroAnimo**: ánimo y estrés del día con nota opcional; pertenece a un ResumenDiario.

## Privacidad

Los datos de salud nunca salen del dispositivo. La app solo pide los cuatro tipos de datos que necesita, y funciona aunque el usuario niegue alguno de ellos.

Nota: HealthKit no permite que otras apps escriban minutos de ejercicio (`appleExerciseTime`). Por eso el generador de datos de prueba guarda esos minutos directamente en Core Data.

## Autor

Fernando Miguel Pérez Casco – Ingeniería en Sistemas y Computación, UTEC.
