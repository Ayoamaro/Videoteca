# 🎬 Videoteca

**El catálogo de tu colección de películas, en el PC y en el móvil.**

Videoteca recorre la carpeta (o el disco) donde guardas tus películas `.mp4`, lee los datos y la carátula que lleva cada archivo y te deja buscarlas al instante: por título, título original, actor o director. Rellena las fichas que faltan con datos de internet, los guarda **dentro de cada archivo** (como hace Windows en *Propiedades → Detalles*) y publica el catálogo, **cifrado**, para consultarlo desde el móvil sin servidores ni cuotas.

- **Windows** (administrador): escanea el disco, vigila las películas nuevas, completa fichas, publica.
- **Android** y otros PC (consulta): ¿la tengo o no la tengo? Buscar, ver fichas y carátulas, también sin internet.

Es gratis, de código abierto (licencia [MIT](LICENSE)) y está en español.

## Descargar

Todo está en la [última versión](https://github.com/Ayoamaro/Videoteca/releases/latest):

| Para | Archivo | Cómo se instala |
|---|---|---|
| Windows 10 u 11 (64 bits) | `Videoteca-<versión>-instalador.exe` | Ábrelo. Se instala solo para tu usuario, sin pedir permisos de administrador. |
| Android 7 o posterior (64 bits) | `Videoteca-<versión>.apk` | Ábrelo en el móvil y permite «instalar aplicaciones desconocidas» (no está en Google Play). |

Las versiones nuevas se instalan encima y no se pierde nada. La propia app avisa cuando hay una.

> Windows puede avisar de que el instalador es de un editor desconocido (no está firmado): pulsa *Más información → Ejecutar de todas formas*.

## Cómo funciona, en cinco pasos

1. **Ordena tus películas** así: `<carpeta principal>\<grupo>\<género>\Título (Año).mp4` (también vale una sola carpeta por género). Los géneros salen de los nombres de las carpetas.
2. **Instala la app en el PC**, elige *Administrar este PC*, crea tu contraseña de administrador y elige la carpeta principal. La app lee todas las películas (la primera vez tarda unos minutos; solo lee, no cambia nada).
3. **Pon las claves gratuitas** de [TMDB](https://www.themoviedb.org/settings/api) y [OMDb](https://www.omdbapi.com/apikey.aspx) en *Ajustes → Servicios de datos* y rellena lo que falta con **Completar mi colección**. Solo se escribe cuando título, año y director coinciden, nunca se pisa un dato que ya tengas y todo se puede deshacer.
4. **Publica el catálogo** en *Ajustes → Publicación*: un repositorio de GitHub tuyo (gratis) y una contraseña común. Se publica solo, cifrado, cada vez que cambia algo.
5. **En el móvil**, instala la APK y entra con tu tablón y la contraseña común.

La guía completa, paso a paso, está en **[docs/guia.md](docs/guia.md)**.

## Qué hace

- **Buscador instantáneo** (Ctrl + K): sin importar tildes ni mayúsculas, con palabras a medias, «spiderman» = «Spider-Man».
- **Catálogo con filtros** combinables: género, carpeta, año, país, estrellas, edad, saga, dirección y reparto.
- **Ficha** con sinopsis, reparto, premios, enlaces a FilmAffinity e IMDb y *Dónde está* (reproducir, abrir la carpeta).
- **Vigila el disco**: las películas nuevas aparecen solas con sus datos ya buscados; las movidas conservan su ficha.
- **Completa las fichas** con TMDB, OMDb (Rotten Tomatoes), Wikidata y FilmAffinity, y las guarda dentro del `.mp4` comprobando después que el vídeo y la carátula quedan intactos. **Registro de cambios** con deshacer.
- **Pendientes**: duplicadas, sin carátula, incompletas y nombres fuera de formato.
- **Estadísticas** (géneros, décadas, países, directores, actores, sagas incompletas), **exportar a Excel** y **copia de seguridad**.
- **Modo consulta** en el móvil y en otros PC: el catálogo se descarga cifrado y se guarda para usarlo sin internet; después solo se bajan los cambios.

## Privacidad y seguridad

- **Tus películas no salen de tu disco.** Solo se publica el catálogo (las fichas) y miniaturas pequeñas de las carátulas.
- Lo publicado va **cifrado** (AES-256-GCM, con una llave sacada de la contraseña común con Argon2id). El repositorio del tablón es público para que los móviles lo descarguen sin cuentas, pero sin la contraseña no se puede leer.
- Las claves de TMDB, OMDb y GitHub se guardan **solo en tu PC**: ni se publican ni van en las copias de seguridad.
- La contraseña de administrador y la común **no se guardan** en ningún sitio, solo una huella para comprobarlas.

## Más documentación

- [Guía de uso](docs/guia.md): preparar la colección, instalar, completar fichas, publicar, el móvil y preguntas frecuentes.
- [Tu propia versión](docs/tu-propia-version.md): compilar la app, publicar tus instaladores con GitHub Actions y firmar tu APK.
- [Novedades de cada versión](docs/novedades/) y [cómo se ha hecho, día a día](PLANNING.md).

## Desarrollo

Hecha con [Flutter](https://flutter.dev) (un solo código para Windows y Android), [Riverpod](https://riverpod.dev) y SQLite ([Drift](https://drift.simonbinder.eu/)). Sin plugins de Flutter: lo propio de Windows (datos de los `.mp4`, diálogos, arrastrar archivos) va por FFI y un poco de C++, y lo de Android por un canal en Kotlin.

```bash
flutter pub get
flutter test
flutter run -d windows
```

Detalles en [docs/tu-propia-version.md](docs/tu-propia-version.md).

## Créditos

- Datos de películas: [TMDB](https://www.themoviedb.org), [OMDb](https://www.omdbapi.com), [Wikidata](https://www.wikidata.org) y [FilmAffinity](https://www.filmaffinity.com). *Esta app usa la API de TMDB, pero TMDB no la respalda ni la certifica.* Videoteca no tiene relación con ninguno de estos servicios.
- Tipografías [Bricolage Grotesque](https://fonts.google.com/specimen/Bricolage+Grotesque) y [Manrope](https://fonts.google.com/specimen/Manrope) (licencia OFL).

## Licencia

[MIT](LICENSE) © 2026 Ayoamaro
