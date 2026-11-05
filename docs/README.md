# Visor de rankings

Sitio público: https://simongazze.github.io/Tesina_de_grado/

GitHub Pages publica esta carpeta desde `main`. El visor no requiere compilación: `index.html` define la página, `styles.css` su diseño y `app.js` los filtros y rankings. Los datos se leen de `rankings.csv`.

## Actualizar los datos desde R

Con `df_rankings` preparado, ejecutar desde la raíz del proyecto. El script agrega el plus-minus estandarizado siguiendo la definición del desarrollo y exporta el CSV:

```r
source("actualizar_rankings.R")
df_rankings <- actualizar_rankings(df_rankings)
```

Para actualizar el CSV ya publicado sin volver a cargar los modelos, se puede ejecutar `actualizar_rankings()` sin argumentos. Después, hacer commit y push del CSV. GitHub Pages actualizará el visor. **No volver a ejecutar `htmlwidgets::saveWidget()` sobre `docs/index.html`**: reemplazaría esta página por la tabla original de reactable.

## Modificar el visor

Todo el código es editable después de `git pull`: `index.html` contiene textos y estructura, `styles.css` define colores y diseño y `app.js` implementa selectores, filtros, orden y descarga. R prepara los datos; el navegador muestra la página con HTML, CSS y JavaScript. No hay que ejecutar un generador para cambiar el diseño.

Conservar `docs/.nojekyll`. Las dependencias antiguas de `index_files/` no son utilizadas por este visor; pueden retirarse por separado.

Los logos del encabezado se publican en `docs/assets/logos/`, con los archivos originales de `img/Logo-unr.png`, `img/logo_lnb_2024_2025.png` e `img/LOGO horizontal gris.png`. El PDF enlazado está en `docs/assets/tesina-simon-gazze.pdf`, copiado de `Tesina-de-grado---Simon-Gazze.pdf`. Si se reemplazan los originales, actualizar también estas copias para que GitHub Pages muestre la nueva versión.

## Interpretación

- Se conserva cada fila jugador-equipo. No se agregan ni se eliminan jugadores que cambiaron de club.
- El filtro de posesiones se aplica a cada fila. El mínimo inicial es 500.
- El ranking se recalcula dentro de los filtros actuales. Los valores empatados (tolerancia numérica de 1e-12) comparten posición.
- RAPM: mayor es mejor en ataque, defensa y total; total = ORAPM + DRAPM.
- EPTS y wEPTS: mayor es mejor en ataque y total; menor es mejor en defensa. Total = ataque − defensa.
- Los totales se leen de las columnas existentes del CSV. El visor no vuelve a estimar modelos ni reemplaza valores faltantes.
- `pts_recib_por_pos` está guardado con signo negativo. Solo para mostrar puntos recibidos por posesión se cambia el signo y se ordena de menor a mayor. La descarga de la selección incluye tanto el valor original como el mostrado.
- `pm_estand_median` es el plus-minus estandarizado por equipo: `(plus_minus_100 - mediana del equipo) / MAD del equipo`, con el factor 1,4826 de `mad()` en R. La referencia usa los registros con más de 500 posesiones por equipo, igual que el desarrollo. Se calcula al exportar y no cambia al filtrar el visor. Se presenta en la dimensión Total y no se obtiene sumando las otras medidas estandarizadas.
- Las medidas ofensivas y defensivas estandarizadas conservan su signo original: mayor es mejor. No se crea un total sumándolas.
- El CSV completo conserva la precisión original. La tabla redondea únicamente la presentación.

La descarga de la selección incluye todos los registros filtrados, no solo la página visible, y documenta la columna de origen y los parámetros elegidos.
