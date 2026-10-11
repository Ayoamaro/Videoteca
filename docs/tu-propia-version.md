# Tu propia versión de Videoteca

Para usar Videoteca **no hace falta nada de esto**: basta con los instaladores de la [última versión](https://github.com/Ayoamaro/Videoteca/releases/latest) y la [guía de uso](guia.md). Esta página es para quien quiera compilar la app, cambiarla o publicar sus propios instaladores.

## 1. Qué necesitas

- **Windows 10 u 11** de 64 bits.
- [**Flutter**](https://docs.flutter.dev/get-started/install/windows) (canal estable; la versión exacta que se usa está en `FLUTTER_VERSION` de [`.github/workflows/publicar.yml`](../.github/workflows/publicar.yml)).
- **Visual Studio 2022** (Community vale) con la carga de trabajo *Desarrollo para el escritorio con C++*.
- Para Android: **Android Studio** con el SDK (trae el JDK 17 en `jbr`).
- **Git**.

No hace falta el *Modo de desarrollador* de Windows: la app no usa plugins de Flutter. Lo propio de Windows (datos de los `.mp4`, diálogos de abrir y guardar, abrir enlaces) va por FFI, el arrastre de archivos por C++ (`windows/runner/receptor_arrastre.cpp`) y lo de Android por un canal en Kotlin (`MainActivity.kt`).

## 2. Compilar y probar

```bash
git clone https://github.com/Ayoamaro/Videoteca.git
cd Videoteca
flutter pub get
flutter test
flutter run -d windows
```

Versiones de prueba como las publicadas:

```bash
flutter build windows --release --dart-define=TABLON=usuario/Videoteca_Tablon
```

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=TABLON=usuario/Videoteca_Tablon
```

- `TABLON` es el tablón que se propone en la pantalla de entrada del modo consulta (se puede cambiar al entrar). `REPO_APP` (`usuario/Videoteca`) es dónde mira la app si hay versiones nuevas; sin él no se comprueba nada.
- Sin llave de firma, la APK se firma con la de depuración (vale para probar).
- La app guarda sus datos en `%LOCALAPPDATA%\Videoteca`. Para probar sin tocar los tuyos, abre el `.exe` con `LOCALAPPDATA` apuntando a otra carpeta.
- Para ver la versión del móvil en el PC: compilación de depuración con la variable de entorno `VIDEOTECA_MOVIL=1`.
- La base de datos (SQLite con [Drift](https://drift.simonbinder.eu/)) está en `lib/datos/base_datos.dart`. Si cambias sus tablas: `dart run build_runner build`.
- En `tool/` hay herramientas de línea de órdenes para probar cada pieza con tu disco: `probar_lectura.dart`, `escanear.dart`, `probar_busqueda.dart`, `probar_escritura.dart` (con **copias**), `probar_fuentes.dart`, `probar_filmaffinity.dart`, `leer_tablon.dart`, `probar_consulta.dart`… Cada una explica al principio cómo se usa.

## 3. Publicar tus instaladores con GitHub Actions

Cada vez que subes una etiqueta `v…`, [`publicar.yml`](../.github/workflows/publicar.yml) compila el instalador de Windows y la APK, **prueba el instalador** (lo instala, abre la app, comprueba que no se abre dos veces y lo desinstala) y lo publica todo en *Releases*, con las huellas SHA-256.

### Una sola vez

1. **Tu repositorio**: haz un *fork* (o sube el código a un repositorio tuyo). Para que otras personas descarguen los instaladores y la app avise de versiones nuevas, tiene que ser **público**.
2. **Tablón propuesto**: la app propone `<tu repositorio>_Tablon` (por ejemplo, `ana/Videoteca` → `ana/Videoteca_Tablon`). Si el tuyo se llama de otra forma, crea la variable **`TABLON`** en *Settings → Secrets and variables → Actions → Variables*.
3. **Llave de firma de Android.** Android solo instala una versión encima de otra si las dos llevan la misma firma, así que se crea una vez y se usa siempre. Con el `keytool` del JDK de Android Studio:

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore videoteca.jks -alias videoteca -keyalg RSA -keysize 4096 -validity 36500
   ```

   Usa el alias `videoteca` y la misma contraseña para el almacén y para la llave. **Guarda una copia del `.jks` y de la contraseña fuera del repositorio**: sin ellos, los móviles no aceptarán tus actualizaciones.

   Después, en *Settings → Secrets and variables → Actions → Secrets*, crea:
   - **`ANDROID_LLAVE_BASE64`**: el `.jks` en base64. En PowerShell, esto lo copia al portapapeles:
     ```powershell
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("videoteca.jks")) | Set-Clipboard
     ```
   - **`ANDROID_LLAVE_CLAVE`**: su contraseña.

   Para firmar también en tu PC, crea `android/key.properties` (no se sube: está en `.gitignore`):

   ```properties
   storeFile=C:/ruta/a/videoteca.jks
   storePassword=tu-contraseña
   keyAlias=videoteca
   keyPassword=tu-contraseña
   ```

4. **Nombre del paquete de Android**: si vas a repartir tu propia APK, cambia `applicationId` en `android/app/build.gradle.kts` (por ejemplo, `io.github.ana.videoteca`). Si no, tu app y la original chocarían en los móviles.

### Cada versión

1. Sube el número en `pubspec.yaml`: `version: 1.1.0+6`. El número de después del `+` tiene que ser **mayor que el de la versión anterior** (Android lo exige para actualizar).
2. Escribe las novedades en `docs/novedades/v1.1.md` (es el texto que verá la gente al actualizar).
3. Haz commit y sube la etiqueta:

   ```bash
   git tag v1.1
   ```

   ```bash
   git push origin v1.1
   ```

El flujo comprueba que la etiqueta coincide con la versión de `pubspec.yaml` y que existen las notas. Para probarlo todo sin publicar nada: *Actions → Publicar versión → Run workflow* (los archivos quedan en la ejecución, en *Artifacts*).

## 4. Google Play y el registro de desarrolladores de Android

La APK no está en Google Play: cuesta 25 $, pide verificar la identidad, las cuentas personales nuevas tienen que hacer antes una prueba cerrada con al menos 12 personas durante 14 días, y los revisores de Google necesitarían entrar con la contraseña común.

Ojo con un cambio que viene: Google [exigirá desde 2027](https://developer.android.com/developer-verification/guides/faq) que las apps instaladas en móviles Android certificados sean de un **desarrollador registrado**, también las que se instalan desde fuera de Google Play. Para repartir una app entre familia y amigos hay una cuenta gratuita de **distribución limitada** (hasta 20 móviles, sin verificar la identidad) en la *Android Developer Console*, donde se registra el nombre del paquete con su llave de firma. Hasta entonces, la APK se instala como siempre.

## 5. El instalador de Windows

`windows/instalador/videoteca.iss` es el script de [Inno Setup 6](https://jrsoftware.org/isinfo.php): instalación por usuario (sin administrador) en `%LOCALAPPDATA%\Programs\Videoteca`, actualización encima (cierra la app y la vuelve a abrir), y al desinstalar pregunta si se borran los datos. GitHub Actions lo compila solo; a mano, con Inno Setup instalado y después de `flutter build windows --release`:

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DVersion=1.1.0 /DRepo=usuario/Videoteca windows\instalador\videoteca.iss
```

Las imágenes del asistente (y el icono de la app) se generan con `dart run tool/generar_iconos.dart`.

El instalador no está firmado, por eso Windows avisa de «editor desconocido». Quitar ese aviso exige un certificado de firma de código, que es de pago.

## 6. Cómo está hecha

| Carpeta | Qué hay |
|---|---|
| `lib/pantallas/` | Las pantallas (Inicio, Catálogo, Ficha, Editar ficha, Nuevas, Completar mi colección, Ajustes…). |
| `lib/widgets/` | Piezas reutilizables (carátula, buscador, diálogos). |
| `lib/datos/` | Estado de la app (Riverpod), base de datos, buscador, filtros, estadísticas, lote, publicación. |
| `lib/disco/` | Leer y escribir los `.mp4` (cajas `moov › udta`), escáner, vigilancia de carpetas, FFI de Windows. |
| `lib/fuentes/` | TMDB, OMDb, Wikidata, FilmAffinity (con Edge) e identificación segura. |
| `lib/tablon/` | Cifrado (Argon2id + AES-256-GCM), formato del tablón, API de GitHub y copia local del modo consulta. |
| `windows/runner/` | La parte en C++ de Windows (ventana, arrastre de archivos, una sola instancia). |
| `android/` | La app de Android (canal `videoteca/sistema`, firma). |
| `test/` | Pruebas automáticas (`flutter test`). |

Las notas técnicas más detalladas (decisiones, formatos, trucos) están en [`CLAUDE.md`](../CLAUDE.md), y la historia del proyecto, día a día, en [`PLANNING.md`](../PLANNING.md).
