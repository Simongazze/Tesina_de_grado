# =============================================================================
# CONSISTENCIA: 20 DIVISIONES ALEATORIAS EN DOS MITADES
# =============================================================================
# Adaptación de Hvattum y Gelade (2021), apartado "Reliability":
# https://doi.org/10.2478/ijcss-2021-0002
#
# Se repite 20 veces la división, el reajuste y la correlación de Pearson.
# Aquí se dividen POSESIONES DENTRO DE CADA PARTIDO, no segmentos sin cambios.
# Cada mitad contiene aproximadamente el 50% de las posesiones de cada partido.
# Por lo tanto, se evalúa estabilidad entre subconjuntos de los mismos encuentros.
#
# Se mantienen los alpha y lambda seleccionados con la temporada completa.
# Los coeficientes, interceptos y pesos de wEPTS se recalculan en cada mitad.
# Las mismas divisiones se utilizan para todos los métodos.
#
# Gráfico: puntos pequeños = correlaciones de cada división;
#          rombos blancos = promedio aritmético de las correlaciones.
# No se calculan permutaciones ni intervalos de confianza.
#
# Ejecutar DESPUÉS de crear estos objetos:
#   poss_by_poss_temporada, df_mod_ltp_sep
#   modelo_ridge, modelo_lasso, modelo_enet
#   modelo_multi_ridge, modelo_multi_lasso, modelo_multi_enet
#
# Los seis modelos deben ser objetos cv.glmnet de la temporada completa.
# df_mod_ltp_sep ya debe estar restringido a los jugadores elegibles
# (en la tesina, al menos 500 posesiones en la temporada).
# Ambas bases deben contener las mismas posesiones EN EL MISMO ORDEN.
# No se requiere df_metricas.
#
# Paquetes, si faltaran:
# install.packages(c("dplyr", "tidyr", "purrr", "stringr", "tibble",
#                    "ggplot2", "glmnet", "Matrix"))
# =============================================================================

paquetes <- c("dplyr", "tidyr", "purrr", "stringr", "tibble",
              "ggplot2", "glmnet", "Matrix")
faltan_paquetes <- paquetes[
  !vapply(paquetes, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
]
if (length(faltan_paquetes)) {
  stop("Instalá estos paquetes antes de continuar: ",
       paste(faltan_paquetes, collapse = ", "), call. = FALSE)
}
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(tibble)
  library(ggplot2)
  library(glmnet)
})

# -----------------------------------------------------------------------------
# 1. Configuración
# -----------------------------------------------------------------------------

n_repeticiones <- 20L
semilla_particion <- 20260809L
alpha_normal_enet <- 0.005
alpha_multi_enet <- 0.005
valor_3_mas <- 3.0304

# Mínimo POR COMPONENTE en CADA mitad. Con 1 se excluyen solo los ausentes.
# No se vuelve a aplicar el umbral de 500 posesiones a cada mitad.
min_posesiones_por_mitad <- 1L

# Las rutas se interpretan desde getwd(), normalmente la carpeta del proyecto.
guardar_resultados <- TRUE
carpeta_salida <- file.path("resultados_consistencia", "consistencia_20_divisiones")

stopifnot(
  n_repeticiones >= 2, n_repeticiones == as.integer(n_repeticiones),
  min_posesiones_por_mitad >= 1,
  alpha_normal_enet > 0, alpha_normal_enet < 1,
  alpha_multi_enet > 0, alpha_multi_enet < 1,
  is.finite(valor_3_mas), valor_3_mas >= 3
)

# -----------------------------------------------------------------------------
# 2. Objetos, correspondencia entre filas y matriz de diseño
# -----------------------------------------------------------------------------

#Poss-by-poss

poss_by_poss_temporada <- read_csv("data/poss_by_poss_temporada.csv")
poss_by_poss_temporada <- poss_by_poss_temporada[,-1]
poss_by_poss_temporada = poss_by_poss_temporada %>% 
  dplyr::select(- c(`ARN BUSTAMANTE, LUCAS  MARTIN`,`COSTA,  ALBANO NAHUEL` ))

