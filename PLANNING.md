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
- Las versiones se etiquetan en GitHub: `v0.1`, `v0.2`… hasta `v1.0`; después, `v1.1`, `v1.2`…
- **Regla de seguridad:** hasta el día 9 la app **solo lee** el disco. Antes de escribir en archivos reales, todo se prueba con copias.

## Stack

| Pieza | Tecnología |
|---|---|
| App Windows + Android | Flutter (Dart), Material 3, Riverpod |
| Base de datos local y buscador | SQLite con Drift + FTS5 |
| Datos del `.mp4` | API nativa de Windows (Property System) vía FFI propio |
| Datos automáticos | TMDB, OMDb, Wikidata (APIs) · FilmAffinity (WebView2) |
| Tablón compartido | Repositorio público de GitHub (REST API), cifrado AES-256-GCM + Argon2id |
| Compilación e instaladores | GitHub Actions · instalador Windows · APK Android |

## Resumen

| Fase | Días | Resultado |
|---|---|---|
| 0 · Preparación | 1–2 | Entorno instalado, repositorio y esqueleto de la app con el diseño |
| 1 · Catálogo (solo lectura) | 3–8 | **v0.1**: buscar y ver tus 5.541 películas en Windows |
| 2 · Escritura y datos automáticos | 9–13 | **v0.2**: completar fichas nuevas y toda la colección |
| 3 · Publicación y móvil | 14–16 | **v0.3**: consulta desde Android |
| 4 · Cierre | 17–20 | **v1.0**: estadísticas, pulido, instaladores y documentación |
| 5 · Red de casa | 21–24 | **v1.1**: reproducir, abrir y copiar películas desde cualquier PC de casa |

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

### ☑ Día 5 — Inicio y buscador
- Pantalla de Inicio: contador, "Añadidas recientemente" y géneros.
- **Buscador con autocompletado** instantáneo: título español u original, sin importar tildes ni mayúsculas, y también por actor y director.

**Al terminar:** escribes "vengadores" y aparece al momento.
**Hecho:** cada búsqueda tarda ~10 ms entre las 5.541. Debajo del buscador de Inicio salen hasta 6 películas y los actores o directores con ese nombre; ↑ ↓ e Intro para elegir, **Ctrl + K** desde cualquier pantalla. Encuentra «atame» → *¡Átame!*, «spiderman» → *Spider-Man* y «origen 2010» (título + año). En el Catálogo: botones *Todo / Títulos / Actores / Directores* y orden «Más parecidas». Prueba desde la terminal: `dart run tool/probar_busqueda.dart`.

### ☑ Día 6 — Catálogo y filtros
- Cuadrícula y vista de lista.
- Filtros combinables: género, carpeta, año, país, estrellas, edad, saga, director y actor.
- Ordenación: título, año, estrellas y fecha añadida.

**Hecho:** panel lateral (en el móvil, hoja inferior con «Ver N películas»). **Género** = los de la ficha (Comedia 2.417…) y **Carpeta** = dónde está, en árbol (*Comedias › Romance*). Cada opción muestra cuántas películas saldrían con el resto de filtros; dentro de un grupo vale cualquiera de las marcadas y entre grupos se tienen que cumplir todos. Año con barra y atajos por décadas, estrellas «3 o más», edad, y país/saga/dirección/reparto escribiendo el nombre (país y saga se llenarán el día 10). Ordenar por fecha añadida, título, año o estrellas, con la flecha para darle la vuelta; la vista lista/cuadrícula se recuerda. Filtrar las 5.541 tarda 1–5 ms. También se puede abrir ya filtrado: `/catalogo?director=…&actor=…&carpeta=…`. Arreglada la insignia de edad para +10 y +13.
**Datos raros vistos en el disco (para Pendientes, día 8):** *DC Liga de Supermascotas (2022)* tiene el año `20222`; *Jurassic World 2: El Reino Caído* tiene «Michael Giacchino» como clasificación de edad; 18 frases de edad con erratas («…de 16 año», punto final).

### ☑ Día 7 — Ficha de película
- Ficha completa con el bloque **"Dónde está"** (ruta exacta, calidad y tamaño).
- Botones Reproducir, Abrir carpeta y Copiar ruta.
- Pulsar un actor o director muestra sus otras películas de la colección.
- Aviso de "disco desconectado" (la búsqueda sigue funcionando).

**Hecho:** **Reproducir** abre la película con tu reproductor de Windows (VLC) y **Abrir carpeta** abre el Explorador con el archivo ya seleccionado (también con nombres que llevan `꞉`). Cada nombre de Dirección y Reparto se puede pulsar: lleva al lado el número de películas suyas que tienes y abre una ventana con todas ellas (y «Ver en el Catálogo» para filtrarlas). Debajo, **«Más de *director*»** con hasta 6 carátulas; si una es otra copia de la misma película, lo indica. Botones *Buscar en FilmAffinity / IMDb* (abren la ficha directa cuando el enlace esté guardado, día 10). El disco se comprueba cada 5 s: si no está, sale una franja de aviso, el punto del menú se pone rojo y Reproducir/Abrir carpeta se desactivan; si el disco está pero el archivo ya no, la ficha lo dice.
**Más datos raros (para Pendientes):** el archivo *El Caballero Oscuro 3꞉ La Leyenda Renace (2008).mp4* tiene el año 2008 en el nombre y 2012 en los datos, y su sinopsis está cortada a media palabra.

### ☑ Día 8 — Cambios en el disco y Pendientes · 🏷 v0.1
- Vigilancia de carpetas: detectar al momento las películas **nuevas**, **movidas** y **desaparecidas**.
- Pantalla **Pendientes**: duplicadas, sin carátula, incompletas y nombre fuera de formato.
- Primer instalador de Windows.

**Al terminar:** 🎉 **v0.1** — ya puedes usar la app a diario para buscar tus películas.
**Hecho:** Windows avisa a la app de cualquier cambio dentro de la carpeta raíz; tras 3 s de calma hace una revisión rápida (las 5.541 en menos de 1 s si no hay nada que leer). También revisa al abrir la app y al reconectar el disco. Las **nuevas** van a la bandeja de *Películas nuevas* (insignia en el menú y aviso abajo: «Película nueva: …», con *Ver*); un archivo que todavía se está copiando se espera a que termine. Las **movidas o renombradas** se reconocen por tamaño + fecha y conservan su ficha. Las **desaparecidas** ya no se borran solas: salen en Pendientes con *Quitar del catálogo* (y si vuelven, se recuperan). **Pendientes** con tus datos: 15 duplicadas (también *Predator* / *Depredador 4*, *Project X* / *Proyecto X*…, con calidad y tamaño de cada copia), 138 incompletas (dice qué falta), 69 *datos que revisar* (año imposible o distinto al del nombre, frases de edad mal escritas), 1 nombre fuera de formato y 0 sin carátula; cada una se puede ignorar/marcar como revisada (se recuerda). La base de datos pasa a la versión 2 sola. **Instalador:** al subir la etiqueta `v0.1`, GitHub Actions compila la app, crea `Videoteca-0.1.0-instalador.exe` (Inno Setup, sin pedir administrador, se instala en `%LOCALAPPDATA%\Programs\Videoteca`) y lo publica en *Releases*.

