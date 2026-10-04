# Videoteca — contexto del proyecto

App de catálogo de películas para **Windows (administrador) y Android (consulta)**. El usuario habla en **español**, no conoce Flutter y quiere entender cada paso con explicaciones sencillas. Claude hace todo el desarrollo.

## Cómo trabajamos
- El plan está en [PLANNING.md](PLANNING.md): 20 "días" = sesiones de trabajo. El usuario dice "vamos con el día X".
- **Al empezar una sesión:** leer `PLANNING.md` y ver qué días están marcados (☑) y el `git log`.
- **Al terminar cada día:** marcar el día como ☑ en `PLANNING.md`, hacer commit (mensajes en español) y push.
- Hasta el día 9 la app **solo lee** el disco. Cualquier escritura en `.mp4` se prueba antes con **copias**, nunca con los originales.
- Diseño aprobado: https://claude.ai/artifact/ExVasA5vV2r3fByTLLAxnW · prompt: `docs/prompt-claude-design.md`. Estilo: oscuro "sala de cine", acento dorado `#E2AE4F`, fondo `#0F0E13`, tipografías Bricolage Grotesque (títulos) + Manrope (texto).

## La colección del usuario (comprobado el 2026-10-03)
- Disco `D:\` (HDD de 16 TB) con **5.540 `.mp4` + 1 `.m4v`** (`Wonka (2023).m4v`; la app acepta ambas extensiones) en `D:\<Grupo>\<Género>\Título (Año).mp4` (7 grupos, 16 géneros; siempre 2 niveles). Usa `꞉` (U+A789) en lugar de `:` en los nombres. Hay 12 títulos duplicados en dos carpetas y 1 archivo fuera de formato (`…(1990)-1.mp4`).
- Cada `.mp4` lleva los datos en las propiedades de Windows (~99 % completos) y una **carátula incrustada** (átomo `covr`, 350×500, la pone el usuario a mano; la app **nunca** pone carátulas por su cuenta).
- **Escribir con `IPropertyStore` (Windows) NO sirve** (comprobado el día 9 con copias): textos de más de 255 caracteres no se guardan aunque `Commit` dice que sí (con el reparto largo, lo **borró**), y reescribe el archivo entero (~10 s en el HDD). Por eso la app escribe ella misma las cajas `moov › udta › meta › ilst` (estándar iTunes) y `moov › udta › Xtra` (Microsoft, textos UTF-16) con el mismo formato que Windows, y **Windows lo vuelve a leer** para comprobarlo. Las sinopsis largas existentes las puso otro programa; la de *El Caballero Oscuro 3* (cortada a media palabra) probablemente se editó en el Explorador.
- En tus archivos `moov` va al principio seguida de una caja `free` (3–60 KB): la `moov` nueva se escribe en su sitio (≈0,2 s, el vídeo no se mueve); si no cabe, va al final del archivo y la vieja pasa a `free`. Algunos archivos acaban en una caja `mdat` vacía de tamaño 0 (p. ej. *Superfrikis*).
- La app debe ser **genérica**: carpeta raíz configurable y géneros detectados de las carpetas, sin nada fijo a este disco.

## Asignación de campos (Windows → significado)
| Propiedad de Windows | Dato | Estado | Caja en el `.mp4` |
|---|---|---|---|
| System.Title | Título en España (el del nombre de archivo; no se sustituye) | existente | `©nam` |
| System.Media.SubTitle | Título original | existente | `WM/SubTitle` |
| System.Comment | Sinopsis (de FilmAffinity) | existente | `©cmt` |
| System.Music.Artist | Reparto | existente | `©ART` |
| System.Media.Year | Año | existente | `©day` (texto) |
| System.Music.Genre | Géneros, formato `Drama. Comedia. Romance` | existente | `©gen` |
| System.Rating | Estrellas = Rotten Tomatoes | existente | `WM/SharedUserRating` (8 bytes) |
| System.Video.Director | Dirección | existente | `WM/Director` |
| System.Media.Producer | Productora | existente | `WM/Producer` |
| System.Music.Composer | Música | existente | `©wrt` |
| System.ParentalRating | Frase de edad, ej. "No recomendado para menores de 12 años" | existente | `WM/ParentalRating` |
| System.Media.Writer | Guion | nuevo | `WM/Writer` |
| System.Media.Publisher | País | nuevo | `WM/Publisher` |
| System.Music.Conductor | Fotografía | nuevo | `WM/Conductor` |
| System.Keywords | Temas de FilmAffinity | nuevo | `WM/Category` (un valor por tema) |
| System.Media.AuthorUrl | Enlace a FilmAffinity | nuevo | `WM/AuthorURL` |
| System.Media.PromotionUrl | Enlace a IMDb | nuevo | `WM/PromotionURL` |
| System.Music.Period | Premios (resumen) | nuevo | `WM/Period` |
| System.Music.AlbumTitle | Saga (oculto en Detalles) | nuevo | `©alb` |
| System.Music.TrackNumber | Nº dentro de la saga (oculto) | nuevo | `trkn` |

No se pueden escribir en MP4: Copyright, ParentalRatingReason, PartOfSet, DateEncoded. La carátula va en `covr` (13 JPEG, 14 PNG). Windows separa por «;» los valores de las propiedades de lista: la app no deja escribir «;» en ellas (salvo Temas).

## Fuentes de datos
- **FilmAffinity** devuelve 403 a peticiones automáticas: solo se lee con navegador real (WebView2), de forma semiautomática y para películas nuevas. Sin API.
- **TMDB** (clave gratuita): país, guion, fotografía, saga, edad en España, IMDb. Para el lote de las 5.541.
- **OMDb** (clave gratuita): nota de Rotten Tomatoes. **Wikidata**: IMDb → ID de FilmAffinity.
- Identificación segura: título + año + **director** deben coincidir; si hay dudas, no se escribe nada.

## Arquitectura (decidida)
- **Flutter** (Windows + Android, un solo código), Riverpod, SQLite con Drift + FTS5.
- Property System con **FFI propio** (`lib/disco/propiedades_windows.dart`, sin el paquete `win32`: su v6 no trae `SHGetPropertyStoreFromParsingName`). Carátula leída en Dart puro (`lib/disco/caratula_mp4.dart`). `System.Rating` 0–99 → estrellas: 1/25/50/75/99.
- **Sin plugins de Flutter** mientras Windows no tenga el *Modo de desarrollador* (los plugins lo exigen y requiere administrador): diálogos de Windows (abrir archivo, elegir carpeta con `IFileOpenDialog`) también por FFI. El paquete `sqlite3` v3 **sí funciona**: trae SQLite (con FTS5) mediante *build hooks*, no es un plugin.
- Base de datos: `lib/datos/base_datos.dart` (Drift; el `.g.dart` generado se sube al repo). Datos de la app en `%LOCALAPPDATA%\Videoteca` (`videoteca.sqlite` + `miniaturas\<id>.jpg`, 240 px). Proveedores Riverpod en `lib/datos/catalogo.dart`.
- Buscador (`lib/datos/buscador.dart`, sin Flutter): índice **en memoria** (no FTS5: con 5.541 películas tarda ~10 ms y permite ordenar a medida; también servirá en Android con el catálogo descargado). Limpia tildes/signos, prefijos de palabra, «spiderman» ↔ «Spider-Man», ámbitos Todo/Títulos/Actores/Directores y sugerencias de personas. Autocompletado en `lib/widgets/buscador_sugerencias.dart`; Ctrl + K en `marco.dart`.
- Filtros del Catálogo (`lib/datos/filtros.dart`, sin Flutter): `Filtros` + `Facetas` (recuentos con el resto de filtros); textos limpiados una vez y guardados con `Expando`. Género = géneros de la ficha; Carpeta = `grupo` / subcarpeta. La ruta `/catalogo` acepta `q, en, genero, grupo, carpeta, pais, saga, director, actor`.
- Acciones de Windows por FFI en `lib/disco/acciones_windows.dart`: `ShellExecuteW` (reproducir/abrir webs) y `SHOpenFolderAndSelectItems` (abrir carpeta). `discoConectadoProvider` comprueba la carpeta raíz cada 5 s; `peliculasDePersonaProvider` da las películas de un director/actor.
- Escáner (`lib/disco/escaner.dart`, sin Flutter): 4 isolates en paralelo, ~60 ms/película en el HDD (escaneo completo ≈ 5,5 min), incremental por tamaño + fecha de modificación; se salta carpetas ocultas/de sistema. Carpeta raíz guardada en el ajuste `carpetaRaiz`; sin ella, el PC abre el asistente `/bienvenida`.
- Cambios en el disco (día 8): `lib/disco/vigilante.dart` (`Directory.watch` recursivo + 3 s de calma) → `vigilanciaProvider` (`lib/datos/vigilancia.dart`) → `Escaneo.revisar()`. El escáner empareja movidas por tamaño + fecha (conservan el id), marca `desaparecida` (no borra) y `nueva` (bandeja de Nuevas; no en el primer escaneo ni al cambiar de raíz), y se salta archivos en copia (`archivoEnUso`, CreateFileW sin compartir escritura). Pendientes en `lib/datos/pendientes.dart` (sin Flutter); lo revisado se guarda en el ajuste `pendientesRevisados`.
- Escritura (día 9): `lib/disco/etiquetas_mp4.dart` (cajas, sin Flutter ni Windows; devuelve `CopiaOriginal` para restaurar byte a byte) → `lib/disco/escritor.dart` (`Campo` = propiedad + caja, `escribirFicha`: valida, solo escribe lo distinto, comprueba con Windows campos/carátula/duración y `HuellaVideo` —3 muestras de 1 MB de `mdat`— y si falla restaura) → `lib/datos/edicion.dart` (isolate, registro, relee la película al catálogo). Registro de cambios = tabla `Cambios` (base de datos **versión 3**; antes/después en JSON por `Campo.name`; carátulas en `%LOCALAPPDATA%\Videoteca\copias\<id>-antes|despues.img`). Deshacer = volver a escribir lo de antes, avisando si la ficha cambió después. Pantallas `/pelicula/:id/editar` y `/registro` (desde Ajustes). Pruebas con copias: `dart run tool/probar_escritura.dart D:\ <temporal> [n | nombre]`.
- `Isolate.run` dentro de un método de una clase con `ref`/`State` falla en ejecución («object is unsendable»): lanzarlo desde funciones sueltas (ver final de `edicion.dart`).
- Instalador: `windows/instalador/videoteca.iss` (Inno Setup, por usuario, sin admin). `.github/workflows/publicar.yml` lo compila y publica en Releases al subir una etiqueta `v*` (notas en `docs/novedades/<etiqueta>.md`; versión de `pubspec.yaml`). Inno Setup no está instalado en el PC: se compila solo en GitHub.
- **Sin servidor y gratis:** el PC administrador publica el catálogo y las miniaturas WebP, **cifrados** (AES-256-GCM + Argon2id), en un **repositorio de GitHub "tablón"** separado, vía REST API y automáticamente al guardar, con número de versión. Los usuarios base (Android/Windows) lo descargan al abrir la app y entran con una **contraseña común**. El administrador solo trabaja desde el PC.
- Las claves (TMDB, OMDb, llave de GitHub) **nunca** se suben al repositorio.

## Decisiones pendientes
Ver la tabla al final de `PLANNING.md`.