poss_by_poss_temporada = poss_by_poss_temporada %>% 
  mutate(`GRÜN, FEDERICO JOSE` = `GRÜN, FEDERICO JOSE` + `GRUN, FEDERICO JOSE`, `MAINOLDI, LEONARDO ANDRES` = `MAINOLDI, LEONARDO ANDRES` + `MAINOLDI , LEONARDO ANDRES`) %>%
  dplyr::select(- c(`GRUN, FEDERICO JOSE`,`MAINOLDI , LEONARDO ANDRES`))

poss_by_poss_temporada <- poss_by_poss_temporada %>%
  mutate(
    equipos = str_split(partido_key, " vs "),
    equipo_local = str_trim(sapply(equipos, `[`, 1)),
    equipo_visitante = str_trim(sapply(equipos, `[`, 2)),
    
    # opcional: limpiar lo que venga después del nombre (paréntesis, fecha, etc.)
    equipo_local = str_remove(equipo_local, " \\(.*"),
    equipo_visitante = str_remove(equipo_visitante, " \\(.*"),
    
    equipo_limpio = if_else(
      tipo_equipo_accion == "local",
      equipo_local,
      equipo_visitante
    ),
    equipo_limpio_def = if_else(
      tipo_equipo_accion == "local",
      equipo_visitante,
      equipo_local
    )
  ) %>%
  dplyr::select(-equipos)

df_mod_ltp_sep = readRDS("resultados/resultados_consistencia/df_mod_ltp_sep.rds")

nombres_modelos <- c(
  "modelo_ridge", "modelo_enet", "modelo_lasso",
  "modelo_multi_ridge", "modelo_multi_enet", "modelo_multi_lasso"
)
objetos_necesarios <- c(
  "poss_by_poss_temporada", "df_mod_ltp_sep", nombres_modelos
)
faltan_objetos <- objetos_necesarios[
  !vapply(objetos_necesarios, exists, inherits = TRUE, FUN.VALUE = logical(1))
]
if (length(faltan_objetos)) {
  stop("Primero debés crear: ", paste(faltan_objetos, collapse = ", "),
       call. = FALSE)
}
stopifnot(
  all(c("partido_key", "puntos_pos") %in% names(df_mod_ltp_sep)),
  all(c("partido_key", "equipo_limpio", "equipo_limpio_def") %in%
        names(poss_by_poss_temporada)),
  nrow(df_mod_ltp_sep) == nrow(poss_by_poss_temporada),
  identical(as.character(df_mod_ltp_sep$partido_key),
            as.character(poss_by_poss_temporada$partido_key))
)
if ("puntos_pos" %in% names(poss_by_poss_temporada)) {
  stopifnot(identical(as.numeric(df_mod_ltp_sep$puntos_pos),
                      as.numeric(poss_by_poss_temporada$puntos_pos)))
}

id_partido <- as.character(df_mod_ltp_sep$partido_key)
y <- df_mod_ltp_sep$puntos_pos
stopifnot(
  !anyNA(id_partido), all(nzchar(id_partido)),
  is.numeric(y), all(is.finite(y)), all(y >= 0), all(y == floor(y))
)
variables_jugadores <- names(df_mod_ltp_sep) %>%
  keep(~ str_ends(.x, "_off") | str_ends(.x, "_def")) %>%
  setdiff(c("puntos_pos_off", "puntos_pos_def"))
stopifnot(
  length(variables_jugadores) >= 2,
  !anyDuplicated(variables_jugadores),
  all(vapply(df_mod_ltp_sep[variables_jugadores], is.numeric, logical(1)))
)

mapa_variables <- tibble(
  variable = variables_jugadores,
  jugador = str_remove(str_remove_all(variables_jugadores, "\x60"), "_(off|def)$"),
  componente = if_else(str_ends(variables_jugadores, "_off"),
                       "Ofensivo", "Defensivo")
)
stopifnot(!anyDuplicated(mapa_variables[c("jugador", "componente")]))

