# 🎬 Videoteca

Catálogo de películas para **Windows** (administración) y **Android** (consulta).

La app recorre una carpeta de películas `.mp4` organizadas por grupo y género, lee los datos que cada archivo lleva en sus propiedades de Windows (título, sinopsis, reparto, carátula…), permite buscarlas al instante y publica el catálogo cifrado para consultarlo desde el móvil.

> 🚧 En desarrollo. El plan completo está en [PLANNING.md](PLANNING.md).

## Instalar

Descarga `Videoteca-<versión>-instalador.exe` de la última versión en [Releases](https://github.com/Ayoamaro/Videoteca/releases) y ábrelo. Se instala solo para tu usuario (no pide permisos de administrador). Para actualizar, instala la versión nueva encima: el catálogo se conserva.

> Windows puede avisar de que el instalador es de un editor desconocido (no está firmado): pulsa *Más información → Ejecutar de todas formas*.

## Estructura de carpetas esperada

```
<Carpeta raíz>\<Grupo>\<Género>\Título (Año).mp4
```

La carpeta raíz se elige al abrir la app por primera vez; los géneros se detectan de las carpetas. También se aceptan archivos `.m4v` (el mismo formato que `.mp4`).

## Desarrollo

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install/windows) (canal estable), Visual Studio con "Desarrollo para el escritorio con C++" y, para Android, Android Studio con el SDK.

```bash
flutter pub get
flutter run -d windows
```

La base de datos (SQLite con [Drift](https://drift.simonbinder.eu/)) se describe en `lib/datos/base_datos.dart`. Si cambias sus tablas, vuelve a generar su código con:

```bash
dart run build_runner build
```

La app guarda su base de datos y las miniaturas de las carátulas en `%LOCALAPPDATA%\Videoteca`. Para probar el escaneo desde la terminal sin tocarlas:

```bash
dart run tool/escanear.dart D:\ C:\Temp\prueba-videoteca
```

Las claves de servicios externos (TMDB, OMDb, GitHub) **no** forman parte del repositorio: se guardan solo en el equipo de cada administrador.

## Licencia

[MIT](LICENSE)
