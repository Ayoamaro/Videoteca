# Guía de uso de Videoteca

Esta guía explica cómo montar tu propia colección con Videoteca, desde ordenar las películas hasta consultarlas en el móvil y verlas desde los demás PC de casa. No hace falta saber programar.

**Índice**

1. [Qué necesitas](#1-qué-necesitas)
2. [Prepara tu colección](#2-prepara-tu-colección)
3. [Instala la app en el PC](#3-instala-la-app-en-el-pc)
4. [Primer arranque](#4-primer-arranque)
5. [Buscar y explorar](#5-buscar-y-explorar)
6. [Las claves gratuitas de TMDB y OMDb](#6-las-claves-gratuitas-de-tmdb-y-omdb)
7. [Completar los datos de las películas](#7-completar-los-datos-de-las-películas)
8. [Qué se guarda dentro de cada archivo](#8-qué-se-guarda-dentro-de-cada-archivo)
9. [Pendientes, estadísticas, Excel y copias de seguridad](#9-pendientes-estadísticas-excel-y-copias-de-seguridad)
10. [Publicar el catálogo para el móvil](#10-publicar-el-catálogo-para-el-móvil)
11. [El móvil y otros PC (modo consulta)](#11-el-móvil-y-otros-pc-modo-consulta)
12. [Usar Videoteca en otros PC de casa](#12-usar-videoteca-en-otros-pc-de-casa)
13. [Actualizar y desinstalar](#13-actualizar-y-desinstalar)
14. [Preguntas frecuentes](#14-preguntas-frecuentes)

---

## 1. Qué necesitas

- Un **PC con Windows 10 u 11** de 64 bits: es el «administrador», donde están las películas y donde se completan las fichas.
- Tus películas en **`.mp4`** (también valen `.m4v`, que es el mismo formato), en un disco o una carpeta.
- Para completar datos: conexión a internet y dos claves gratuitas (TMDB y OMDb, [apartado 6](#6-las-claves-gratuitas-de-tmdb-y-omdb)). Para FilmAffinity, cualquier navegador (Edge, Chrome, Firefox…).
- Para consultar desde el móvil: una cuenta gratuita de **GitHub** ([apartado 10](#10-publicar-el-catálogo-para-el-móvil)) y móviles **Android 7 o posterior** de 64 bits (todos los de los últimos años). No hay versión para iPhone.
- Los demás PC de casa, también con **Windows 10 u 11** de 64 bits. En Windows 7 u 8 la app no funciona, pero las películas se pueden abrir por la red desde el Explorador ([apartado 12](#pc-con-windows-7-u-8)).

## 2. Prepara tu colección

Videoteca lee una **carpeta principal** (por ejemplo, el disco `D:\` entero) y todas las de dentro. Los nombres de las carpetas se usan para organizar el catálogo:

```
D:\                                 ← carpeta principal
├── Comedias\                       ← grupo
│   ├── Comedia\                    ← género
│   │   ├── Atrapado en el tiempo (1993).mp4
│   │   └── Joy (2015).mp4
│   └── Romance\
│       └── Notting Hill (1999).mp4
└── Acción, Bélico y Western\
    └── Western\
        └── Sin perdón (1992).mp4
```

- La carpeta donde está cada película es su **género** («Comedia», «Western»…) y la de encima, su **grupo**. También vale tener las películas directamente en una carpeta por género (`D:\Comedia\Joy (2015).mp4`).
- Nombra cada archivo como **`Título (Año).mp4`**. Si el archivo no tiene datos dentro, el título y el año se sacan del nombre.
- Windows no deja poner `:` en un nombre de archivo. Puedes usar en su lugar el carácter **`꞉`** (se parece mucho) y la app lo convierte en `:` al mostrar el título: `Misión꞉ Imposible (1996).mp4` → *Misión: Imposible*.
- Las carpetas ocultas o de sistema (como la papelera) se saltan.

**Los datos de cada película van dentro del propio archivo**, en las mismas «propiedades» que enseña Windows (*clic derecho → Propiedades → Detalles*): título, sinopsis (Comentarios), reparto (Artistas), director, año, géneros, estrellas… Si tus archivos ya los tienen, la app los lee tal cual. Si no, la app te ayuda a rellenarlos ([apartado 7](#7-completar-los-datos-de-las-películas)).

**La carátula** también va dentro del archivo. Si alguna película no tiene, la puedes poner desde la app arrastrando una imagen JPEG o PNG (por ejemplo, de 350 × 500 píxeles). La app **nunca pone carátulas por su cuenta**: siempre las eliges tú.

## 3. Instala la app en el PC

1. Descarga `Videoteca-<versión>-instalador.exe` de la [última versión](https://github.com/Ayoamaro/Videoteca/releases/latest).
2. Ábrelo. Si Windows avisa de que es de un «editor desconocido» (el instalador no está firmado), pulsa **Más información → Ejecutar de todas formas**.
3. Sigue los pasos. Se instala solo para tu usuario (en `%LOCALAPPDATA%\Programs\Videoteca`), sin pedir permisos de administrador, y crea un acceso en el menú Inicio (y, si quieres, en el escritorio).

## 4. Primer arranque

1. **¿Cómo quieres entrar?** → elige **Administrar este PC**.
2. **Crea tu contraseña de administrador** (al menos 6 caracteres, dos veces). Se pide solo al entrar; la sesión se queda abierta hasta que pulses *Cerrar sesión* en Ajustes. No se guarda en ningún sitio (solo una huella para comprobarla): si la olvidas, la pantalla de entrada explica cómo crear otra sin perder nada.
3. **¿Dónde guardas tus películas?** → *Elegir carpeta…* y elige la carpeta principal. La app enseña cuántas películas y qué géneros ha encontrado y cuánto tardará en leerlas.
4. **Leer las películas**. La primera vez lee los datos y la carátula de cada archivo (con miles de películas en un disco duro, unos minutos; puedes seguir usando el PC). **Solo lee: no cambia nada.** Las veces siguientes solo lee lo nuevo o lo cambiado.

Los datos de la app (catálogo, miniaturas de las carátulas, ajustes) se guardan en `%LOCALAPPDATA%\Videoteca`. Las películas no se copian ni se mueven.

## 5. Buscar y explorar

- **Inicio**: el buscador (también con **Ctrl + K** desde cualquier pantalla), las añadidas recientemente y los géneros. Busca por título (el español o el original), actor o director, sin importar tildes ni mayúsculas, con palabras a medias y en cualquier orden. «origen 2010» busca título y año.
- **Catálogo**: cuadrícula o lista, con filtros que se combinan (género, carpeta, año, país, estrellas, edad, saga, dirección, reparto) y orden por fecha añadida, título, año o estrellas.
- **Ficha**: todos los datos, con *Dónde está* (ruta, calidad y tamaño) y los botones **Reproducir** (con tu reproductor de Windows), **Abrir carpeta**, **Copiar ruta** y **Copiar película** (a un pendrive u otro disco, [apartado 12](#copiar-una-película)). Pulsa un actor o un director para ver sus otras películas de tu colección.
- **El disco, vigilado**: mientras la app está abierta, en cuanto copias, mueves o borras una película lo detecta. Las nuevas van a **Películas nuevas**; las movidas o renombradas conservan su ficha; las que desaparecen no se borran solas (salen en Pendientes). Si el disco se desconecta, el buscador sigue funcionando y la app avisa.

## 6. Las claves gratuitas de TMDB y OMDb

Para buscar datos en internet hacen falta dos claves gratuitas. Se ponen en **Ajustes → Servicios de datos** (la app comprueba que funcionan) y **se guardan solo en tu PC**.

- **TMDB** (identifica la película; país, guion, fotografía, saga, edad, IMDb): crea una cuenta en [themoviedb.org](https://www.themoviedb.org/signup), entra en [Ajustes → API](https://www.themoviedb.org/settings/api), pide una clave para uso personal y copia la **API Key** (también vale el «token de lectura»).
- **OMDb** (nota de Rotten Tomatoes → estrellas): pide una clave gratuita en [omdbapi.com](https://www.omdbapi.com/apikey.aspx) y actívala desde el correo que te mandan. Permite 1.000 consultas al día.
- **Wikidata** (enlace a FilmAffinity) y **FilmAffinity** no necesitan clave.

## 7. Completar los datos de las películas

Reglas que la app cumple siempre:

- Solo da una película por **identificada** si coinciden el **título**, el **año** (±1) y el **director**. Si hay dudas, no escribe nada y te pregunta.
- En los procesos automáticos solo rellena campos **vacíos**: nunca cambia un dato que ya tienes ni la carátula.
- Cada guardado se **comprueba** (con Windows se vuelven a leer los datos; el vídeo y la carátula tienen que seguir intactos; si algo no cuadra, el archivo vuelve a quedar como estaba) y queda en el **Registro de cambios** (Ajustes), desde donde se puede **deshacer**.

### Editar ficha

En la ficha de cualquier película, **Editar ficha** abre sus datos (leídos del propio archivo). Puedes cambiarlos a mano, poner o cambiar la carátula (arrastrando una imagen a la pantalla o con *Cambiar carátula…*) y usar:

- **Buscar datos en internet**: TMDB, OMDb y Wikidata (título original, sinopsis, reparto, dirección, guion, música, fotografía, productora, país, saga, edad, estrellas y enlaces). Si la película no se identifica sin dudas, te enseña las parecidas para que elijas.
- **Leer de FilmAffinity**: para lo que solo tiene FilmAffinity (temas y premios, y sus géneros o su sinopsis si los prefieres). La app abre la ficha de la película en tu navegador (o su búsqueda, para que entres tú). En la ficha, pulsa **Ctrl + A** y después **Ctrl + C** y vuelve a la app: la lee sola y te enseña lo que trae para que elijas. La app no maneja el navegador ni entra en FilmAffinity por su cuenta (FilmAffinity no lo permite).

Los datos traídos de fuera llevan una etiqueta de color con su origen y no se guardan hasta que pulsas **Guardar en el archivo**.

### Películas nuevas

Cuando copias una película al disco, aparece en **Películas nuevas** y la app busca sola sus datos. Con **Completar ficha**: el título y el año salen del nombre del archivo, los datos encontrados se ponen en los campos vacíos, «¿Cuál es?» te enseña las parecidas si hay varias, y *Leer de FilmAffinity* trae temas y premios. Arrastra la carátula, guarda y pasa sola a la siguiente nueva.

### Completar mi colección

Para rellenar de golpe lo que falta en toda la colección:

1. Marca qué campos rellenar (cada casilla dice cuántas películas lo tienen vacío).
2. Pulsa **Probar con 50 películas** y revisa el resultado (contadores, lista de resultados y Registro de cambios). Si te convence, sigue con 500 o con todas. Cada película tarda un segundo y medio, más o menos, y puedes seguir usando la app (o pausar y seguir otro día).
3. **Deshacer la tanda** deja todos los archivos de esa tanda como estaban.

Las **dudosas** (no coinciden título, año y director, o el archivo no tiene director) y las **no encontradas** se quedan sin tocar. Con **Revisar una a una** la app te las va enseñando: la busca, te propone las parecidas y rellena los campos vacíos; tú compruebas cuál es, guardas (o *Saltar*) y pasa a la siguiente. Es la forma más rápida de completar una colección cuyos archivos todavía no tienen datos.

El **Repaso con FilmAffinity** (sinopsis cortadas y películas sin temas) funciona igual: FilmAffinity se abre solo en tu navegador con cada película, la copias (Ctrl + A, Ctrl + C), revisas, guardas y pasa a la siguiente.

## 8. Qué se guarda dentro de cada archivo

La app escribe en el `.mp4` en el mismo formato que usa Windows, así que los datos se ven también en el Explorador (*Propiedades → Detalles*) y en otros programas:

| En la app | En Windows (Propiedades → Detalles) |
|---|---|
| Título | Título |
| Título original | Subtítulo |
| Sinopsis | Comentarios |
| Reparto | Artistas colaboradores |
| Año | Año |
| Géneros (`Drama. Comedia`) | Género |
| Estrellas | Clasificación |
| Dirección | Directores |
| Productora | Productores |
| Música | Compositores |
| Edad («No recomendado para menores de 12 años») | Clasificación parental |
| Guion | Escritores |
| País | Editor |
| Fotografía | Director de orquesta |
| Temas | Etiquetas |
| Enlace a FilmAffinity / IMDb | Dirección URL del autor / de promoción |
| Premios | Período |
| Saga y nº | Álbum y nº de pista (no se ven en Detalles) |
| Carátula | La miniatura del archivo |

Windows usa «;» para separar varios valores (por ejemplo, varios actores), así que en esos campos la app usa comas.

## 9. Pendientes, estadísticas, Excel y copias de seguridad

- **Pendientes**: películas duplicadas, sin carátula, incompletas, con datos que revisar (por ejemplo, un año imposible), con el nombre fuera de formato o desaparecidas. Cada una se puede marcar como revisada.
- **Estadísticas**: horas de cine, espacio, géneros, décadas, países, directores, actores y **sagas incompletas** (con *Comprobar en TMDB* sabe cuántas partes tiene de verdad cada saga). Cada barra abre el catálogo ya filtrado.
- **Exportar a Excel** (Estadísticas y Ajustes → Datos): un `.xlsx` con una fila por película.
- **Copia de seguridad** (Ajustes → Datos): un `.zip` con el catálogo, el registro de cambios y los ajustes (**sin tus claves**). *Restaurar una copia* vuelve a dejarlo todo como en la copia. Los datos de cada película, además, están siempre dentro de su archivo.

## 10. Publicar el catálogo para el móvil

El catálogo se publica en un **repositorio de GitHub** que hace de «tablón»: los móviles lo descargan de ahí. Es gratis y no hace falta ningún servidor. Todo lo que se sube va **cifrado** con la contraseña común.

1. **Crea una cuenta** en [github.com](https://github.com/signup) si no tienes.
2. **Crea un repositorio nuevo** ([github.com/new](https://github.com/new)), **público** (para que los móviles lo descarguen sin cuenta; lo de dentro va cifrado) y vacío. Un buen nombre: `Videoteca_Tablon`.
3. En la app, **Ajustes → Publicación**:
   - *Repositorio del tablón*: `tu-usuario/Videoteca_Tablon`.
   - *Llave de acceso de GitHub*: pulsa **Crear una llave**; se abre GitHub con casi todo rellenado. En *Repository access* elige **Only select repositories** → tu tablón, comprueba que *Contents* está en **Read and write**, pulsa *Generate token* y copia la llave (`github_pat_…`). Se guarda solo en tu PC.
   - *Contraseña común*: la que pondrán los móviles (al menos 8 letras). **No se guarda en ningún sitio: apúntala.**
4. **Comprobar y publicar**. La primera vez sube todo (con miles de películas, unos minutos). Después la app publica sola unos segundos después de cada cambio, y solo sube lo que ha cambiado.

Si un día quieres que alguien deje de tener acceso, usa **Cambiar contraseña común**: se vuelve a cifrar todo y los móviles tendrán que entrar con la nueva.

## 11. El móvil y otros PC (modo consulta)

**Android**

1. Descarga `Videoteca-<versión>.apk` de la [última versión](https://github.com/Ayoamaro/Videoteca/releases/latest) en el móvil (o pásala por cable, correo…) y ábrela.
2. Android pedirá permiso para **instalar aplicaciones desconocidas** desde el navegador o la app con la que la abras: concédelo (la app no está en Google Play).
3. En **Consultar el catálogo** escribe el **tablón** (`usuario/nombre`, o su enlace de GitHub) y la **contraseña común**. Ojo: algunos teclados cambian letras al escribir contraseñas; toca el ojo para comprobarla.
4. La primera vez se descarga el catálogo con sus carátulas (unos segundos o minutos, según la colección). Queda guardado: se puede consultar **sin internet**, y cada vez que abres la app solo se bajan los cambios.

**Otro PC con Windows**: instala la app igual que en el [apartado 3](#3-instala-la-app-en-el-pc) y elige **Consultar el catálogo**. Si ese PC está en la misma red de casa que el de las películas, también puede reproducirlas y copiarlas ([apartado 12](#12-usar-videoteca-en-otros-pc-de-casa)).

En el modo consulta no se puede cambiar nada: se busca, se miran fichas y, en los PC de casa, se ven y se copian películas. En el móvil, *Dónde está* dice solo la carpeta de cada película (por ejemplo, «Drama y Musical › Drama»).

## 12. Usar Videoteca en otros PC de casa

En los demás PC de casa (en modo consulta), además de buscar, puedes **reproducir** las películas, **abrir su carpeta** y **copiarlas** a un pendrive o un disco de ese PC. Entran al disco del PC de las películas por la red de casa y **solo para leer**: desde ellos no se puede cambiar ni borrar nada.

### En el PC de las películas (una sola vez)

1. **La red de casa, como privada.** *Configuración → Red e Internet →* tu red (Wi-Fi o Ethernet) *→ Perfil de red: Privada*. En una red «pública», Windows no deja que los demás PC vean las carpetas compartidas.
2. **Comparte la carpeta de las películas, solo para leer.** Lo más sencillo es compartir la carpeta principal de la colección (o el disco entero): en el Explorador, clic derecho → *Propiedades → Compartir → Uso compartido avanzado…* → marca *Compartir esta carpeta* → *Permisos* → para *Todos*, deja marcado solo **Leer** (quita *Cambiar* y *Control total*) → *Aceptar*. Ese permiso es el que impide cambiar o borrar películas desde otro PC.
3. **Entrar sin contraseña** (recomendado): *Panel de control → Redes e Internet → Centro de redes y recursos compartidos → Cambiar configuración de uso compartido avanzado → Todas las redes → Desactivar el uso compartido con protección por contraseña* (en Windows 11: *Configuración → Red e Internet → Configuración de red avanzada → Configuración de uso compartido avanzado*). Windows pide permiso de administrador. Así los demás PC entran sin usuario ni contraseña (salvo los que no dejan entrar como invitado, como Windows 11 reciente: mira [Si Windows pide usuario y contraseña](#si-windows-pide-usuario-y-contraseña)).
4. **En Videoteca, *Ajustes → Red de casa***. La app busca sola, entre las carpetas que comparte el PC, la que lleva a las películas, y prueba 20 de ellas: «encontradas 20 de 20 películas de prueba». Si las encuentra todas, **la usa sola** y sale *Disponible* (si no, pulsa **Usar esta ruta**). Se publica **cifrada** en el tablón junto con el catálogo, y los demás PC la usan sin que tengas que hacer nada en ellos. Si no la encuentra, *Escribir la ruta…* (por ejemplo, `\\NOMBRE-DEL-PC\Películas`).

### En los demás PC

1. Instala Videoteca y entra con **Consultar el catálogo** ([apartado 11](#11-el-móvil-y-otros-pc-modo-consulta)).
2. *Ajustes → Películas en la red* dice si este PC llega a las películas y lo vuelve a mirar cada minuto:
   - **Disponible**: todo listo.
   - **Sin conexión**: el PC de las películas está apagado o este PC no está en la red de casa. La app no se queda esperando: lo sabe en unos 3 segundos.
   - **Pide contraseña**: mira el apartado siguiente.
   - **No se encuentra**: se llega al PC, pero en esa carpeta no están las películas.

   Si este PC ve las películas por otro camino (por ejemplo, una unidad de red `Z:`), pulsa *Cambiar…* y elígela; cada PC guarda la suya.
3. En la ficha, *Dónde está* enseña la ruta de la película **desde ese PC** y los botones **Reproducir** (con el reproductor de ese PC), **Abrir carpeta** (el Explorador con la película ya seleccionada), **Copiar ruta** y **Copiar película**. La carátula grande se lee del archivo por la red. Si el PC de las películas está apagado, los botones se desactivan y lo explica; si la película se ha movido o borrado y el catálogo aún no se ha actualizado, también lo dice.

### Si Windows pide usuario y contraseña

Pasa si el PC de las películas tiene la protección por contraseña activada o si el otro PC no deja entrar «como invitado», sin contraseña: **Windows 11 24H2 o posterior** (por seguridad) y las ediciones Enterprise y Education. No hace falta bajar la seguridad de nada; se hace **una vez** en cada PC:

1. En *Ajustes → Películas en la red* (o en la ficha), pulsa **Escribir usuario y contraseña…**.
2. Escribe el usuario y la contraseña de una cuenta del PC de las películas y pulsa **Entrar**:
   - **Usuario**: el nombre de la cuenta (la app le pone delante el nombre del PC: `NOMBRE-DEL-PC\usuario`) o, si es una cuenta de Microsoft, su correo.
   - **Contraseña**: la de la cuenta, **no el PIN** (el PIN solo sirve para entrar en ese PC sentado delante). En una cuenta de Microsoft, la contraseña de Microsoft.
3. La app entra con ellos y los deja guardados en Windows (como «Recordar mis credenciales»): pasa a **Disponible** y nadie tiene que volver a escribirlos, tampoco al reiniciar. La app no guarda la contraseña.

Si algo no cuadra, lo dice: contraseña incorrecta, una cuenta que no existe en ese PC o una cuenta sin contraseña (Windows no deja entrar por la red con ella). También se puede hacer desde el Explorador con **Abrir en el Explorador**, marcando «Recordar mis credenciales» cuando Windows pida la contraseña.

Si no quieres usar tu cuenta, crea una solo para esto en el PC de las películas, con contraseña: *Configuración → Cuentas → Familia y otros usuarios → Agregar otra persona* (o *Agregar cuenta*) *→ No tengo los datos de inicio de sesión de esta persona → Agregar un usuario sin cuenta Microsoft*. Como la carpeta se comparte solo para leer, con esa cuenta tampoco se puede cambiar nada por la red.

### PC con Windows 7 u 8

Videoteca necesita **Windows 10 u 11 de 64 bits** (Flutter, con lo que está hecha, no funciona en versiones anteriores), y el instalador lo avisa. Desde esos PC puedes ver y copiar las películas igual, sin la app: en el Explorador, escribe en la barra de direcciones la ruta de *Ajustes → Red de casa* del PC de las películas (por ejemplo, `\NOMBRE-DEL-PC\Películas`) y busca la película por su carpeta. El catálogo, en el móvil.

### Copiar una película

En la ficha, **Copiar película** abre *¿Dónde quieres guardarla?* con las unidades de ese PC: pendrives, discos USB, tarjetas y discos internos, con su espacio libre. Elige una y la película se guarda en la carpeta **Películas** de esa unidad (se crea sola), o donde quieras con *Elegir otra carpeta…*.

- Antes de empezar avisa si **no cabe**, si la película **ya está copiada** ahí (pregunta si reemplazarla) o si el pendrive está en formato **FAT32** y la película pasa de 4 GB: ese formato no admite archivos tan grandes aunque haya sitio. Para usarlo, formatéalo en **exFAT** (clic derecho en el pendrive → *Formatear…*; **borra lo que tenga**).
- La copia va **en segundo plano**, con su avance, velocidad y tiempo restante en la ficha y en el menú: puedes seguir usando la app. **Una película cada vez.** *Cancelar* borra lo copiado.
- Mientras se copia, el archivo se llama «… .mp4.parcial»; solo al terminar, y **comprobado** que es igual que el original, pasa a llamarse como la película. Si se quita el pendrive o se corta la red a mitad, la app lo explica y nunca deja una película rota.
- En el PC de las películas también funciona, a cualquier otro disco o pendrive. El disco de la colección no sale en la lista: en él no se escribe nada (y una copia dentro saldría como película nueva repetida).

## 13. Actualizar y desinstalar

- La app **avisa sola** cuando hay una versión nueva (en Inicio, y en *Ajustes → Acerca de Videoteca*). *Novedades y descarga* enseña lo que cambia y baja el instalador (en el PC) o la APK (en el móvil). Se instalan **encima** de la versión que tienes y no se pierde nada; en el PC, el instalador cierra la app y la vuelve a abrir.
- **Desinstalar en Windows**: *Configuración → Aplicaciones → Videoteca → Desinstalar*. Al final pregunta si quieres borrar también los datos de la app (catálogo, miniaturas, registro de cambios, ajustes); si piensas volver a instalarla, di que no. **Tus películas no se tocan nunca.**

## 14. Preguntas frecuentes

**¿La app cambia mis películas?**
Solo escribe dentro de un archivo cuando tú guardas una ficha (o lanzas *Completar mi colección*), y solo los datos: el vídeo no se toca. Después de cada escritura se comprueba que el vídeo y la carátula siguen intactos; si algo falla, el archivo vuelve a quedar byte a byte como estaba. Todo queda en el Registro de cambios y se puede deshacer.

**¿Por qué una película sale como «dudosa»?**
Porque no coinciden a la vez título, año y director con ninguna película de TMDB: por ejemplo, el archivo no tiene director todavía, el año está mal o hay dos películas con el mismo título. Revísalas con *Revisar una a una* en Completar mi colección.

**FilmAffinity me pide «verificar que soy un ser humano».**
Es la protección de FilmAffinity: márcala en tu navegador, como en cualquier web. La app no entra en FilmAffinity: solo lee la ficha que copias tú.

**«Leer de FilmAffinity» dice que lo copiado no sirve.**
Tiene que ser la ficha de la película (no la búsqueda), en español (`filmaffinity.com/es/…`) y copiada entera: pulsa Ctrl + A y después Ctrl + C en la página. Si sigue sin leerla, pulsa *Leer lo copiado*.

**OMDb dice que he llegado al límite.**
La clave gratuita permite 1.000 consultas al día. *Completar mi colección* deja las estrellas para el día siguiente y sigue con lo demás.

**He olvidado la contraseña de administrador.**
En la pantalla de entrada, *¿La has olvidado?* explica qué archivo borrar para crear otra. No se pierde nada.

**He olvidado la contraseña común.**
No se puede recuperar (no se guarda en ningún sitio). Pon una nueva con *Ajustes → Publicación → Cambiar contraseña común* y dásela a quien quieras.

**El disco está desconectado.**
La app lo indica con una franja y un punto rojo en el menú. Puedes seguir buscando; *Reproducir* y *Abrir carpeta* esperan a que vuelva.

**Otro PC de casa dice «Sin conexión» con el PC de las películas encendido.**
Comprueba que los dos PC están en la misma red, que en el de las películas la red es **privada** y que la carpeta sigue compartida (en el otro PC, escribe `\\NOMBRE-DEL-PC` en la barra del Explorador: tiene que salir la carpeta). Si el PC de las películas está en suspensión, los demás tampoco llegan: tiene que estar encendido.

**¿Se puede abrir la app dos veces?**
No: si ya está abierta, al abrirla otra vez se trae al frente la que hay.

**¿Y en iPhone o Mac?**
De momento no hay versión. La app está hecha con Flutter, que también funciona en iOS y macOS, pero haría falta prepararla y probarla.