# Matriz dispersa para reducir memoria y costo de los 240 reajustes.
X <- Matrix::Matrix(
  as.matrix(dplyr::select(df_mod_ltp_sep, all_of(variables_jugadores))),
  sparse = TRUE
)
stopifnot(all(is.finite(X@x)))
columnas_off <- which(mapa_variables$componente == "Ofensivo")
columnas_def <- which(mapa_variables$componente == "Defensivo")
stopifnot(
  length(columnas_off) > 0, length(columnas_def) > 0,
  all(X[, columnas_off, drop = FALSE]@x %in% c(0, 1)),
  all(X[, columnas_def, drop = FALSE]@x %in% c(0, -1))
)
for (columna in c("equipo_limpio", "equipo_limpio_def")) {
  equipos <- as.character(poss_by_poss_temporada[[columna]])
  if (anyNA(equipos) || any(!nzchar(trimws(equipos)))) {
    stop("Hay equipos faltantes en ", columna,
         "; revisalos antes de calcular los pesos de wEPTS.")
  }
}

indices_por_partido <- split(seq_along(id_partido), id_partido)
if (any(lengths(indices_por_partido) < 2L)) {
  stop("Hay partidos con menos de dos posesiones: no pueden repartirse en A y B.")
}

# -----------------------------------------------------------------------------
# 3. Especificaciones fijas de regularización
# -----------------------------------------------------------------------------

especificaciones <- tibble(
  objeto = nombres_modelos,
  familia = rep(c("gaussian", "multinomial"), each = 3),
  regularizacion = rep(c("Ridge", "Elastic Net", "LASSO"), 2),
  alpha = c(0, alpha_normal_enet, 1, 0, alpha_multi_enet, 1),
  lambda = map_dbl(nombres_modelos, function(nombre) {
    modelo <- get(nombre, inherits = TRUE)
    if (!inherits(modelo, "cv.glmnet")) {
      stop(nombre, " debe ser un objeto cv.glmnet.")
    }
    valor <- unname(modelo$lambda.min)
    if (length(valor) != 1 || !is.finite(valor) || valor <= 0) {
      stop("lambda.min no es válido en ", nombre)
    }
    valor
  })
)
lambda_utilizados <- especificaciones %>%
  dplyr::select(familia, regularizacion, alpha, lambda)
print(lambda_utilizados)

# -----------------------------------------------------------------------------
# 4. Funciones: división, pesos y extracción de valoraciones
# -----------------------------------------------------------------------------

crear_mitades_dentro_partidos <- function(indices, n_filas, seed) {
  set.seed(seed)
  particion <- character(n_filas)
  for (idx in indices) {
    # Si el número de posesiones es impar, se sortea qué mitad recibe una más.
    etiquetas <- rep(sample(c("A", "B")), length.out = length(idx))
    particion[idx] <- sample(etiquetas)
  }
  particion
}

softmax <- function(eta) {
  z <- exp(eta - max(eta))
  z / sum(z)
}

calcular_pesos <- function(X_sub, pbp_sub) {
  map_dfr(seq_len(ncol(X_sub)), function(j) {
    variable <- colnames(X_sub)[j]
    presente <- as.numeric(X_sub[, j]) != 0
    equipo_fila <- if (str_ends(variable, "_off")) {
      as.character(pbp_sub$equipo_limpio)
    } else {
      as.character(pbp_sub$equipo_limpio_def)
    }
    equipos_jugador <- unique(equipo_fila[presente])
    denominador <- sum(equipo_fila %in% equipos_jugador)
    n_jugador <- sum(presente)
    stopifnot(n_jugador > 0, denominador >= n_jugador)
    tibble(
      variable = variable,
      posesiones_jugador = n_jugador,
      posesiones_equipos = denominador,
      cantidad_equipos = length(equipos_jugador),
      peso = n_jugador / denominador
    )
  })
}
# Para quienes actuaron en varios equipos se conserva tu definición anterior:
# el denominador suma las posesiones de esos equipos dentro de la mitad.