---

## Fase 2 · Escritura y datos automáticos

### ☑ Día 9 — Escribir en los `.mp4`
- Escribir campos y **carátula** dentro del archivo con el mismo sistema que usa Windows.
- Verificación tras cada escritura: la carátula y los datos existentes quedan intactos.
- **Registro de cambios con deshacer.**
- "Editar ficha" a mano desde la app.
- Todo probado primero con **copias**, nunca con los originales.

**Hecho:** probándolo con copias descubrimos que el sistema de escritura de Windows **solo guarda textos de hasta 255 letras** (con más, no guarda nada aunque diga que sí; con el reparto largo, lo borró) y que reescribe el archivo entero (~10 s por película en el disco duro). Así que la app escribe ella misma los datos **en el mismo formato que Windows** y después **Windows los vuelve a leer** para comprobarlo. Aprovecha el hueco libre que hay detrás de los datos: tarda unos 0,2 s y **el vídeo ni se mueve**. Tras cada guardado comprueba que los campos cambiados tienen el valor nuevo, que todos los demás y la carátula siguen idénticos y que el vídeo no ha cambiado; si algo no cuadra, deja el archivo **byte a byte** como estaba. **Editar ficha** (botón en la ficha): los datos se leen del propio archivo, cada campo cambiado se marca en dorado con su botón para volver atrás, estrellas con un toque, frases de edad más usadas, y **Cambiar/Quitar carátula** (JPEG o PNG). **Registro de cambios** (Ajustes): cada guardado con antes → después (y miniaturas de las carátulas) y **Deshacer** (también en el aviso tras guardar; si la ficha ha cambiado después, avisa). Probado con copias de 4 películas reales (sinopsis de 685 letras, reparto de 528, carátula nueva y deshacer): el archivo final es **idéntico al original** (misma huella SHA-256). Prueba desde la terminal: `dart run tool/probar_escritura.dart D:\ <carpeta temporal>`.
**Para el día 13:** como cada película tarda ~0,2 s en escribirse (en vez de 10 s), el lote de las 5.541 será cuestión de minutos de escritura. En la ficha no se puede escribir «;» en reparto, dirección, géneros… (Windows lo toma como separador): se usan comas.

### ☑ Día 10 — Fuentes de datos automáticas
- Integración con **TMDB** (país, guion, fotografía, saga, edad en España, IMDb), **OMDb** (Rotten Tomatoes) y **Wikidata** (enlace a FilmAffinity).
- Identificación segura: el título, el año y el director tienen que coincidir.
- Reglas de conversión: porcentaje de Rotten Tomatoes → estrellas y calificación de edad → tu frase.

**Necesito de ti:** registrarte en TMDB y OMDb (gratis) para obtener las claves, tus rangos de estrellas y tus frases de edad.
**Hecho:** las claves se ponen en **Ajustes → Servicios de datos** (la app las comprueba antes de guardarlas y solo quedan en este PC). En **Editar ficha** hay un botón **Buscar datos en internet**: busca la película en TMDB y solo la da por buena si coinciden **título** (el español o el original, con pequeñas diferencias), **año** (±1) y **director**; si no, enseña las parecidas para que elijas («Es esta»). Trae dirección, guion, fotografía, país, saga y su número, frase de edad y enlace a IMDb (TMDB), estrellas (OMDb) y enlace a FilmAffinity (Wikidata), cada dato con su etiqueta de origen. Vienen marcados solo los campos **vacíos**; los que ya tienes distintos se enseñan con «Ahora: …» y solo se cambian si los marcas. Después se guarda como siempre (comprobación, registro y deshacer). Probado con **150 películas tuyas al azar: 148 identificadas sin dudas** y 2 dudosas (una ya arreglada: el director venía en japonés; la otra, *Paranormal Activity*, 2007 en tu ficha y 2009 en TMDB). Los nombres de personas se piden en inglés porque en español TMDB pone algunos en su alfabeto (奥井敦 → Atsushi Okui). Prueba desde la terminal: `dart run tool/probar_fuentes.dart [n | título] [sin-omdb]`.
**Reglas decididas:** estrellas en tramos de 20 % (0–19 % = 1★ … 80–100 % = 5★). Ojo: con tus estrellas actuales solo coinciden 32 de 127, porque casi no usas 1★ ni 5★; como solo se rellenan los vacíos, afecta sobre todo a las nuevas. Edades: primero la calificación de **EE. UU.** (G → TP, PG → 7, PG-13 → 13, R y NC-17 → 18) y, si no hay, la de **España** (TP, 7, 12, 16, 18). Es la regla que más se parece a tus frases (tus «13» vienen del PG-13), aunque en las de R a veces pusiste 16 y otras 18.
**Para el día 13:** OMDb gratis = 1.000 consultas al día → las estrellas de toda la colección tardarían ~6 días (o 1 $/mes en Patreon de OMDb para 100.000/día). TMDB y Wikidata no tienen ese límite (~1,2 s por película).

### ☑ Día 11 — FilmAffinity
- Navegador integrado (WebView2) que abre la ficha de FilmAffinity y lee: título original, sinopsis, géneros, temas, reparto, guion, música, fotografía, productora, país y premios.

**Hecho:** en vez de WebView2 (que exigiría plugins y el *Modo de desarrollador*), la app usa **Microsoft Edge**, que ya viene con Windows: abre una ventana de Edge propia de la app (con su perfil aparte, sin tocar el tuyo) y lee la página que tienes abierta. En **Editar ficha** hay un botón nuevo, **Leer de FilmAffinity**: va directo a la ficha si ya se conoce su enlace (el guardado o el de Wikidata) y, si no, abre la búsqueda de FilmAffinity para que entres tú en la película. En cuanto la ventana está en la ficha de una película, la app la lee sola, **comprueba título, año (±1) y director** y aparta la ventana. Trae título original, géneros (con tu formato «Drama. Comedia»), sinopsis completa (sin el «(FILMAFFINITY)» final), dirección, reparto, guion, música, fotografía, productora, país, temas, premios y el enlace. Como el día 10: vienen marcados solo los campos vacíos (y la sinopsis si la tuya está cortada), los distintos se enseñan con «Ahora: …», y si no coincide la película no se marca nada. Probado con copias: *Hipnótico* leída e identificada, 5 datos guardados y comprobados. Prueba desde la terminal: `dart run tool/probar_filmaffinity.dart [n | título]`.
**Importante — Cloudflare:** FilmAffinity está protegido por Cloudflare y a veces enseña «Un momento… Verifique que es un ser humano». La app lo detecta y te pide que marques la casilla en la ventana de Edge; después sigue sola. **No se intenta saltar esa comprobación**. En las pruebas saltó a la segunda película abierta seguida y, una vez que salta, se repite hasta que una persona la resuelve.
**Para el día 13:** 679 de tus sinopsis están cortadas justo a las 255 letras (editadas en el Explorador) y 3.624 tienen más de 255 (de otro programa). Las cortadas se pueden completar con FilmAffinity película a película (el botón las marca solas).

### ☑ Día 12 — Películas nuevas y Completar ficha
- Bandeja de **Películas nuevas** con estados.
- Pantalla **Completar ficha**: campos rellenos solos, etiqueta de origen de cada dato y carátula arrastrable.
- Selector "¿Cuál es?" cuando hay varias coincidencias.
- Guardar en el archivo.

