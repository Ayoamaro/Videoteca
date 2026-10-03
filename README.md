# 🎬 Videoteca

Catálogo de películas para **Windows** (administración) y **Android** (consulta).

La app recorre una carpeta de películas `.mp4` organizadas por grupo y género, lee los datos que cada archivo lleva en sus propiedades de Windows (título, sinopsis, reparto, carátula…), permite buscarlas al instante y publica el catálogo cifrado para consultarlo desde el móvil.

> 🚧 En desarrollo. El plan completo está en [PLANNING.md](PLANNING.md).

## Estructura de carpetas esperada

```
<Carpeta raíz>\<Grupo>\<Género>\Título (Año).mp4
```

La carpeta raíz se elige al abrir la app por primera vez; los géneros se detectan de las carpetas.

## Desarrollo

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install/windows) (canal estable), Visual Studio con "Desarrollo para el escritorio con C++" y, para Android, Android Studio con el SDK.

```bash
flutter pub get
flutter run -d windows
```

Las claves de servicios externos (TMDB, OMDb, GitHub) **no** forman parte del repositorio: se guardan solo en el equipo de cada administrador.

## Licencia

[MIT](LICENSE)