extraer_valoraciones <- function(ajuste, esp, pesos) {
  coefs <- coef(ajuste, s = esp$lambda)
  if (esp$familia == "gaussian") {
    beta <- as.matrix(coefs)
    ratings <- tibble(
      variable = rownames(beta),
      metrica = "RAPM",
      valor = as.numeric(beta[, 1]),
      epts_0 = NA_real_
    ) %>%
      filter(variable != "(Intercept)") %>%
      left_join(pesos, by = "variable")
  } else {
    beta <- do.call(cbind, lapply(coefs, function(z) as.numeric(z[, 1])))
    rownames(beta) <- rownames(coefs[[1]])
    colnames(beta) <- names(coefs)
    stopifnot(setequal(colnames(beta), as.character(0:3)))
    valores_categoria <- c("0" = 0, "1" = 1, "2" = 2, "3" = valor_3_mas)
    valores_categoria <- valores_categoria[colnames(beta)]
    interceptos <- beta["(Intercept)", ]
    epts_base <- sum(valores_categoria * softmax(interceptos))
    variables <- setdiff(rownames(beta), "(Intercept)")
    epts <- tibble(
      variable = variables,
      metrica = "EPTS",
      valor = map_dbl(variables, function(variable) {
        # +1 ofensivo; -1 defensivo, igual que en la matriz de diseño.
        signo <- if (str_ends(variable, "_off")) 1 else -1
        sum(valores_categoria * softmax(interceptos + signo * beta[variable, ]))
      }),
      epts_0 = epts_base
    ) %>%
      left_join(pesos, by = "variable")
    wepts <- epts %>%
      mutate(metrica = "wEPTS", valor = peso * valor + (1 - peso) * epts_0)
    ratings <- bind_rows(epts, wepts)
  }
  stopifnot(all(is.finite(ratings$valor)), !anyNA(ratings$peso))
  ratings %>%
    left_join(mapa_variables, by = "variable") %>%
    mutate(regularizacion = esp$regularizacion, alpha = esp$alpha,
           lambda_usado = esp$lambda)
}

ajustar_mitad <- function(particion_filas, mitad, repeticion) {
  idx <- which(particion_filas == mitad)
  X_sub <- X[idx, , drop = FALSE]
  # No se confunden coeficientes anulados por LASSO con jugadores ausentes.
  presentes <- Matrix::colSums(X_sub != 0) > 0
  X_sub <- X_sub[, presentes, drop = FALSE]
  y_sub <- y[idx]
  y_multi <- factor(pmin(y_sub, 3), levels = 0:3)
  if (ncol(X_sub) < 2 || sd(y_sub) == 0 || any(table(y_multi) < 2)) {
    stop("Información insuficiente en repetición ", repeticion, ", mitad ", mitad)
  }
  pesos <- calcular_pesos(
    X_sub, poss_by_poss_temporada[idx, , drop = FALSE]
  )
  map_dfr(seq_len(nrow(especificaciones)), function(i) {
    esp <- especificaciones[i, ]
    message("  ", repeticion, "/", n_repeticiones, " | mitad ", mitad,
            " | ", esp$familia, " - ", esp$regularizacion)
    # Recorrido corto para aprovechar los warm starts de glmnet.
    # Se extrae SOLO la solución en el lambda fijo; NO se selecciona otro lambda.
    argumentos <- list(
      x = X_sub,
      y = if (esp$familia == "gaussian") y_sub else y_multi,
      family = esp$familia,
      alpha = esp$alpha,
      lambda = esp$lambda * c(10, 5, 2, 1),
      standardize = FALSE,
      intercept = TRUE
    )
    if (esp$familia == "multinomial") {
      argumentos$type.multinomial <- "grouped"
    }
    ajuste <- do.call(glmnet::glmnet, argumentos)
    if ((!is.null(ajuste$jerr) && ajuste$jerr != 0) ||
        !any(abs(ajuste$lambda - esp$lambda) <= 1e-10 * esp$lambda)) {
      stop("No se obtuvo una solución válida en el lambda seleccionado: ",
           "repetición ", repeticion, ", mitad ", mitad, ", ", esp$objeto)
    }
    extraer_valoraciones(ajuste, esp, pesos) %>%
      mutate(repeticion = repeticion, particion = mitad)
  })
}