**Al terminar:** pegas una película en el disco, la app la detecta, pones la carátula, guardas y ya está.
**Hecho:** en cuanto aparece una película nueva, la app **busca sola sus datos en TMDB** (de una en una, en segundo plano) y la bandeja enseña su estado: *Buscando datos…*, **Lista para revisar**, **Varias coincidencias**, *No encontrada*, *Sin conexión* (con «Volver a buscar») y **Guardada** (con «Quitar las guardadas»); arriba, los contadores del diseño. El aviso «Película nueva: …» lleva directo a **Completar ficha**, que abre la película con todo ya puesto: título y año del **nombre del archivo** y los datos de TMDB/OMDb/Wikidata en los campos vacíos, cada uno con su **etiqueta de color** (FilmAffinity dorado, TMDB azul, OMDb rojo, Wikidata morado, nombre del archivo gris). Como un archivo recién copiado aún no tiene director, la identificación segura no es posible: si solo hay **una** película con ese título y año, sale como **«Probable»** (para que la compruebes); si hay varias, el selector **«¿Cuál es?»** enseña las parecidas con su cartel de TMDB (solo para reconocerlas, nunca se usa como carátula), y se puede buscar con otro título. «¿No es esta?» lo abre siempre. El botón principal es **Leer de FilmAffinity** (sinopsis, reparto, géneros, música, productora…). La **carátula se arrastra desde el Explorador** a la pantalla (la zona se ilumina al pasar por encima), o con «Elegir imagen…»; esto lo hace el propio programa de Windows de la app (sin plugins) y también funciona en Editar ficha. Al guardar (comprobación, registro como «Completar ficha» y deshacer, como siempre) pregunta si falta la carátula, marca la película como **Guardada** y pasa a la **siguiente nueva**. Probado con copias: *Hipnótico* vaciada como recién descargada → detectada al pegarla, «Lista para revisar» en ~20 s, carátula arrastrada y 10 datos guardados y comprobados con Windows. La base de datos pasa sola a la **versión 4**.

### ☑ Día 13 — Completar mi colección · 🏷 v0.2
- Proceso por lotes: rellenar solo los campos vacíos de las 5.541 películas.
- Pausar y reanudar, contadores, dudosas sin tocar, registro y deshacer.
- Ejecución por etapas: **primero 50 películas**, revisamos juntos el resultado y después el resto.

**Necesito de ti:** decidir si los temas y premios de FilmAffinity se intentan también en lote o solo para películas nuevas. Visto el día 11: un lote desatendido **no es viable** (Cloudflare pide marcar la casilla a mano y no se va a saltar); como mucho, una pasada «contigo delante» por tandas.
**Decidido:** el lote automático usa TMDB, OMDb y Wikidata; temas, premios y sinopsis cortadas van en un **Repaso con FilmAffinity** aparte, contigo delante.
**Hecho:** pantalla **Completar mi colección**. Eliges qué rellenar (título original, país, guion, fotografía, saga y nº, edad, estrellas, IMDb, FilmAffinity; cada casilla dice cuántas lo tienen vacío) y pulsas **Probar con 50 películas** (después *Seguir con 50 / 500 / Todas*). La app las hace de una en una en segundo plano (~1,4 s cada una; puedes cambiar de pantalla, el menú enseña una ruedecita): busca la película, solo escribe si coinciden **título, año y director**, y solo en los campos **vacíos** (esto lo garantiza también el propio escritor: aunque le pidieran otra cosa, no pisa un dato que ya existe). Cada escritura se comprueba con Windows y queda en el Registro de cambios. Contadores (completadas, sin datos nuevos, dudosas sin tocar, no encontradas), lista de resultados filtrable (las dudosas con «Revisar a mano») y **Deshacer la tanda** entera (las que hayas cambiado después a mano no se tocan). **Pausar / Reanudar**; si cierras la app a mitad, la tanda queda en pausa y sigue donde iba. Sin internet, sin clave o con el disco desconectado se para sola. OMDb solo se consulta para las 57 sin estrellas (no hay problema con las 1.000 al día). **Repaso con FilmAffinity**: *Sinopsis cortadas* (792) y *Sin temas*: abre cada película en Editar ficha con FilmAffinity ya buscando; guardas o «Saltar» y pasa a la siguiente; se puede dejar y seguir otro día. La base de datos pasa sola a la **versión 5**.
**Probado con copias** (14 películas): 14 completadas, 0 datos existentes cambiados; tras *Deshacer la tanda*, **14 de 14 idénticas byte a byte** a los originales; cierre brusco a mitad → al reabrir, en pausa y reanudable; repaso con FilmAffinity de una sinopsis cortada guardado y comprobado. Arreglado de paso: una «saga» de TMDB en chino (colección de usuario) ya no se acepta, y los avisos con «Deshacer» ya se cierran solos.
**Tanda 1 en tu disco (50 películas, 4/10/2026):** 50 completadas en 1 min 10 s, 0 dudosas, 0 errores, **0 datos existentes cambiados**. Guion, fotografía, país e IMDb en las 50; FilmAffinity en 46; saga en 19 (*Arma letal* 1–4, *Bourne* 1–5…). Revisada contigo y aprobada.
**Resto de la colección (tanda 2, 4/10/2026, ~3 h 20 min):** de las 5.526, **5.379 completadas**, 140 dudosas (sin tocar), 6 no encontradas y 1 con error (*Backrooms*: TMDB la ha borrado). **0 datos existentes cambiados.** Rellenado: país e IMDb en 5.379, guion en 5.340, FilmAffinity en 4.957, fotografía en 4.936, saga en 1.678, título original en 46, estrellas en 13 y edad en 8. Todo está en el Registro de cambios (5.379) y cada tanda se puede deshacer. Muchas dudosas son de Hong Kong: TMDB escribe el director con su nombre chino completo («Kirk Wong Chi-Keung» frente a «Kirk Wong»); se pueden revisar a mano desde la lista. **Mejorado después:** un nombre con una o dos palabras más al principio o al final cuenta como la misma persona («Kirk Wong» = «Kirk Wong Chi-Keung», «Martín Cuervo» = «Hugo Martín Cuervo»; no si sobra «Jr.»), y el botón *Volver a intentar las dudosas* resolvió 12 más (quedan 102: 51 sin director en la ficha, años distintos o dos películas iguales). Al guardar una dudosa desde Editar ficha, sale sola de la lista.
🎉 **v0.2** publicada: `Videoteca-0.2.0-instalador.exe` en GitHub → Releases.

---

## Fase 3 · Publicación y móvil

### ☑ Día 14 — Tablón en GitHub
- Crear el repositorio del tablón (separado del código).
- Exportar el catálogo y miniaturas WebP de las carátulas, **cifrados** con la contraseña común.
- Publicación automática al guardar, con número de versión.

