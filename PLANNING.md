# 🎬 Videoteca — Planning de desarrollo

Catálogo de películas para Windows y Android: detecta las películas del disco, rellena sus fichas automáticamente, escribe los datos dentro de cada `.mp4` y publica el catálogo para consultarlo desde el móvil.

- **Diseño de referencia:** [Videoteca – Diseño de la app](https://claude.ai/artifact/ExVasA5vV2r3fByTLLAxnW) (privado)
- **Prompt de diseño:** [docs/prompt-claude-design.md](docs/prompt-claude-design.md)

## Cómo trabajamos

- Cada **"día"** es una **sesión de trabajo**, no un día del calendario. Se empieza cuando digas "vamos con el día X".
- Al final de cada día:
  - hay algo que **se puede ver o probar**;
  - se hace **commit y push** a GitHub;
  - se marca el día como completado en este archivo (☐ → ☑).
- Las versiones se etiquetan en GitHub: `v0.1`, `v0.2`… hasta `v1.0`.
- **Regla de seguridad:** hasta el día 9 la app **solo lee** el disco. Antes de escribir en archivos reales, todo se prueba con copias.

## Stack

| Pieza | Tecnología |
|---|---|
| App Windows + Android | Flutter (Dart), Material 3, Riverpod |
| Base de datos local y buscador | SQLite con Drift + FTS5 |
| Datos del `.mp4` | API nativa de Windows (Property System) vía FFI propio |
| Datos automáticos | TMDB, OMDb, Wikidata (APIs) · FilmAffinity (WebView2) |
| Tablón compartido | Repositorio de GitHub (REST API), cifrado AES-256-GCM + Argon2id |
| Compilación e instaladores | GitHub Actions · instalador Windows · APK Android |

## Resumen

| Fase | Días | Resultado |
|---|---|---|
| 0 · Preparación | 1–2 | Entorno instalado, repositorio y esqueleto de la app con el diseño |
| 1 · Catálogo (solo lectura) | 3–8 | **v0.1**: buscar y ver tus 5.541 películas en Windows |
| 2 · Escritura y datos automáticos | 9–13 | **v0.2**: completar fichas nuevas y toda la colección |
| 3 · Publicación y móvil | 14–16 | **v0.3**: consulta desde Android |
| 4 · Cierre | 17–20 | **v1.0**: estadísticas, pulido, instaladores y documentación |

---

## Fase 0 · Preparación

### ☑ Día 1 — Entorno y repositorio
**Objetivo:** dejar el PC listo para programar y el proyecto en GitHub.
- Instalar **Flutter**, **Visual Studio Community** (con "Desarrollo para el escritorio con C++"), **Android Studio** (con el SDK de Android) y las extensiones de Flutter y Dart en VS Code.
- Comprobar con `flutter doctor` que todo está bien.
- Crear el repositorio `videoteca` en GitHub y subir este planning.
- Crear el proyecto Flutter (Windows + Android), `README.md`, licencia y `.gitignore` (las claves nunca se suben).
- GitHub Actions básico: comprobar que el código compila en cada commit.

**Al terminar:** la app vacía se abre en Windows.
**Necesito de ti:** aceptar las instalaciones y entrar en tu cuenta de GitHub.

### ☑ Día 2 — Esqueleto visual
**Objetivo:** la app con el aspecto del diseño, aún sin datos reales.
- Tema oscuro "sala de cine": colores, tipografías (Bricolage Grotesque + Manrope) y modo claro.
- Navegación: menú lateral en Windows y barra inferior en Android.
- Pantallas vacías: Inicio, Catálogo, Ficha, Nuevas, Pendientes, Completar colección, Ajustes.
- Componente **Carátula** reutilizable.

**Al terminar:** puedes navegar por todas las pantallas con datos de ejemplo.

---

## Fase 1 · Catálogo (solo lectura)

### ☑ Día 3 — Leer los datos de los `.mp4`
- Leer desde la app los campos de "Propiedades → Detalles": título, subtítulo, comentarios, reparto, año, género, estrellas, director, productores, compositores y clasificación parental.
- Leer la **carátula incrustada**, la duración, la resolución y el tamaño.
- Prueba con 10 películas reales comparando con lo que muestra Windows.

**Al terminar:** la app muestra los datos reales de una película elegida.
**Hecho:** Ajustes → *Leer un archivo .mp4*. Para probar desde la terminal: `dart run tool/probar_lectura.dart` (lee 10 películas de `D:\`, ~0,12 s cada una).

### ☑ Día 4 — Escaneo del disco y base de datos
- Base de datos local (SQLite) con el modelo `Película`.
- Asistente de primer arranque: elegir la carpeta raíz (`D:\`) y detectar las carpetas de géneros automáticamente.
- Escaneo completo de las 5.541 películas con barra de progreso.
- Guardar miniaturas de las carátulas para que todo vaya rápido.

**Al terminar:** tus 5.541 películas están en el catálogo de la app.
**Hecho:** el escaneo completo tarda ~5,5 min (4 lecturas a la vez); los siguientes solo leen lo nuevo o cambiado (Ajustes → *Buscar cambios*). Base de datos y miniaturas (240 px, ~27 KB) en `%LOCALAPPDATA%\Videoteca`. Son 5.540 `.mp4` + 1 `.m4v` (*Wonka*), que también se acepta. Prueba desde la terminal: `dart run tool/escanear.dart D:\ <carpeta temporal>`.

### ☐ Día 5 — Inicio y buscador
- Pantalla de Inicio: contador, "Añadidas recientemente" y géneros.
- **Buscador con autocompletado** instantáneo: título español u original, sin importar tildes ni mayúsculas, y también por actor y director.

**Al terminar:** escribes "vengadores" y aparece al momento.

### ☐ Día 6 — Catálogo y filtros
- Cuadrícula y vista de lista.
- Filtros combinables: género, carpeta, año, país, estrellas, edad, saga, director y actor.
- Ordenación: título, año, estrellas y fecha añadida.

### ☐ Día 7 — Ficha de película
- Ficha completa con el bloque **"Dónde está"** (ruta exacta, calidad y tamaño).
- Botones Reproducir, Abrir carpeta y Copiar ruta.
- Pulsar un actor o director muestra sus otras películas de la colección.
- Aviso de "disco desconectado" (la búsqueda sigue funcionando).

### ☐ Día 8 — Cambios en el disco y Pendientes · 🏷 v0.1
- Vigilancia de carpetas: detectar al momento las películas **nuevas**, **movidas** y **desaparecidas**.
- Pantalla **Pendientes**: duplicadas, sin carátula, incompletas y nombre fuera de formato.
- Primer instalador de Windows.

**Al terminar:** 🎉 **v0.1** — ya puedes usar la app a diario para buscar tus películas.

---

## Fase 2 · Escritura y datos automáticos

### ☐ Día 9 — Escribir en los `.mp4`
- Escribir campos y **carátula** dentro del archivo con el mismo sistema que usa Windows.
- Verificación tras cada escritura: la carátula y los datos existentes quedan intactos.
- **Registro de cambios con deshacer.**
- "Editar ficha" a mano desde la app.
- Todo probado primero con **copias**, nunca con los originales.

### ☐ Día 10 — Fuentes de datos automáticas
- Integración con **TMDB** (país, guion, fotografía, saga, edad en España, IMDb), **OMDb** (Rotten Tomatoes) y **Wikidata** (enlace a FilmAffinity).
- Identificación segura: el título, el año y el director tienen que coincidir.
- Reglas de conversión: porcentaje de Rotten Tomatoes → estrellas y calificación de edad → tu frase.

**Necesito de ti:** registrarte en TMDB y OMDb (gratis) para obtener las claves, tus rangos de estrellas y tus frases de edad.

### ☐ Día 11 — FilmAffinity
- Navegador integrado (WebView2) que abre la ficha de FilmAffinity y lee: título original, sinopsis, géneros, temas, reparto, guion, música, fotografía, productora, país y premios.

### ☐ Día 12 — Películas nuevas y Completar ficha
- Bandeja de **Películas nuevas** con estados.
- Pantalla **Completar ficha**: campos rellenos solos, etiqueta de origen de cada dato y carátula arrastrable.
- Selector "¿Cuál es?" cuando hay varias coincidencias.
- Guardar en el archivo.

**Al terminar:** pegas una película en el disco, la app la detecta, pones la carátula, guardas y ya está.

### ☐ Día 13 — Completar mi colección · 🏷 v0.2
- Proceso por lotes: rellenar solo los campos vacíos de las 5.541 películas.
- Pausar y reanudar, contadores, dudosas sin tocar, registro y deshacer.
- Ejecución por etapas: **primero 50 películas**, revisamos juntos el resultado y después el resto.

**Necesito de ti:** decidir si los temas y premios de FilmAffinity se intentan también en lote (una pasada lenta de 25–30 horas) o solo para películas nuevas.

---

## Fase 3 · Publicación y móvil

### ☐ Día 14 — Tablón en GitHub
- Crear el repositorio del tablón (separado del código).
- Exportar el catálogo y miniaturas WebP de las carátulas, **cifrados** con la contraseña común.
- Publicación automática al guardar, con número de versión.

**Necesito de ti:** crear la llave de acceso de GitHub (te guío) y elegir la contraseña común.

### ☐ Día 15 — Modo consulta
- Inicio de sesión: administrador (contraseña local en el PC) o consulta (contraseña común).
- Descargar el tablón, descifrarlo y guardar una copia para usar sin internet.
- Comprobar al abrir si hay versión nueva y descargar solo los cambios.

### ☐ Día 16 — Android · 🏷 v0.3
- Pantallas móviles: Acceso, Inicio, Buscar, Géneros y Ficha.
- Generar la **APK** e instalarla en tu móvil.

**Al terminar:** 🎉 **v0.3** — guardas una película en el PC y aparece en el móvil.

---

## Fase 4 · Cierre

### ☐ Día 17 — Estadísticas y exportación
- Estadísticas: por género, década y país, directores y actores más presentes, sagas incompletas.
- Exportar a Excel y copia de seguridad del catálogo.

### ☐ Día 18 — Pulido
- Rendimiento con las 5.541 películas.
- Estados especiales: sin internet, disco desconectado, sin resultados, sin carátula.
- Mensajes de error claros y accesibilidad.

### ☐ Día 19 — Instaladores y documentación
- Instalador de Windows definitivo.
- GitHub Actions: cada versión genera automáticamente el `.exe` y la `.apk` en *Releases*.
- README con instrucciones para que **otras personas** monten su propia colección.

### ☐ Día 20 — Pruebas finales · 🏷 v1.0
- Recorrido completo: película nueva → ficha → guardar → aparece en el móvil.
- Corrección de los últimos fallos.
- 🎉 **Versión 1.0**.

---

## Decisiones pendientes

| Decisión | Se resuelve el |
|---|---|
| Rangos de Rotten Tomatoes → estrellas | Día 10 |
| Frases exactas de clasificación por edades | Día 10 |
| Temas y premios de FilmAffinity en lote o solo en nuevas | Día 13 |
| Contraseña común para los usuarios | Día 14 |
| Publicar la APK en Google Play (25 €, opcional) | Día 19 |

## Ideas para después de la v1.0

- Notificación en el móvil al añadir películas.
- Marcar películas como vistas y nota personal.
- Varios discos o colecciones.