cor_segura <- function(x, y, method = "pearson") {
  completos <- is.finite(x) & is.finite(y)
  x <- x[completos]
  y <- y[completos]
  # Una correlación indefinida NO se reemplaza por cero.
  if (length(x) < 3 || sd(x) == 0 || sd(y) == 0) return(NA_real_)
  cor(x, y, method = method)
}

# -----------------------------------------------------------------------------
# 5. Veinte divisiones completas: 12 reajustes y 18 correlaciones por división
# -----------------------------------------------------------------------------

semillas <- semilla_particion + seq_len(n_repeticiones) - 1L
configuracion_consistencia <- list(
  n_repeticiones = n_repeticiones, semillas = semillas,
  unidad_division = "Posesiones dentro de cada partido",
  min_posesiones_por_mitad = min_posesiones_por_mitad,
  valor_3_mas = valor_3_mas, lambda_utilizados = lambda_utilizados,
  n_posesiones = nrow(X), n_partidos = length(indices_por_partido),
  n_jugadores = n_distinct(mapa_variables$jugador)
)
if (guardar_resultados) {
  dir.create(carpeta_salida, recursive = TRUE, showWarnings = FALSE)
}
resultados_repeticiones <- vector("list", n_repeticiones)
inicio_total <- Sys.time()

for (r in seq_len(n_repeticiones)) {
  inicio_r <- Sys.time()
  message("\nDIVISIÓN ", r, " DE ", n_repeticiones)
  particion_filas <- crear_mitades_dentro_partidos(
    indices_por_partido, nrow(X), semillas[r]
  )
  conteos <- tibble(partido_key = id_partido, particion = particion_filas) %>%
    count(partido_key, particion, name = "posesiones") %>%
    pivot_wider(names_from = particion, values_from = posesiones, values_fill = 0)
  stopifnot(all(conteos$A > 0), all(conteos$B > 0),
            all(abs(conteos$A - conteos$B) <= 1))

  ratings <- bind_rows(
    ajustar_mitad(particion_filas, "A", r),
    ajustar_mitad(particion_filas, "B", r)
  )
  pares <- ratings %>%
    dplyr::select(repeticion, variable, jugador, componente, metrica,
                  regularizacion, particion, valor, posesiones_jugador) %>%
    pivot_wider(
      names_from = particion,
      values_from = c(valor, posesiones_jugador)
    ) %>%
    mutate(
      elegible = !is.na(posesiones_jugador_A) & !is.na(posesiones_jugador_B) &
        posesiones_jugador_A >= min_posesiones_por_mitad &
        posesiones_jugador_B >= min_posesiones_por_mitad &
        is.finite(valor_A) & is.finite(valor_B)
    )
  correlaciones <- pares %>%
    group_by(repeticion, metrica, regularizacion, componente) %>%
    summarise(
      jugadores_comparados = sum(elegible),
      correlacion_pearson = cor_segura(valor_A[elegible], valor_B[elegible]),
      correlacion_spearman = cor_segura(valor_A[elegible], valor_B[elegible],
                                       "spearman"),
      .groups = "drop"
    )
  stopifnot(nrow(correlaciones) == 18L)

  # Control para identificar a los jugadores excluidos en alguna división.
  cobertura <- tibble(
    variable = colnames(X),
    posesiones_A = as.numeric(Matrix::colSums(X[particion_filas == "A", ] != 0)),
    posesiones_B = as.numeric(Matrix::colSums(X[particion_filas == "B", ] != 0))
  ) %>%
    left_join(mapa_variables, by = "variable") %>%
    mutate(
      repeticion = r,
      elegible = posesiones_A >= min_posesiones_por_mitad &
        posesiones_B >= min_posesiones_por_mitad
    )
  resumen_mitades <- tibble(
    repeticion = r, semilla = semillas[r], particion = c("A", "B"),
    partidos_representados = c(sum(conteos$A > 0), sum(conteos$B > 0)),
    posesiones = c(sum(conteos$A), sum(conteos$B))
  )
  resultados_repeticiones[[r]] <- list(
    correlaciones = correlaciones, ratings = ratings,
    cobertura = cobertura, resumen_mitades = resumen_mitades
  )
  if (guardar_resultados) {
    # Conserva las repeticiones terminadas si interrumpís una ejecución larga.
    # No hay reanudación automática: este archivo es un respaldo de resultados.
    saveRDS(
      list(configuracion = configuracion_consistencia,
           repeticiones_completadas = r,
           resultados = resultados_repeticiones[seq_len(r)]),
      file.path(carpeta_salida, "consistencia_resultados_parciales.RDS")
    )
  }
  message("División terminada en ",
          round(as.numeric(difftime(Sys.time(), inicio_r, units = "secs")), 1),
          " segundos.")
}