**Necesito de ti:** crear la llave de acceso de GitHub (te guío) y elegir la contraseña común.
**Hecho:** repositorio **público** [Ayoamaro/Videoteca_Tablon](https://github.com/Ayoamaro/Videoteca_Tablon) (el del código pasa a llamarse `Ayoamaro/Videoteca`). Público para que los móviles lo descarguen sin ninguna llave; todo lo de dentro va **cifrado**: de la contraseña común sale una llave con **Argon2id** (64 MB, 3 pasadas: ~0,7 s en el PC; probar contraseñas a ciegas sale carísimo) y cada archivo se cifra con **AES-256-GCM**, que además detecta cualquier byte tocado. Sin cifrar solo van `tablon.json` (la «sal» y los parámetros, que el móvil necesita) y un README. Las películas van en **paquetes de 100** (56 de fichas, ~2,2 MB en total, y 56 de carátulas WebP de 180 px, ~13 KB cada una, 57,5 MB): al guardar una ficha solo cambia su paquete, y el móvil (día 15) solo tendrá que bajar ese. Un `indice.bin` cifrado lleva el **número de versión** y la huella de cada paquete. El mismo contenido cifrado da siempre los mismos bytes, así que lo que no cambia no se vuelve a subir; cada versión entra de golpe en **un solo commit sin historia detrás** (el repositorio no engorda con cada versión). **Ajustes → Publicación**: repositorio, llave de GitHub (*fine-grained*, solo para ese repositorio, «Contents: Read and write»; botón «Crear una llave» con la página de GitHub ya rellena) y contraseña común (no se guarda en ningún sitio: solo la llave sacada de ella). Se publica **sola 30 s después de cada cambio del catálogo** (como mucho cada 5 min durante un lote), al abrir la app si quedó algo pendiente, y con «Publicar ahora»; sin internet lo reintenta a los 5 min. Estado en el menú («Publicada v1») y en Ajustes, con barra de progreso. «Cambiar contraseña común» vuelve a cifrar y subir todo. **Primera publicación (4/10/2026):** versión 1 con las 5.526 películas y sus 5.526 carátulas, ~3 min (las carátulas WebP se preparan una vez, ~55 s, y se guardan en `%LOCALAPPDATA%\Videoteca\tablon`); republicar sin cambios tarda ~3 s. Comprobado descargándolo como el móvil: las 5.526 fichas y carátulas se descifran bien. Prueba: `dart run tool/leer_tablon.dart Ayoamaro/Videoteca_Tablon [contraseña]`.
**Arreglado:** la app instalada v0.1, abierta con los datos nuevos, dejó la base de datos marcada como «versión 2» y las versiones nuevas no arrancaban (se quedaban sin ventana). Ahora la actualización de la base comprueba qué columnas hay de verdad. Hasta instalar la v0.3, la app instalada (v0.2) no tiene la sección de publicar.

### ☑ Día 15 — Modo consulta
- Inicio de sesión: administrador (contraseña local en el PC) o consulta (contraseña común).
- Descargar el tablón, descifrarlo y guardar una copia para usar sin internet.
- Comprobar al abrir si hay versión nueva y descargar solo los cambios.
**Decidido:** la contraseña de administrador se pide **solo al entrar**; la sesión se queda abierta hasta pulsar «Cerrar sesión».
**Hecho:** al abrir la app sale la pantalla **¿Cómo quieres entrar?** (solo la primera vez, o después de cerrar la sesión). **Consultar el catálogo** (PC y móvil): tablón (ya propuesto: `Ayoamaro/Videoteca_Tablon`; también vale su enlace de GitHub) y **contraseña común**; la app saca la llave y comprueba que abre el índice del tablón («La contraseña no es correcta» si no). **Administrar este PC** (solo en Windows): la primera vez se **crea** la contraseña de administrador (dos veces, mínimo 6 caracteres); después se pide para entrar. No se guarda la contraseña, solo una huella sacada con Argon2id (en `sesion.json`); si se olvida, «¿La has olvidado?» explica cómo crear otra sin perder nada. Cada modo tiene **su propia base de datos**: el administrador la de siempre (tu colección no cambia) y el modo consulta una copia aparte en `%LOCALAPPDATA%\Videoteca\consulta`. **Copia para usar sin internet:** el modo consulta descarga el tablón, lo descifra y lo guarda (fichas en su base de datos y carátulas WebP); mientras baja la primera vez, una franja dorada enseña el progreso y ya se puede buscar en cuanto llegan las fichas. **Solo los cambios:** al abrir la app (y al volver a ella en el móvil, y cada 30 min) mira si hay un commit nuevo; si lo hay, compara la huella de cada paquete y baja **solo los que han cambiado**; avisa abajo («Catálogo actualizado a la versión 3: 2 películas nuevas · 1 ficha cambiada»). Si se corta a medias, la siguiente vez sigue donde iba. Si cambias la contraseña común, el móvil sigue viendo su copia y una franja pide **volver a entrar**. En consulta no aparece nada de administración (ni menú, ni Editar, ni Reproducir; las rutas de administración llevan a Inicio). **Ajustes → Catálogo descargado** (versión, fecha, «Buscar novedades») y **Ajustes → Sesión** (Cerrar sesión; el administrador también *Cambiar contraseña*). En el menú, «Catálogo v2 · Consulta».
**Probado con tu tablón real** (en una carpeta temporal, sin tocar tus datos): primera descarga de las **5.526 fichas y 5.526 carátulas (57,5 MB) en 20 s**; abrir otra vez sin cambios no baja nada; con un paquete desactualizado bajó solo ese y avisó «5 películas nuevas». Contraseñas buenas y malas de los dos modos, cerrar sesión y reabrir la app (recuerda la sesión). Prueba desde la terminal: `dart run tool/probar_consulta.dart <carpeta> [repositorio] [contraseña]`.
**Al instalar esta versión en tu PC:** la primera vez saldrá la pantalla de entrada → *Administrar este PC* → crea tu contraseña de administrador y sigues con tu colección como siempre.

### ☑ Día 16 — Android · 🏷 v0.3
- Pantallas móviles: Acceso, Inicio, Buscar, Géneros y Ficha.
- Generar la **APK** e instalarla en tu móvil.

**Al terminar:** 🎉 **v0.3** — guardas una película en el PC y aparece en el móvil.
**Hecho:** la app de Android es la misma que la del PC (un solo código) con la barra inferior **Inicio · Buscar · Géneros · Más**. **Acceso** con la pregunta del diseño («¿La tengo o no la tengo?») y solo la entrada de consulta; **Buscar** con cuadrícula de **3 columnas** y «Todo / Títulos / Actores / Directores» en una fila que se desliza; **Ficha** sin lo que solo tiene sentido en el PC; los enlaces de **FilmAffinity e IMDb** se abren en el navegador del móvil (código nativo propio, sin plugins); el **botón «atrás»** vuelve de la ficha a la lista, de cualquier pestaña a Inicio y desde Inicio sale de la app. **Icono nuevo** (la tira de película dorada del diseño) en Android —adaptable a la forma de cada móvil— y en Windows, que aún tenía el de Flutter; arranque en oscuro y barras del sistema a juego. **APK de 23,5 MB** (solo móviles de 64 bits, todos los actuales), **firmada con una llave propia** guardada fuera del repositorio en `Documents\Videoteca-firma` (**haz una copia**: sin ella, las actualizaciones no se instalan encima) y en los secretos de GitHub, así que cada versión publica ya el instalador de Windows **y** la APK. Prueba automática del recorrido en el móvil (detectó que en «Más» no se veía el efecto al pulsar).
**Probado en tu móvil:** instalada la APK, entrada con la contraseña común (el teclado del móvil cambiaba una letra sin que se viera: con el ojo se comprueba), descarga del catálogo, todas las pantallas, enlaces, «atrás» y sin internet. **Prueba final (5/10/2026):** instalada la v0.3 en el PC y en el móvil; el PC publicó él solo la **versión 3** del tablón (5.527 películas) y el móvil la recibe. Para comprobar la contraseña común desde el PC sin enseñarla: `tool/comprobar_contrasena.dart` (también como `.exe` suelto).

---

## Fase 4 · Cierre

### ☑ Día 17 — Estadísticas y exportación
- Estadísticas: por género, década y país, directores y actores más presentes, sagas incompletas.
- Exportar a Excel y copia de seguridad del catálogo.

**Hecho:** pantalla **Estadísticas** (en el PC y en el móvil): resumen (películas, horas de cine, espacio en disco, media de estrellas, sagas), la más antigua y la más larga, **gráfico por décadas** y listas con barras de **géneros, países, directores y actores**; cada barra abre el Catálogo ya filtrado (la ruta del Catálogo acepta ahora `desde`/`hasta` para las décadas). **Sagas incompletas** («Tienes 3 de 4» y cuáles te faltan): sin más datos se deducen por el número de cada película; con el botón **Comprobar en TMDB** (solo en el PC) se mira cuántas tiene de verdad cada saga (solo las ya estrenadas) y se guarda en `sagas.json`. Con tu colección: 758 sagas comprobadas en 77 s, 755 reconocidas, 430 completas y 270 incompletas. Se cuenta bien aunque una ficha tenga el año mal (tu *Licencia para matar* dice **1985** y es de **1989**). **Exportar a Excel** (Estadísticas y Ajustes): un `.xlsx` hecho por la propia app, sin complementos, con una fila por película y 26 columnas, la primera fila fija, filtros y enlaces a FilmAffinity e IMDb (5.526 películas = 3 MB en menos de medio segundo; comprobado abriéndolo con Excel). **Copia de seguridad** (Ajustes): un `.zip` con las fichas, el registro de cambios (con las carátulas para deshacerlos), los ajustes y las miniaturas (136 MB en 4,5 s); **tus claves nunca van dentro**. **Restaurar una copia**: la app se cierra y se vuelve a abrir sola con los datos de la copia, conserva las claves y la conexión con el tablón de este PC y guarda antes la base de datos actual como `videoteca-antes-de-restaurar.sqlite`. Los diálogos «Guardar como» y «Abrir» son los de Windows (sin plugins).

### ☑ Día 18 — Pulido
- Rendimiento con las 5.541 películas.
- Estados especiales: sin internet, disco desconectado, sin resultados, sin carátula.
- Mensajes de error claros y accesibilidad.

**Hecho:** **rendimiento** medido con una copia de tu base (5.526 películas; prueba `test/rendimiento_test.dart`): la app abre la ventana en menos de 2 s; preparar el buscador bajó de 270 a 140 ms y **ya no frena la pantalla** (se hace en otro hilo junto con la carga del catálogo, también después de cada guardado); limpiar textos para buscar es más rápido y se recuerda, así que actores, filtros, pendientes y estadísticas tardan entre un 20 y un 55 % menos; las miniaturas pequeñas (vista de lista) se cargan a su tamaño. **Estados especiales**: aviso común cuando no hay nada que enseñar — colección vacía (explica si se está cargando, revisando la carpeta, descargando o qué hacer, con botón), búsqueda sin resultados (con consejo y «Quitar los filtros»); en consulta **sin internet**, Inicio dice que estás viendo el catálogo descargado y de cuándo es, con «Reintentar»; una carátula dañada se ve como la provisional (y la marca «NUEVA» sale también sobre las carátulas de verdad). **Errores claros**: los fallos inesperados se explican en español («El archivo está abierto en otro programa (…). Ciérralo y vuelve a intentarlo», «No queda espacio en el disco», «Sin conexión a internet») en vez del mensaje técnico en inglés, también al leer archivos con Windows. **Accesibilidad**: pruebas nuevas con la letra al **200 %** en el PC y en el móvil (se arreglaron Ajustes, el desplegable de orden y la fila de recientes del móvil, que se salían), botones con nombre y del tamaño de un dedo, y contraste de los textos en modo oscuro y claro; el lector de pantalla anuncia cada película como «Título, año · género, botón»; los nombres de la ficha (director, reparto) se pueden elegir con el tabulador y abrir con Intro.

### ☑ Día 19 — Instaladores y documentación
- Instalador de Windows definitivo.
- GitHub Actions: cada versión genera automáticamente el `.exe` y la `.apk` en *Releases*.
- README con instrucciones para que **otras personas** monten su propia colección.

**Decidido:** el repositorio del código pasa a ser **público** (para que otras personas descarguen los instaladores y para que la app pueda avisar de versiones nuevas) y **no** se publica en Google Play (25 $, DNI, prueba cerrada con 12 personas durante 14 días y los revisores necesitarían la contraseña común). Ojo para 2027: Google exigirá que hasta las APK instaladas desde fuera de Google Play sean de un desarrollador registrado; para familia y amigos hay una cuenta gratuita de «distribución limitada» (hasta 20 móviles), apuntado en *Ideas*.
**Hecho:** **instalador definitivo**: imágenes propias en el asistente (la tira de película dorada sobre el fondo oscuro), bienvenida en español que explica que si ya tienes Videoteca se actualiza sin perder nada, versión, autor y enlaces en *Aplicaciones instaladas*, y el `.exe` dice en sus propiedades «Videoteca · Ayoamaro». Si la app está abierta al actualizar, el instalador la **cierra y la vuelve a abrir**; al **desinstalar** pide cerrarla y **pregunta si borra también los datos** de la app (por defecto no: si la vuelves a instalar, todo sigue igual; las películas nunca se tocan). La app **ya no se abre dos veces** (un doble clic impaciente abría dos ventanas trabajando con el mismo catálogo): la segunda trae al frente la primera. **GitHub Actions**: al subir una etiqueta comprueba que coincide con la versión de la app y que están las novedades, compila el instalador y la APK, **instala de verdad la app en una máquina de GitHub, la abre, comprueba que no se abre dos veces, la actualiza con ella abierta (comprobando que la cierra y la vuelve a abrir) y la desinstala** (sin borrar los datos), y publica todo con las huellas SHA-256; también se puede lanzar a mano sin publicar nada (así se ha probado hoy: la primera vez el instalador fallaba al arrancar por el formato de las imágenes, ya arreglado). Para quien monte su propia versión, el tablón propuesto y el repositorio de versiones ya no van escritos a fuego. **Aviso de versión nueva**: la app mira en GitHub (al abrir y cada 12 h) si hay una versión más nueva; en Inicio sale una franja dorada («Hay una versión nueva de Videoteca: la 1.0») con *Novedades y descarga* (las notas de la versión y el botón que baja el instalador en el PC o la APK en el móvil) y *Más tarde*; también en **Ajustes → Acerca de Videoteca** (versión, «Al día», enlace a las instrucciones y el aviso de TMDB que piden sus condiciones). **Revisar una a una** las dudosas de Completar mi colección (lo elegiste hoy): la app abre cada una como en Completar ficha, la busca, enseña las parecidas y rellena los campos vacíos; guardas o *Saltar* y pasa a la siguiente (tú ya no tenías ninguna: las 135 estaban revisadas). **Documentación**: [README](README.md) nuevo para cualquiera, [guía de uso](docs/guia.md) paso a paso (preparar la colección, instalar, claves, completar fichas, qué se guarda en cada archivo, publicar, el móvil, preguntas frecuentes) y [tu propia versión](docs/tu-propia-version.md) (compilar, firmar la APK, publicar con GitHub Actions). **Arreglado**: la comprobación automática de GitHub fallaba desde el día 17 (una prueba escrita solo para Windows) y en Ajustes, FilmAffinity aún decía «Día 11».
**Versión 0.9** preparada (candidata a la 1.0, `docs/novedades/v0.9.md`): instalador y APK compilados y probados en GitHub.

### ☑ Día 20 — Pruebas finales · 🏷 v1.0
- Recorrido completo: película nueva → ficha → guardar → aparece en el móvil.
- Corrección de los últimos fallos.
- 🎉 **Versión 1.0**.

**Al terminar:** 🎉 **v1.0** — la primera versión completa.
**Hecho:** **recorrido completo con tu colección real**: nada más instalar la 0.9 guardaste desde *Completar ficha* las **19 películas nuevas** que habías añadido los días 5 y 7 de octubre, y el PC publicó él solo la **versión 5 del tablón** (5.545 películas) medio minuto después. Descargada como lo hace el móvil, la copia tiene las 19 con sus datos y carátulas y **ni una diferencia** con el catálogo del PC; abierta en modo consulta, salen arriba en *Añadidas recientemente*. **Recorrido de una película nueva en el PC** (con una copia de *Hipnótico*, sin tocar D:, a la que se le vaciaron 8 datos): la app la detectó sola en segundos, la identificó en TMDB (título, año y director), rellenó 5 datos que coinciden **exactamente** con los tuyos, la guardó dentro del archivo y comprobó el vídeo (la productora sale de FilmAffinity y TMDB no tiene su edad: queda en Pendientes, como debe ser). **Arreglado**: en el modo consulta (también en el móvil) quedaba un hueco doble bajo el buscador de Inicio, y lo mismo en *Completar mi colección* sin dudosas; los **temas** escritos con puntos, como los escribes tú («Biográfico. Años 60. Años 70»), se ven uno por uno en la ficha (sin cambiar los archivos); el botón para quitar las estrellas decía «Sin estrellas» y parecía que la película no tenía (ahora, «Quitar estrellas»); las novedades de una versión enseñaban los asteriscos de las cursivas (arreglado para las siguientes; las de la 1.0 ya no llevan). **Versión 1.0** publicada en GitHub: instalador y APK compilados, instalados y probados allí. Tu app 0.9 de prueba ya avisa: «Hay una versión nueva de Videoteca: la 1.0 (tienes la 0.9.0)», con las novedades y el botón de descarga. Tu móvil seguía en la 0.3, que aún no avisaba de versiones nuevas: desde la 1.0 lo hace solo.

---

## Fase 5 · Red de casa

**Objetivo:** que en **cualquier PC de casa** (no solo en el PC1, que tiene el disco) se pueda **reproducir, abrir la carpeta, copiar la ruta y copiar la película** a un disco o pendrive de ese PC, entrando al disco por la red y **solo para leer**. El móvil sigue siendo para consultar: dice en qué carpeta está cada película.

**Cómo está montado en tu casa (visto el 11/10/2026):** el PC1 se llama `AYO-PC` y comparte `Multimedia` (= `D:\!Multimedia`, carpeta oculta). Dentro, `Películas` tiene una unión (un «atajo» de Windows) a cada carpeta de grupo de `D:\`; `Series`, `Documentales` y `Programas de TV` llevan a `E:\Vídeos`. Así, *Factory Girl* es `D:\Drama y Musical\Drama\Factory Girl (2006).mp4` en el PC1 y `\\AYO-PC\Multimedia\Películas\Drama y Musical\Drama\Factory Girl (2006).mp4` desde los demás: **la parte final es la misma** y el tablón ya la lleva; solo cambia el principio. La cuenta *Invitado* está activada y las carpetas dan a *Todos* permiso de solo lectura. Como `!Multimedia` está oculta, la app del PC1 no cuenta las películas dos veces (no hay que quitarle la marca de oculta).

**Antes de empezar (tarea tuya, sin programar):**
- En el PC1: *Panel de control → Redes e Internet → Centro de redes y recursos compartidos → Cambiar configuración de uso compartido avanzado → Todas las redes → Desactivar el uso compartido con protección por contraseña* (Windows pide permiso de administrador). Así se entra sin usuario ni contraseña.
- Comprobar que el recurso compartido solo deja leer: *`D:\!Multimedia` → Propiedades → Compartir → Uso compartido avanzado → Permisos → Todos: solo «Leer»*. Es lo que impide modificar por la red (en las carpetas de `D:\`, Windows deja modificar a cualquier usuario con cuenta).
- Mirar qué Windows tienen el PC2 y el PC3 (*Configuración → Sistema → Información*). Windows 11 reciente (24H2 o posterior) bloquea por seguridad la entrada como invitado: en esos PC no se baja la seguridad; se guarda la contraseña **una vez** («Recordar mis credenciales») y nadie vuelve a escribirla.

### ☑ Día 21 — La ruta de red
**Objetivo:** que cada PC sepa por dónde ve él las películas.
- **PC1 (administrador):** en Ajustes, sección nueva **Red de casa** con la ruta para los demás PC. La app la **propone sola** buscando entre las carpetas compartidas del PC la que lleva a las películas (en tu caso `\\AYO-PC\Multimedia\Películas`); se puede cambiar o dejar vacía. Antes de aceptarla comprueba unas cuantas películas del catálogo por esa ruta.
- La ruta viaja **cifrada en el tablón**, sin romper nada en las apps 1.0 ya instaladas (simplemente no la usan).
- **PC2/PC3 (consulta en Windows):** en Ajustes, **Películas en la red**: usa la del tablón si funciona; si no, se elige la carpeta a mano (vale `\\…` o una letra como `Z:`). Comprueba que es la buena («Encontradas 20 de 20»). Cada PC guarda la suya.
- Estado de la red **sin que la app se quede colgada** (la comprobación va aparte y con tiempo límite): disponible, PC1 apagado o sin red, o pide contraseña.
- Todo genérico: nada fijo a `AYO-PC` ni a `Multimedia`.

**Al terminar:** en un PC de consulta, Ajustes dice «Películas en la red: `\\AYO-PC\Multimedia\Películas` · disponible».
**Cómo se prueba:** desde este PC, con una carpeta de datos aparte en modo consulta y la ruta de red real (solo leer, sin tocar tus películas).
**Hecho:** **en el PC1**, *Ajustes → Red de casa* busca sola entre las carpetas que comparte el PC y **propone `\\AYO-PC\Multimedia\Películas`** («encontradas 20 de 20 películas de prueba», en menos de 1 s); con «Usar esta ruta» queda guardada y se publica **cifrada dentro del índice del tablón** (2 s después; si solo cambia la ruta, se sube solo el índice). Una carpeta de este PC (`D:\…`) no se acepta: los demás no la ven así. Las apps 1.0 ya instaladas leen el tablón igual que antes (el formato no cambia; simplemente no ven la ruta). **En un PC de consulta**, *Ajustes → Películas en la red* usa la del tablón y la comprueba sola (y cada minuto); también se puede elegir otra (`\\…` o una unidad como `Z:`) y volver a la del administrador. Estados: **Disponible**, **Sin conexión** (PC1 apagado o sin red), **Pide contraseña** (con el botón «Abrir en el Explorador» y qué hacer) y **No se encuentra** (la carpeta no es la buena). La comprobación va aparte: primero se «llama» al PC con un límite de 3 s, así un PC apagado nunca deja la app esperando (Windows tardaría hasta medio minuto). **Probado con tu red real** y una copia de tus datos en modo consulta: «`\\AYO-PC\Multimedia\Películas` · Disponible · Publicada por el administrador · encontradas 20 de 20»; con un PC que no existe, «Comprobando…» y a los 3 s «Sin conexión», sin que la app se pare. Lo que no se puede probar desde aquí es «Pide contraseña» (este PC entra con tu propio usuario): queda para el día 24 en el PC2/PC3. Herramienta para probarlo desde la terminal: `dart run tool/probar_red.dart D:\ [ruta]`.

### ☑ Día 22 — La ficha en todos los aparatos
**Objetivo:** Reproducir, Abrir carpeta y Copiar ruta funcionando igual en el PC1 y en los PC de la red.
- **PC2/PC3 con la red disponible:** «Dónde está» con la ruta **de ese PC**, **Reproducir** (con el reproductor de ese PC), **Abrir carpeta** (el Explorador con la película ya seleccionada) y **Copiar ruta**. La **carátula grande** se lee del archivo por la red, como en el PC1 (ahora en consulta solo se ve la miniatura).
- **Avisos claros:** PC1 apagado → botones desactivados y explicación; pide contraseña → botón **Abrir en el Explorador** (Windows la pide y la recuerda) y después todo funciona; película que ya no está en esa ruta (movida o borrada en el PC1 y el catálogo aún sin actualizar) → lo dice.
- **PC fuera de casa o sin la red configurada:** como el móvil.
- **Móvil:** «Dónde está» más sencillo, solo la carpeta: **Drama y Musical › Drama** (con la calidad y el tamaño, como ahora). Sin ruta de red ni botones.
- Pruebas automáticas de la ficha en los tres casos (PC1, PC de la red y móvil).

**Al terminar:** desde un PC de consulta, *Factory Girl* se reproduce con un clic.
**Hecho:** la ficha sabe **dónde está cada película desde el aparato en el que estás**. **En el PC1**, como siempre: la ruta del disco y los tres botones. **En un PC de la red**, «Dónde está» enseña la ruta **de ese PC** (`\\AYO-PC\Multimedia\Películas\Drama y Musical\Drama\Factory Girl (2006).mp4`), **Reproducir** abre la película con el reproductor de ese PC (como un doble clic en el Explorador), **Abrir carpeta** abre el Explorador con la película ya seleccionada y **Copiar ruta** copia la ruta de red; la **carátula grande** se lee del archivo por la red (sin red, la miniatura). **Reproducir y Abrir carpeta van aparte** (en otro hilo) y antes miran, con 3 s de límite, que el PC contesta y que la película sigue ahí: un PC1 apagado nunca deja la app colgada. **Avisos:** PC1 apagado o fuera de casa → «No se llega al PC de las películas…», Reproducir y Abrir carpeta desactivados (la ruta se puede copiar) y botón **Comprobar**; **pide contraseña** → botón **Abrir en el Explorador** (abre el Explorador en la carpeta de red: Windows pide usuario y contraseña y, con «Recordar mis credenciales», los guarda) y, **al volver a la app, se comprueba sola** y todo funciona; película movida o borrada en el PC1 → «No se encuentra la película en esta ruta…»; carpeta de red equivocada → lo dice y lleva a Ajustes. **En el móvil** (y en un PC sin la red de casa), «Dónde está» solo dice la carpeta: **Drama y Musical › Drama**, con la calidad, el tamaño y la fecha, sin ruta ni botones. **Probado con tu red real** y una copia de tus datos en modo consulta: *Factory Girl* con la ruta de red, los botones activos y la carátula grande leída por la red; con un PC que no existe, el aviso y los botones desactivados; sin ruta de red, «Drama y Musical › Drama». El mecanismo nuevo de abrir (desde otro hilo) se ha probado con un archivo inofensivo; el clic en Reproducir con la película, contigo delante. 4 pruebas automáticas nuevas de la ficha (PC1, PC de la red —apagado, contraseña, película movida—, PC sin red y móvil).

### ☑ Día 23 — Copiar película
**Objetivo:** copiar una película a cualquier disco o pendrive del PC donde estás.
- Botón **Copiar película** en la ficha (PC1 y PC de la red).
- Ventana **¿Dónde quieres guardarla?** con las unidades de ese PC: nombre, si es disco interno o USB y espacio libre. Oculta las que no tienen nada dentro (lectores de tarjetas vacíos) y, en el PC1, el propio disco de la colección (una copia dentro saldría como película nueva duplicada).
- Se guarda en una carpeta **Películas** en la raíz de la unidad elegida (se crea si no existe), o donde digas con **Elegir otra carpeta…**.
- **Avisos antes de empezar:** no cabe; pendrive en formato FAT32 con una película de más de 4 GB (no la admite aunque haya espacio); ya existe en el destino (pregunta si reemplazarla).
- **Copia en segundo plano** con barra de progreso, velocidad y tiempo restante (también en el menú); se puede seguir usando la app. **Cancelar** borra el trozo a medias. Al terminar comprueba que la copia está completa y ofrece **Abrir carpeta**. Si se quita el pendrive o se apaga el PC1 a mitad, lo explica y no deja un archivo roto.
- **Una película cada vez** (copiar varias de golpe queda en *Ideas*).
- El disco de las películas **solo se lee**: nunca se escribe en él.

**Al terminar:** *Factory Girl* → Copiar película → pendrive → en unos segundos está en `E:\Películas`.
**Cómo se prueba:** copiando películas pequeñas por la red a una carpeta temporal (también cancelar a mitad, destino lleno y «ya existe»).
**Hecho:** botón **Copiar película** en «Dónde está» (en el PC1 y en los PC de la red; en el móvil y en un PC sin la red, no). Abre **¿Dónde quieres guardarla?** con las unidades de ese PC: nombre, si es pendrive, disco USB, tarjeta o disco interno, formato y espacio libre (con su barrita). No salen los lectores de tarjetas vacíos, los CD ni las unidades de red, y en el PC1 tampoco el disco de la colección (lo dice: «en él no se escribe nada»). Si conectas un pendrive con la ventana abierta, aparece solo. Las que no valen salen apagadas y dicen por qué: **«No cabe: faltan 2,1 GB»**, **«Formato FAT32: no admite archivos de más de 4 GB»** o protegida contra escritura; si la película ya está ahí, **«Ya está copiada aquí»** y, al elegirla, pregunta si reemplazarla. Se guarda en **`Películas`** en la raíz de la unidad (se crea sola) o con **Elegir otra carpeta…** (no deja elegir el disco de la colección ni la carpeta de las películas del otro PC). La copia va **en segundo plano**: barra con %, «640 MB de 2,2 GB · 213 MB/s · faltan unos 20 s» en la ficha y en el **menú** (pulsándolo, vuelves a la ficha), y se puede seguir usando la app; **una película cada vez**. Mientras se copia, el archivo se llama «… .mp4**.parcial**» y solo al final, **comprobado** (tamaño y trozos del principio, el medio y el final iguales a la original), pasa a llamarse como la película, con su misma fecha: así nunca queda un .mp4 roto. **Cancelar** (pregunta antes) borra lo copiado; si se cierra la app copiando, **pregunta** y, si cierras, cancela y borra. Al terminar: aviso «copiada en X:\Películas» con **Abrir carpeta**. Si se quita el pendrive, se apaga el PC1 o se llena el disco a mitad, lo explica («Se ha perdido la conexión con el PC de las películas…») y borra el trozo (si no puede, porque ya no está el pendrive, lo dice, y se borra solo en la próxima copia a esa carpeta). El disco de las películas solo se lee. **Probado de verdad** desde una copia de tus datos: por la red (`\\AYO-PC\…`) a una carpeta temporal, *Las Navidades de Casper* idéntica (mismo SHA-256 y fecha), «ya existe» y reemplazar, cancelar a mitad sin dejar nada, *Infinity War* (2,2 GB) a ~210 MB/s, cerrar la app copiando; en el PC1, el disco D: no sale y *Factory Girl* (1,9 GB) se copió en 9,5 s, idéntica; en D: no se escribió nada. 18 pruebas automáticas nuevas (copiador con archivos de verdad y pantallas del PC1, PC de la red y al cerrar). **Queda para el día 24, con un pendrive de verdad:** quitarlo a mitad, uno en FAT32 con una película de más de 4 GB y uno lleno (aquí no hay ningún pendrive ni se puede llenar un disco), y apagar el PC1 a mitad de una copia.

### ☐ Día 24 — Pruebas en casa · 🏷 v1.1
- **Recorrido real:** instalar la 1.1 en el PC1 (propone y publica la ruta), en el PC2/PC3 (Reproducir, Abrir carpeta, Copiar ruta y Copiar película a un pendrive) y en el móvil («Dónde está»).
- Casos: PC1 apagado, con y sin contraseña, Windows 10 y 11.
- Copiar película con un pendrive de verdad: quitarlo a mitad, uno en FAT32 con una película de más de 4 GB, uno casi lleno y apagar el PC1 a mitad de una copia.
- **Documentación:** en la [guía](docs/guia.md), «Usar Videoteca en otros PC de casa» (compartir la carpeta solo para leer y sin contraseña, y qué hacer si Windows la pide), y las novedades `docs/novedades/v1.1.md`.
- 🎉 **v1.1** publicada en GitHub (instalador y APK).

**Necesito de ti:** estar delante del PC2 o el PC3 y tener a mano un pendrive.
**Al terminar:** 🎉 **v1.1** — cualquier PC de casa ve, reproduce y copia tus películas.

**Hecho hasta ahora (12/10):** versión **1.1.0** preparada: [novedades](docs/novedades/v1.1.md) y en la [guía](docs/guia.md#12-usar-videoteca-en-otros-pc-de-casa) el apartado «Usar Videoteca en otros PC de casa» (red privada, compartir solo para leer, entrar sin contraseña, qué hacer si la pide, copiar una película, Windows 7). Comprobado en el PC1: la carpeta `Multimedia` se comparte **solo para leer** («Todos: Leer»), la red es **privada** y deja entrar como invitado. **Novedad que ha salido al preparar las pruebas:** en los PC que no dejan entrar como invitado (Windows 11 24H2 o posterior, y las ediciones Enterprise/Education) el Explorador **no pide la contraseña**: solo dice que «las directivas de seguridad bloquean el acceso de invitados». Por eso, con «Pide contraseña», la app tiene ahora **Escribir usuario y contraseña…**: entra con ellos y los deja guardados en Windows (como «Recordar mis credenciales»; la app no los guarda); dice si la contraseña es incorrecta, si la cuenta no existe en el PC1 o si no tiene contraseña, y recuerda que **el PIN no vale** (hace falta la contraseña de la cuenta). Probado de verdad contra la carpeta compartida de este PC. **Windows 7 u 8 (o de 32 bits):** la app no puede funcionar (Flutter necesita Windows 10 u 11 de 64 bits); el instalador lo explica y la guía dice cómo abrir las películas desde el Explorador. Versión de prueba (instalador + APK) compilada en GitHub sin publicar, y una **lista de pruebas** para el móvil donde marcar cada resultado (Claude la lee al volver). 194 pruebas automáticas.
**Falta (contigo delante):** instalar la 1.1 de prueba en el PC1 y pulsar «Usar esta ruta» en *Ajustes → Red de casa*; las pruebas del PC2/PC3 (y un PC con Windows 7 si lo hay) y del móvil con la lista; y, si todo va bien, publicar la v1.1.

---

## Decisiones pendientes

| Decisión | Se resuelve el |
|---|---|
| ~~Rangos de Rotten Tomatoes → estrellas~~ | ☑ Día 10: tramos de 20 % |
| ~~Frases exactas de clasificación por edades~~ | ☑ Día 10: EE. UU. primero, si no España |
| ~~Temas y premios de FilmAffinity en lote o solo en nuevas~~ | ☑ Día 13: repaso aparte, contigo delante |
| ~~Contraseña común para los usuarios~~ | ☑ Día 14: la eliges tú en Ajustes (no se guarda) |
| ~~Publicar la APK en Google Play (25 €, opcional)~~ | ☑ Día 19: no, se sigue con la APK de GitHub |
| ~~Qué enseña «Dónde está» en el móvil~~ | ☑ 11/10: solo la carpeta (Drama y Musical › Drama), sin ruta de red ni botones |
| ~~Copiar varias películas de golpe~~ | ☑ 11/10: de momento una a una; varias, en *Ideas* |
| ~~Red de casa: entrar como invitado o con la contraseña guardada en cada PC~~ | ☑ 12/10: los dos. Como invitado donde Windows lo deja; donde no (Windows 11 reciente), la contraseña se escribe una vez en la app y la guarda Windows |

## Ideas para después de la v1.0

- **Antes de 2027:** registrar la app (gratis) en la cuenta de «distribución limitada» de Android, porque Google exigirá que hasta las APK de fuera de Google Play sean de un desarrollador registrado (hasta 20 móviles).
- Capturas de pantalla en el README.
- Notificación en el móvil al añadir películas.
- Marcar películas como vistas y nota personal.
- Varios discos o colecciones.
- Publicar también en el tablón las sagas comprobadas en TMDB, para que el móvil cuente igual que el PC (ahora las deduce por el número de cada película).
- Copiar varias películas de golpe: marcarlas mientras se navega y copiarlas una detrás de otra (no va más lento que de una en una).
- Probar a reproducir en el móvil desde la red de casa con VLC para Android (solo en casa y con el PC1 encendido).
