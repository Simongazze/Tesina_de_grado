# Métrica RAPM: Evaluación del impacto ofensivo y defensivo de los jugadores de la Liga Nacional de Básquetbol en Argentina

Repositorio de la tesina de grado de **Simón Pedro Gazze**, Licenciatura en Estadística, Universidad Nacional de Rosario.

**Director:** Andrés Sosa · **Codirectora:** Cristina Cuesta · **Año:** 2026

[**Explorar rankings interactivos →**](https://simongazze.github.io/Tesina_de_grado/) · [**Leer la tesina (PDF)**](Tesina-de-grado---Simon-Gazze.pdf) · [**Descargar rankings (CSV)**](docs/rankings.csv)

---

## El proyecto

¿Cómo evaluar el aporte de un jugador más allá de sus puntos, rebotes o asistencias? Esta tesina estudia el desempeño individual en la **Liga Nacional de Básquetbol de Argentina, temporada 2024/2025**, mediante modelos que consideran simultáneamente a los compañeros y rivales presentes en cancha.

El trabajo recorre el proceso completo de investigación: extracción de datos públicos, reconstrucción de posesiones y quintetos, análisis descriptivo, estimación de modelos regularizados y evaluación de los rankings obtenidos. El repositorio reúne el código de desarrollo, las bases procesadas, modelos y tablas guardadas, la tesis y un visor para consultar los resultados.

### Referente metodológico principal

La principal referencia es **Damoulaki, Ntzoufras y Pelechrinis (2025)**, [*Lasso multinomial performance indicators for in-play basketball data*](https://doi.org/10.1007/s00180-025-01604-7).

De este artículo se retoman el enfoque de modelización por posesión, las medidas **EPTS** y **wEPTS** y criterios para evaluar los rankings. La tesina adapta esa propuesta a la información disponible de la LNB e incorpora la comparación entre **Ridge, Lasso y Elastic Net**. La referencia completa figura en la [bibliografía](#bibliografía).

## Datos y alcance

La fuente original son los registros de **play-by-play** y **box score** publicados para los partidos de la competencia. A partir de las acciones se reconstruyen las posesiones, sus puntos y los jugadores presentes en ataque y defensa.

| Alcance de la tesina | Descripción |
| --- | --- |
| Competencia | Liga Nacional de Básquetbol, Argentina |
| Temporada | 2024/2025, fase regular |
| Equipos | 20 |
| Partidos analizados | 378 |
| Posesiones reconstruidas | 58.625 |
| Jugadores con al menos una posesión | 346 |
| Umbral de participación utilizado | 500 posesiones |
| Jugadores evaluados en los modelos | 229 |

La base del visor conserva **235 registros jugador-equipo**, correspondientes a esos 229 jugadores. Quienes cambiaron de club pueden aparecer en más de una fila; el visor conserva esa información y permite filtrar por equipo y participación.

## Metodología

1. **Extracción y depuración.** Web scraping con Python, Selenium y BeautifulSoup; normalización de nombres y controles sobre acciones, quintetos y puntos.
2. **Construcción de la unidad de análisis.** Transformación del registro de acciones en una base a nivel de posesión, con indicadores de presencia ofensiva y defensiva de cada jugador.
3. **Estimación.** Comparación de modelos normales y de regresión logística multinomial con regularización Ridge, Lasso y Elastic Net, implementados en R con `glmnet`.
4. **Selección y evaluación interna.** Validación cruzada con partidos completos asignados a los folds, error de predicción, simulación de temporadas y análisis de consistencia entre submuestras.
5. **Evaluación de los rankings.** Comparación con criterios externos, como galardones, participación y estadísticas del box score, y con medidas descriptivas de referencia.

### Métricas disponibles

| Métrica | Qué describe | Cómo interpretar el ranking |
| --- | --- | --- |
| Descriptivas | Plus-minus acumulado, por 100 posesiones, estandarizado por equipo y puntos por posesión | El sentido se indica para cada medida en el visor |
| RAPM | Coeficientes del modelo normal para el aporte ofensivo y defensivo | Mayor es mejor en ataque, defensa y total; total = ORAPM + DRAPM |
| EPTS | Puntos esperados por posesión en un escenario con el jugador y los restantes jugadores de referencia | Mayor es mejor en ataque; menor es mejor en defensa; total = ataque − defensa |
| wEPTS | Versión de EPTS ponderada por la proporción de posesiones del jugador en su equipo | Mayor es mejor en ataque; menor es mejor en defensa; total = ataque − defensa |

El **plus-minus estandarizado** se calcula restando al plus-minus por 100 posesiones la mediana del equipo y dividiendo por su MAD. La referencia se calcula al preparar los datos y permanece fija al aplicar filtros en la página.

Las definiciones, fórmulas y decisiones de construcción se desarrollan en la [tesina](Tesina-de-grado---Simon-Gazze.pdf).

## Principales resultados

- Las diferencias en capacidad predictiva entre los modelos fueron pequeñas; ese criterio por sí solo no permitió identificar una alternativa claramente superior.
- Ridge y Elastic Net presentaron rankings más estables que Lasso en los análisis realizados. En esta aplicación, las métricas EPTS y wEPTS obtenidas con esas técnicas mostraron resultados favorables en varios de los criterios considerados.
- EPTS y wEPTS ofrecen lecturas complementarias: rendimiento durante las posesiones disputadas y valoración que incorpora la participación a lo largo de la temporada.

Estos resultados corresponden a los datos y criterios de esta aplicación. La reconstrucción de posesiones, los posibles errores del registro original y el uso de una sola temporada son limitaciones discutidas en la tesis.

## Organización del repositorio

| Archivo o carpeta | Contenido |
| --- | --- |
| [Tesina de grado - Simon Gazze.Rmd](<Tesina de grado - Simon Gazze.Rmd>) | Documento de la tesis; utiliza tablas y figuras guardadas |
| [Desarrollo - Tesina de grado.Rmd](<Desarrollo - Tesina de grado.Rmd>) | Preparación de datos, análisis, modelos, comparaciones y generación de resultados |
| [Web_scraping_play_by_play.ipynb](Web_scraping_play_by_play.ipynb) | Extracción y procesamiento del play-by-play y box score |
| [consistencia_modelos.R](consistencia_modelos.R) | Comparación de estabilidad mediante divisiones y reajustes de los modelos |
| [evaluación externa.Rmd](<evaluación externa.Rmd>) | Análisis complementario de los criterios de evaluación externa |
| [actualizar_rankings.R](actualizar_rankings.R) | Cálculo del plus-minus estandarizado y exportación de los datos del visor |
| [data/](data/) | Bases procesadas e insumos para los análisis y el scraping |
| [resultados/](resultados/) | Modelos ajustados, tablas y resultados de consistencia guardados en RDS y CSV |
| [docs/](docs/) | Sitio publicado con GitHub Pages, rankings y copia del PDF |
| [img/](img/) | Figuras, capturas y logos utilizados en el documento |
| [presentacion/](presentacion/) | Recursos gráficos y logos utilizados para las presentaciones |

Los archivos `.RDS` permiten reutilizar resultados sin volver a estimar los modelos. Se distinguen las tablas del desarrollo de las preparadas para el documento y la presentación.

## Cómo utilizarlo

### Consultar los resultados

El [visor interactivo](https://simongazze.github.io/Tesina_de_grado/) permite elegir la familia de métricas, regularización y dimensión del ranking; buscar jugadores; filtrar por equipo y posesiones; y descargar la selección en CSV. Para usarlo no es necesario instalar R ni Python.

### Trabajar con el código

Clonar el repositorio y abrir `Tesina_de_grado.Rproj`. Las rutas se interpretan desde la **raíz del proyecto**.

```bash
git clone https://github.com/Simongazze/Tesina_de_grado.git
```

- **R:** los análisis utilizan, entre otros, `tidyverse`, `glmnet`, `Matrix`, `readxl`, `gt`, `kableExtra` y paquetes de visualización. Las llamadas `library()` de cada archivo detallan sus dependencias.
- **Python:** el scraping utiliza `pandas`, `numpy`, `selenium`, `webdriver-manager`, `beautifulsoup4` y `tqdm`, además de Chrome/Chromium. El notebook incluye celdas de configuración para un entorno tipo Colab.
- **Documento PDF:** requiere `rmarkdown`, `knitr`, Pandoc y una distribución LaTeX.

Los documentos de desarrollo se trabajan por bloques. `evaluación externa.Rmd` utiliza objetos preparados durante el desarrollo; `consistencia_modelos.R` requiere los seis modelos ajustados, además de las bases indicadas al inicio del script. Cargar esos objetos antes de ejecutar los análisis correspondientes.

El notebook conserva bloques para un partido, diez partidos y la temporada completa. Para regenerar los datos, seleccionar los bloques correspondientes y revisar las rutas de salida. El intermedio crudo `data/df_pbp_final.csv` está excluido de Git y debe regenerarse si se repite esa parte del scraping. Las bases procesadas necesarias para los análisis ya se incluyen en `data/`.

Las versiones de los paquetes todavía no están fijadas en un archivo de entorno. Esta organización permite consultar y reutilizar el trabajo; la reproducción completa desde cero requiere preparar el entorno y ejecutar las etapas correspondientes.

### Compilar la tesina

Con las dependencias instaladas, las tablas guardadas y LaTeX disponible, ejecutar desde la raíz:

```r
rmarkdown::render(
  "Tesina de grado - Simon Gazze.Rmd",
  output_format = "pdf_document",
  output_file = "Tesina-de-grado---Simon-Gazze.pdf"
)
```

### Actualizar los rankings publicados

Con `df_rankings` preparado en R:

```r
source("actualizar_rankings.R")
df_rankings <- actualizar_rankings(df_rankings)
```

La función agrega el plus-minus estandarizado y actualiza `docs/rankings.csv`. Después, hacer commit y push del CSV para actualizar GitHub Pages.

El diseño del visor se edita en `docs/index.html`, `docs/styles.css` y `docs/app.js`. Los detalles están en [docs/README.md](docs/README.md). Si se reemplaza el PDF de la raíz, actualizar también su copia en `docs/assets/tesina-simon-gazze.pdf`.

## Bibliografía

### Referencia metodológica principal

**Damoulaki, A., Ntzoufras, I. y Pelechrinis, K. (2025).** *Lasso multinomial performance indicators for in-play basketball data*. **Computational Statistics, 40**, 2157–2181. [https://doi.org/10.1007/s00180-025-01604-7](https://doi.org/10.1007/s00180-025-01604-7).

### Otras referencias centrales de la tesina

- **Hvattum, L. M. (2019).** A comprehensive review of plus–minus ratings for evaluating individual players in team sports. *International Journal of Computer Science in Sport, 18*, 1–23.
- **Sill, J. (2010).** Improved NBA adjusted +/– using regularization and out-of-sample testing. *Proceedings of the MIT Sloan Sports Analytics Conference*.
- **Hoerl, A. E. y Kennard, R. W. (1970).** Ridge regression: Biased estimation for nonorthogonal problems. *Technometrics, 12*(1), 55–67.
- **Tibshirani, R. (1996).** Regression shrinkage and selection via the Lasso. *Journal of the Royal Statistical Society: Series B, 58*(1), 267–288.
- **Zou, H. y Hastie, T. (2005).** Regularization and variable selection via the Elastic Net. *Journal of the Royal Statistical Society: Series B, 67*(2), 301–320.
- **Yuan, M. y Lin, Y. (2006).** Model selection and estimation in regression with grouped variables. *Journal of the Royal Statistical Society: Series B, 68*(1), 49–67.
- **Hvattum, L. M. y Gelade, G. A. (2021).** Comparing bottom-up and top-down ratings for individual soccer players. *International Journal of Computer Science in Sport, 20*(1), 23–42.

La bibliografía completa se encuentra en el **capítulo 7 de la [tesina](Tesina-de-grado---Simon-Gazze.pdf)**.

## Cómo citar este trabajo

Gazze, S. P. (2026). *Métrica RAPM: Evaluación del impacto ofensivo y defensivo de los jugadores de la Liga Nacional de Básquetbol en Argentina* [Tesina de grado, Licenciatura en Estadística, Universidad Nacional de Rosario]. [Repositorio del proyecto](https://github.com/Simongazze/Tesina_de_grado).

Al reutilizar la metodología de EPTS y wEPTS, citar también el artículo de **Damoulaki, Ntzoufras y Pelechrinis (2025)**.