# -----------------------------------------------------------------------------
# 6. Resultados individuales, resumen y controles de cobertura
# -----------------------------------------------------------------------------

ordenar_factores <- function(datos) {
  datos %>%
    mutate(
      metrica = factor(metrica, levels = c("RAPM", "EPTS", "wEPTS")),
      regularizacion = factor(regularizacion,
                               levels = c("LASSO", "Elastic Net", "Ridge")),
      componente = factor(componente, levels = c("Ofensivo", "Defensivo"))
    )
}
consistencia_por_repeticion <- map_dfr(resultados_repeticiones, "correlaciones") %>%
  ordenar_factores()
ratings_todas_repeticiones <- map_dfr(resultados_repeticiones, "ratings")
cobertura_jugadores <- map_dfr(resultados_repeticiones, "cobertura")
jugadores_excluidos <- cobertura_jugadores %>% filter(!elegible)
resumen_particiones <- map_dfr(resultados_repeticiones, "resumen_mitades")

resumir_validos <- function(x, funcion) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  funcion(x)
}
resumen_consistencia <- consistencia_por_repeticion %>%
  group_by(metrica, regularizacion, componente) %>%
  summarise(
    repeticiones_totales = n(),
    repeticiones_validas = sum(is.finite(correlacion_pearson)),
    jugadores_min = min(jugadores_comparados),
    jugadores_max = max(jugadores_comparados),
    pearson_media = resumir_validos(correlacion_pearson, mean),
    pearson_mediana = resumir_validos(correlacion_pearson, median),
    pearson_sd = resumir_validos(correlacion_pearson, sd),
    pearson_min = resumir_validos(correlacion_pearson, min),
    pearson_max = resumir_validos(correlacion_pearson, max),
    spearman_repeticiones_validas = sum(is.finite(correlacion_spearman)),
    spearman_media = resumir_validos(correlacion_spearman, mean),
    .groups = "drop"
  )

# Compatibilidad de nombres con el desarrollo anterior.
resultados_consistencia <- resumen_consistencia
tabla_consistencia <- resumen_consistencia %>%
  transmute(
    Metrica = metrica, Regularizacion = regularizacion, Componente = componente,
    Repeticiones = repeticiones_totales, Validas = repeticiones_validas,
    Jugadores_min = jugadores_min, Jugadores_max = jugadores_max,
    Pearson_media = pearson_media, Pearson_SD = pearson_sd,
    Pearson_min = pearson_min, Pearson_max = pearson_max,
    Spearman_media = spearman_media,
    Spearman_validas = spearman_repeticiones_validas
  )
tabla_consistencia_final <- tabla_consistencia
print(tabla_consistencia, n = Inf, width = Inf)

if (any(resumen_consistencia$repeticiones_validas < n_repeticiones)) {
  warning(
    "Hay correlaciones indefinidas (pocos jugadores o valoraciones constantes). ",
    "Los promedios usan solo las repeticiones válidas; revisá la columna Validas."
  )
}
message("Combinaciones jugador/componente/división excluidas por participación: ",
        nrow(jugadores_excluidos))
if (nrow(jugadores_excluidos)) print(jugadores_excluidos, n = 20)

# -----------------------------------------------------------------------------
# 7. Gráfico: las 20 correlaciones y su promedio (sin IC ni permutaciones)
# -----------------------------------------------------------------------------

datos_grafico <- consistencia_por_repeticion %>%
  filter(is.finite(correlacion_pearson))
medias_grafico <- resumen_consistencia %>% filter(is.finite(pearson_media))
colores_componente <- c("Ofensivo" = "steelblue3", "Defensivo" = "#E38D65")

