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
- Escribir propiedades con `IPropertyStore` (Windows Property System) **conserva la carátula byte a byte** y no toca el vídeo (probado en una copia).
- La app debe ser **genérica**: carpeta raíz configurable y géneros detectados de las carpetas, sin nada fijo a este disco.

## Asignación de campos (Windows → significado)
| Propiedad de Windows | Dato | Estado |
|---|---|---|
| System.Title | Título en España (el del nombre de archivo; no se sustituye) | existente |
| System.Media.SubTitle | Título original | existente |
| System.Comment | Sinopsis (de FilmAffinity) | existente |
| System.Music.Artist | Reparto | existente |
| System.Media.Year | Año | existente |
| System.Music.Genre | Géneros, formato `Drama. Comedia. Romance` | existente |
| System.Rating | Estrellas = Rotten Tomatoes | existente |
| System.Video.Director | Dirección | existente |
| System.Media.Producer | Productora | existente |
| System.Music.Composer | Música | existente |
| System.ParentalRating | Frase de edad, ej. "No recomendado para menores de 12 años" | existente |
| System.Media.Writer | Guion | nuevo |
| System.Media.Publisher | País | nuevo |
| System.Music.Conductor | Fotografía | nuevo |
| System.Keywords | Temas de FilmAffinity | nuevo |
| System.Media.AuthorUrl | Enlace a FilmAffinity | nuevo |
| System.Media.PromotionUrl | Enlace a IMDb | nuevo |
| System.Music.Period | Premios (resumen) | nuevo |
| System.Music.AlbumTitle | Saga (oculto en Detalles) | nuevo |
| System.Music.TrackNumber | Nº dentro de la saga (oculto) | nuevo |

No se pueden escribir en MP4: Copyright, ParentalRatingReason, PartOfSet, DateEncoded.

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
- Escáner (`lib/disco/escaner.dart`, sin Flutter): 4 isolates en paralelo, ~60 ms/película en el HDD (escaneo completo ≈ 5,5 min), incremental por tamaño + fecha de modificación; se salta carpetas ocultas/de sistema. Carpeta raíz guardada en el ajuste `carpetaRaiz`; sin ella, el PC abre el asistente `/bienvenida`.
- **Sin servidor y gratis:** el PC administrador publica el catálogo y las miniaturas WebP, **cifrados** (AES-256-GCM + Argon2id), en un **repositorio de GitHub "tablón"** separado, vía REST API y automáticamente al guardar, con número de versión. Los usuarios base (Android/Windows) lo descargan al abrir la app y entran con una **contraseña común**. El administrador solo trabaja desde el PC.
- Las claves (TMDB, OMDb, llave de GitHub) **nunca** se suben al repositorio.

## Decisiones pendientes
Ver la tabla al final de `PLANNING.md`.
