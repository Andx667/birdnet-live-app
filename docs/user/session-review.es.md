# Revisión de la sesión

Session Review es donde BirdNET Live convierte las detecciones en un registro editable.

## Cómo alcanzarlo

BirdNET Live abre la Revisión de sesión automáticamente después de completar:

- una sesión en vivo
- un recuento de puntos
- una encuesta
- una ejecución de análisis de archivos

También puede volver a abrir cualquier sesión guardada desde la [Biblioteca de sesiones] (session-library.md).

## Áreas principales

### Resumen y reproducción

Session Review combina reproducción, navegación por espectrograma y una lista de especies. Para sesiones de encuesta, también puede mostrar el contexto mapeado.

### Lista de especies

Las especies se agrupan en filas ampliables. Podrás inspeccionar las detecciones por especie y moverte por la grabación mientras las revisas.

### Mapa de seguimiento de la encuesta

Las sesiones de encuesta muestran un pequeño mapa en línea de la traza GPS y los marcadores de detección. Toque un marcador en el mapa en línea para enfocar una detección — el mapa se centra en ella. Toque el botón :material-fullscreen: **expandir** (esquina superior derecha del mapa en línea) para abrir el **mapa a pantalla completa**; si una detección estaba enfocada, el mapa a pantalla completa se abre centrado y ampliado en esa detección para que conserve su lugar.

#### Codificación de marcadores

- **La confianza se codifica por color** con una paleta segura para personas con daltonismo (CVD): la confianza baja a alta pasa de violeta-azul a turquesa/amarillo hasta rojo. La luminosidad de la paleta varía monotónicamente, por lo que sigue siendo legible en monocromo y para usuarios con deficiencia de visión rojo-verde.
- **Las detecciones con audio** muestran un anillo coloreado alrededor de la foto de la especie más una insignia de reproducción en la esquina — tóquelas para reproducir el clip grabado en una hoja.
- **Las detecciones silenciosas** (sin clip en el disco) se renderizan más pequeñas, atenuadas y con un anillo gris neutro, para que las detecciones con audio siempre se lean como el contenido principal.
- **Los marcadores que se superponen en el mismo punto** se ordenan en z por importancia: resaltado > con audio > mayor confianza, de modo que un marcador silencioso de baja confianza nunca puede ocultar una detección de audio fuerte.
- **Por debajo del zoom 14,5** las siluetas se degradan a puntos coloreados dimensionados por confianza, y los grupos densos se colapsan en una burbuja de recuento (el agrupamiento se desactiva en el zoom 15).

#### Filtrado

El mapa a pantalla completa tiene un **chip de filtro** persistente anclado en la esquina superior derecha. Tóquelo para abrir la hoja de filtros; la etiqueta del chip siempre muestra lo que está actualmente activo (*«Todas las especies»*, *«Con audio»*, *«≥ 80 %»* o el nombre de una sola especie). Filtros disponibles:

- **Todas las detecciones** (predeterminado).
- **Con clip de audio** — solo detecciones cuyo clip aún está en disco y se puede reproducir.
- **Adiciones manuales** — solo detecciones que agregó en Revisión de sesión (excluye las detectadas automáticamente).

También puede restringir las detecciones por nivel de confianza. El control deslizante configura el umbral mínimo de confianza (comienza en 10 %).

Debajo del control deslizante de confianza hay un selector **Limitar a especies** que le permite colapsar el mapa a una sola especie — útil para preguntar «¿dónde exactamente a lo largo de la ruta escuché el zorzal del bosque?». Una entrada *Todas las especies* borra la restricción de especie. Los filtros se combinan: por ejemplo *Con clip de audio* + *Zorzal del bosque* + *> 80 %* muestra solo los marcadores reproducibles del Zorzal del bosque que superaron el 80 %.

Cuando un filtro está activo, el título de la barra de la aplicación obtiene un subtítulo con el número de coincidencias (por ejemplo *«7 detecciones»*). *Restablecer* en la hoja vuelve al valor predeterminado.

## Iconos de la barra de herramientas

La barra de herramientas utiliza los mismos significados de íconos descritos en [Iconos y controles](icons-and-controls.md):

- :material-plus-circle-outline: — agregar contenido
- :material-undo-variant: / :material-redo-variant: — paso a paso por las ediciones
- :material-content-cut: — modo de recorte
- :material-content-save: — guardar ediciones
- :material-share-variant: — exportar o compartir
- :material-delete-outline: — descartar sesión
- :material-play: — continuar una encuesta cuando esa acción esté disponible
- :material-help-circle-outline: — abre la hoja de ayuda de Revisión de la sesión
- :material-tune: — abre Configuración

## Tareas típicas de revisión

- comprobar las detecciones en comparación con la reproducción y el contexto del espectrograma
- agregar una especie o anotación
- recortar la grabación al intervalo útil
- exportar el conjunto de resultados revisado

## Exportar

El comportamiento de exportación depende de las opciones seleccionadas en [Configuración] (settings.md). La aplicación puede empaquetar detecciones y, opcionalmente, audio en el formato de exportación elegido. Cada exportación ahora se envía con metadatos de procedencia completos (la versión de la aplicación, el nombre y la versión del modelo, la configuración regional de la especie, la marca de tiempo de exportación y una instantánea de todas las configuraciones en el momento de la exportación) escritos en un archivo lateral `<prefix>.metadata.json` (ZIP) o en un bloque `meta` de nivel superior (JSON) para que las exportaciones sean autodescriptivas y reproducibles.