# La escala es común para los seis paneles e incluye cero y todos los resultados.
rango_x <- range(c(0, datos_grafico$correlacion_pearson))
margen_x <- max(0.04, diff(rango_x) * 0.08)
limites_x <- c(max(-1, rango_x[1] - margen_x), min(1, rango_x[2] + margen_x))
nota_validas <- if (any(resumen_consistencia$repeticiones_validas < n_repeticiones)) {
  "\nSe omiten correlaciones indefinidas; el promedio usa las repeticiones válidas."
} else {
  ""
}
grafico_consistencia <- ggplot() +
  geom_vline(xintercept = 0, linetype = "dashed",
             color = "grey55", linewidth = 0.5) +
  geom_point(
    data = datos_grafico,
    aes(x = correlacion_pearson, y = regularizacion, color = componente),
    # Solo se desplazan verticalmente; las correlaciones no se alteran.
    position = position_jitter(width = 0, height = 0.12, seed = 123),
    size = 1.8, alpha = 0.6, show.legend = FALSE
  ) +
  geom_point(
    data = medias_grafico,
    aes(x = pearson_media, y = regularizacion),
    shape = 23, fill = "white", color = "black", size = 2.5, stroke = 0.9
  ) +
  facet_grid(componente ~ metrica, drop = FALSE) +
  scale_color_manual(values = colores_componente) +
  scale_x_continuous(
    labels = function(x) format(x, decimal.mark = ",", trim = TRUE)
  ) +
  scale_y_discrete(drop = FALSE) +
  coord_cartesian(xlim = limites_x) +
  labs(
    x = "Correlación de Pearson entre las valoraciones de ambas mitades",
    y = NULL,
    caption = paste0(
      "Rombos blancos: promedio de las 20 correlaciones."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    legend.position = "none",
    plot.caption = element_text(hjust = 0, size = 9),
    panel.spacing = grid::unit(1, "lines")
  )
print(grafico_consistencia)

# -----------------------------------------------------------------------------
# 8. Guardado: tablas, gráfico y resultados completos
# -----------------------------------------------------------------------------

if (guardar_resultados) {
  write.csv2(tabla_consistencia,
             file.path(carpeta_salida, "tabla_consistencia_resumen.csv"),
             row.names = FALSE, fileEncoding = "UTF-8")
  write.csv2(consistencia_por_repeticion,
             file.path(carpeta_salida, "correlaciones_por_division.csv"),
             row.names = FALSE, fileEncoding = "UTF-8")
  write.csv2(cobertura_jugadores,
             file.path(carpeta_salida, "cobertura_jugadores.csv"),
             row.names = FALSE, fileEncoding = "UTF-8")
  saveRDS(tabla_consistencia_final,
          file.path(carpeta_salida, "tabla_consistencia.RDS"))
  saveRDS(
    list(
      configuracion = configuracion_consistencia,
      correlaciones = consistencia_por_repeticion,
      resumen = resumen_consistencia,
      ratings = ratings_todas_repeticiones,
      cobertura = cobertura_jugadores,
      particiones = resumen_particiones,
      grafico = grafico_consistencia,
      sesion = sessionInfo()
    ),
    file.path(carpeta_salida, "consistencia_resultados_completos.RDS")
  )
  ggsave(file.path("img", "consistencia_modelos_20_divisiones.pdf"),
         grafico_consistencia, width = 7, height = 5, units = "in")
  ggsave(file.path(carpeta_salida, "consistencia_modelos_20_divisiones.png"),
         grafico_consistencia, width = 9, height = 5.6, units = "in", dpi = 300)
  message("Resultados guardados en: ", normalizePath(carpeta_salida))
}
message("Tiempo total: ",
        round(as.numeric(difftime(Sys.time(), inicio_total, units = "mins")), 2),
        " minutos.")

# Cuando quieras usar este gráfico en la tesina, podés ejecutar:
# dir.create("img", showWarnings = FALSE)
# ggsave("img/consistencia_modelos.pdf", grafico_consistencia,
#        width = 9, height = 5.6, units = "in")
