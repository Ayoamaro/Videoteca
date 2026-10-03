# Prompt para Claude Design — App "Videoteca"

> Copia todo lo que hay debajo de la línea y pégalo en Claude Design.

---

Diseña la interfaz de una aplicación llamada **Videoteca** (nombre provisional): un catálogo personal de una colección de películas guardadas en un disco duro. La app existe en **Windows (escritorio)** y en **Android (móvil)**, con el mismo estilo visual adaptado a cada pantalla. Todo el texto de la interfaz va en **español de España**.

## Contexto

- El propietario tiene un disco duro con **más de 5.500 películas** en `.mp4`, organizadas en carpetas por género (por ejemplo `D:\Ciencia Ficción\Ciencia Ficción\`, `D:\Suspense, Terror y Thriller\Thriller\`). Los archivos se llaman `Título (Año).mp4`.
- Cada archivo lleva sus datos incrustados (los de "Propiedades → Detalles" de Windows) y su **carátula personalizada de 350×500 px** (formato póster vertical, proporción 7:10).
- La app sirve para saber al instante **si una película está en la colección y en qué carpeta exacta se encuentra**, y para que el administrador rellene automáticamente la ficha de las películas nuevas.
- El catálogo se sincroniza en la nube, así que los usuarios pueden consultarlo desde el móvil sin tener el disco.

## Roles

1. **Administrador**: acceso total. Ve las películas nuevas detectadas en el disco, rellena sus datos (automáticamente desde internet), añade la carátula a mano, edita fichas y gestiona usuarios. Escribir en los archivos solo es posible desde el PC con el disco conectado.
2. **Usuario base**: solo consulta. Ve las películas añadidas recientemente, busca, filtra y abre fichas. No puede añadir, editar ni borrar nada; en su interfaz no aparece ningún control de edición.

## Datos de cada película (ficha)

Carátula · Título en España · Título original · Año · Duración · País · Género(s) (varios, ej. "Fantástico. Ciencia ficción. Acción") · Temas (etiquetas, ej. "Superhéroes · Cómic · Marvel · Secuela") · Sinopsis · Dirección · Guion · Reparto · Música · Fotografía · Productora · Saga y posición en ella (ej. "Los Vengadores · 3 de 4") · Premios (resumen, ej. "Nominada a 1 Óscar") · Puntuación de Rotten Tomatoes en 1–5 estrellas · Clasificación por edades (ej. "No recomendado para menores de 12 años") · Calidad (720p/1080p/4K) · Tamaño · **Ruta exacta del archivo** (carpeta + nombre) · Enlaces a FilmAffinity e IMDb · Fecha en que se añadió.

**Ejemplo real para los mockups:**
- Título: Los Vengadores 3: Infinity War — Original: Avengers: Infinity War
- 2018 · 2 h 29 min · Estados Unidos · ★★★★☆
- Géneros: Fantástico, Ciencia ficción, Acción — Temas: Superhéroes, Cómic, Marvel Comics, MCU, Secuela
- Dirección: Anthony Russo, Joe Russo — Guion: Christopher Markus, Stephen McFeely — Música: Alan Silvestri — Fotografía: Trent Opaloch — Productora: Marvel Studios
- Reparto: Robert Downey Jr., Chris Hemsworth, Benedict Cumberbatch, Chris Evans, Mark Ruffalo, Scarlett Johansson…
- Edad: No recomendado para menores de 12 años
- Sinopsis: "El todopoderoso Thanos ha despertado con la promesa de arrasar con todo a su paso, portando el Guantelete del Infinito…"
- Ruta: `D:\Aventuras y Fantasía\Fantasía\Los Vengadores 3꞉ Infinity War (2018).mp4` · 1080p · 4,1 GB
- Otros títulos para rellenar cuadrículas: Forrest Gump (1994), Solo en casa (1990), Hotel Artemis (2018), Triple 9 (2016), Haru en el reino de los gatos (2002), Liberad a Willy 2 (1995), Joy (2015), Sin límites (2011).

## Pantallas a diseñar

### Comunes (ambos roles)

1. **Inicio de sesión**: logo, usuario/correo, contraseña, "Entrar". Limpia y con estilo cinematográfico.
2. **Inicio**:
   - Buscador grande y protagonista arriba, con **autocompletado** (desplegable con miniatura de carátula, título y año). Busca por título español, título original, actor o director.
   - Carrusel o cuadrícula **"Añadidas recientemente"** con carátulas grandes y una etiqueta "NUEVA" en las de los últimos días.
   - Accesos rápidos por género (las carpetas de la colección: Acción, Bélico, Western, Animación, Infantil & Familiar, Manga, Aventuras, Fantasía, Ciencia Ficción, Comedia, Romance, Drama, Musical, Suspense, Terror, Thriller).
   - Contador total ("5.541 películas").
3. **Catálogo / Resultados**: cuadrícula de carátulas (alternable con vista de lista), ordenación (título, año, estrellas, fecha añadida) y panel de **filtros combinables**: género, carpeta, año/década, país, estrellas, clasificación por edades, saga, director, actor. En Windows el panel va lateral; en Android, en una hoja inferior.
4. **Ficha de película**: carátula grande, título y título original, línea de metadatos (año · duración · país · estrellas), chips de géneros y temas, insignia de edad, sinopsis, créditos en dos columnas, saga con enlace a las demás películas de la saga que hay en la colección, premios y un **bloque destacado "📁 Dónde está"** con la ruta exacta, la calidad y el tamaño. Botones: Abrir carpeta y Reproducir (solo en Windows con el disco conectado), FilmAffinity e IMDb. Al pulsar un actor o director se ven sus otras películas de la colección.

### Solo administrador (Windows)

5. **Inicio de administrador**: lo mismo que el Inicio común, más un aviso destacado arriba: "🆕 3 películas nuevas detectadas en el disco — Completar fichas". Indicador del estado del disco (conectado/desconectado) y de la sincronización con la nube.
6. **Películas nuevas (bandeja)**: lista de archivos nuevos detectados en el disco (sin datos), con estado: "Buscando datos…", "Lista para revisar", "Varias coincidencias", "Guardada".
7. **Completar ficha**: a la izquierda, un hueco para la carátula ("Arrastra aquí tu carátula 350×500" + botón "Elegir imagen…"); a la derecha, el formulario con todos los campos ya rellenos automáticamente y editables, con un pequeño indicador de la fuente de cada dato (FilmAffinity / TMDB / OMDb). Botones "Descartar" y "💾 Guardar en el archivo".
8. **Elegir coincidencia**: diálogo con 2–4 posibles películas (carátula, título, año, director) cuando la búsqueda automática no está segura.
9. **Completar mi colección (proceso por lotes)**: casillas de los campos a rellenar (País, Guion, Fotografía, Saga, IMDb, Enlace FilmAffinity, Temas, Premios), barra de progreso grande ("2.315 / 5.541 · quedan ~40 min"), contadores (Completadas / Dudosas / No encontradas) y botones Pausar, Ver dudosas y Ver registro.
10. **Revisión de pendientes**: bandeja con pestañas o secciones: Dudosas, Sin carátula, Incompletas, Duplicadas (misma película en dos carpetas), Desaparecidas del disco, Nombre fuera de formato.
11. **Usuarios**: lista de usuarios con su rol (Administrador / Usuario), crear usuario, cambiar rol y desactivar.
12. **Ajustes**: carpeta raíz de la colección, claves de servicios (TMDB, OMDb), reglas de conversión (porcentaje de Rotten Tomatoes → estrellas; frases de clasificación por edades), sincronización y exportar a Excel.
13. **Estadísticas** (opcional): películas por género, década y país; directores y actores con más películas; sagas incompletas ("Tienes 3 de 4").

### Android (usuario base y administrador)

- Las pantallas 1–4 adaptadas a móvil: barra de navegación inferior (Inicio · Buscar · Géneros · Perfil), cuadrícula de 3 columnas, ficha en scroll vertical con la carátula arriba y el bloque "Dónde está" muy visible.
- El administrador en Android ve un aviso "X películas pendientes de completar en el PC" (sin edición).

## Estados que también hay que mostrar

- Disco desconectado (la búsqueda sigue funcionando; Abrir carpeta y Reproducir desactivados).
- Sin conexión a internet.
- Búsqueda sin resultados: "No tienes esta película en la colección".
- Cargando y escaneando el disco (primera vez).
- Película sin carátula (marcador de posición elegante).

## Estilo visual

- Estética de **sala de cine / videoteca**: tema **oscuro** por defecto (y variante clara), las carátulas como protagonistas, tipografía limpia y legible, acento de color cálido (dorado o rojo de butaca) para estrellas, etiquetas "NUEVA" y botones principales.
- Carátulas siempre en proporción 7:10, con esquinas ligeramente redondeadas y sombra suave.
- Clasificación por edades como insignia de color (TP verde, 7 azul, 12 amarillo, 16 naranja, 18 rojo).
- Prioridad absoluta a la velocidad del buscador: grande, siempre accesible y con resultados inmediatos.
- Para Windows, ventana de escritorio de ~1440×900 con barra lateral de navegación (Inicio, Catálogo, Nuevas, Pendientes, Completar colección, Estadísticas, Usuarios, Ajustes; los usuarios base solo ven Inicio y Catálogo). Para Android, ~390×844.
