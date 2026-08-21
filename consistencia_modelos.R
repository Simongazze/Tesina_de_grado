library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(tibble)
library(ggplot2)
library(glmnet)

# =============================================================================
# EVALUACIÓN DE CONSISTENCIA
# 3 regularizaciones x 3 métricas x 2 componentes = 18 correlaciones
# =============================================================================

# El código supone que ya existen en el entorno:
#   - poss_by_poss_temporada
#   - df_mod_ltp_sep
#   - modelo_ridge, modelo_lasso, modelo_enet
#   - modelo_multi_ridge, modelo_multi_lasso, modelo_multi_enet
#
# Los seis objetos anteriores deben ser los cv.glmnet ajustados con la temporada
# completa. De ellos se toma lambda.min y se lo mantiene fijo al reajustar A y B.
#
# df_mod_ltp_sep debe conservar partido_key y puntos_pos, y contener las
# indicadoras de jugadores con sufijos _off y _def. En tu desarrollo ya está
# restringido a los 229 jugadores con al menos 500 posesiones en la temporada.

# -----------------------------------------------------------------------------
# 1. Parámetros que podés modificar
# -----------------------------------------------------------------------------

semilla_particion <- 20260809
semilla_azar <- 20260809

B_azar <- 5000

# En Desarrollo - Tesina de grado ambos Elastic Net usan actualmente 0.005.
# Modificá estos valores si finalmente elegís otros alpha.
alpha_normal_enet <- 0.005
alpha_multi_enet <- 0.005

# Valor medio observado dentro de la categoría de 3 o más puntos.
# Se mantiene el valor utilizado actualmente en tu código.
valor_3_mas <- 3.0304

# Para comparar un jugador se exige que haya aparecido, al menos, en esta
# cantidad de posesiones de cada partición. Con 1 solo se excluyen los ausentes.
min_posesiones_por_mitad <- 1

# -----------------------------------------------------------------------------
# 2. Matriz de diseño y controles de correspondencia
# -----------------------------------------------------------------------------

id_partido <- df_mod_ltp_sep$partido_key
y <- df_mod_ltp_sep$puntos_pos

variables_jugadores <- names(df_mod_ltp_sep) %>%
  keep(~ str_ends(.x, "_off") | str_ends(.x, "_def")) %>%
  setdiff(
    c(
      "puntos_pos_off",
      "puntos_pos_def"
    )
  )

normalizar_nombre <- function(x) {
  x %>%
    str_to_upper() %>%
    str_squish()
}

jugadores_metricas <- df_metricas %>%
  distinct(jugador, posesiones_totales) %>%
  mutate(
    clave_jugador = normalizar_nombre(jugador)
  )

jugadores_X <- tibble(
  variable = variables_jugadores
) %>%
  mutate(
    componente = case_when(
      str_ends(variable, "_off") ~ "Ofensivo",
      str_ends(variable, "_def") ~ "Defensivo",
      TRUE ~ NA_character_
    ),
    jugador_X = str_remove(variable, "_(off|def)$"),
    clave_jugador = normalizar_nombre(jugador_X)
  ) %>%
  filter(!is.na(componente)) %>%
  distinct(clave_jugador, jugador_X)

faltantes_en_X <- jugadores_metricas %>%
  anti_join(
    jugadores_X,
    by = "clave_jugador"
  )

faltantes_en_X

X <- df_mod_ltp_sep %>%
  dplyr::select(all_of(variables_jugadores)) %>%
  as.matrix()

stopifnot(
  nrow(X) == length(y),
  length(y) == length(id_partido),
  nrow(poss_by_poss_temporada) == nrow(df_mod_ltp_sep),
  identical(
    as.character(poss_by_poss_temporada$partido_key),
    as.character(df_mod_ltp_sep$partido_key)
  ),
  all(c("equipo_limpio", "equipo_limpio_def") %in%
        names(poss_by_poss_temporada))
)

# -----------------------------------------------------------------------------
# 3. Partición de posesiones dentro de cada partido
# -----------------------------------------------------------------------------

# En cada partido se distribuye aproximadamente la mitad de las posesiones
# en A y la otra mitad en B. Cuando el número de posesiones es impar,
# se determina aleatoriamente qué partición recibe la posesión adicional.

crear_mitades_dentro_partidos <- function(
    id_partido,
    seed = 20260812
) {
  
  set.seed(seed)
  
  particion <- character(length(id_partido))
  
  indices_por_partido <- split(
    seq_along(id_partido),
    as.character(id_partido)
  )
  
  for (idx in indices_por_partido) {
    
    # Se sortea qué partición recibe primero una observación.
    # Esto evita que A reciba sistemáticamente la observación adicional
    # en los partidos con una cantidad impar de posesiones.
    orden_particiones <- sample(c("A", "B"))
    
    etiquetas <- rep(
      orden_particiones,
      length.out = length(idx)
    )
    
    # Se distribuyen aleatoriamente las etiquetas entre las posesiones
    # correspondientes a ese partido.
    particion[idx] <- sample(etiquetas)
  }
  
  particion
}

particion_filas <- crear_mitades_dentro_partidos(
  id_partido,
  seed = semilla_particion
)

resumen_particiones <- tibble(
  partido_key = id_partido,
  particion = particion_filas
) %>%
  group_by(particion) %>%
  summarise(
    partidos_representados = n_distinct(partido_key),
    posesiones = n(),
    porcentaje_posesiones =
      100 * posesiones / length(id_partido),
    .groups = "drop"
  )

print(resumen_particiones)

# Resumen por partido para controlar el reparto.
resumen_particiones_por_partido <- tibble(
  partido_key = id_partido,
  particion = particion_filas
) %>%
  count(
    partido_key,
    particion,
    name = "posesiones"
  ) %>%
  pivot_wider(
    names_from = particion,
    values_from = posesiones,
    values_fill = 0
  ) %>%
  mutate(
    diferencia = abs(A - B)
  )

print(resumen_particiones_por_partido)

# Todos los partidos deben estar representados en ambas particiones.
stopifnot(
  all(resumen_particiones_por_partido$A > 0),
  all(resumen_particiones_por_partido$B > 0)
)

# Dentro de cada partido, la diferencia entre A y B debe ser como máximo
# de una posesión.
stopifnot(
  all(resumen_particiones_por_partido$diferencia <= 1)
)

# -----------------------------------------------------------------------------
# 4. Especificaciones con los lambda ya seleccionados
# -----------------------------------------------------------------------------

# Los lambda fueron seleccionados previamente mediante validación cruzada con la
# temporada completa. En la evaluación de consistencia se mantienen fijos para
# que la comparación mida la estabilidad de los ratings y no vuelva a ejecutar
# una validación cruzada costosa dentro de cada mitad.
especificaciones_normal <- list(
  list(
    regularizacion = "Ridge",
    alpha = 0,
    lambda = unname(modelo_ridge$lambda.min)
  ),
  list(
    regularizacion = "Elastic Net",
    alpha = alpha_normal_enet,
    lambda = unname(modelo_enet$lambda.min)
  ),
  list(
    regularizacion = "LASSO",
    alpha = 1,
    lambda = unname(modelo_lasso$lambda.min)
  )
)

especificaciones_multi <- list(
  list(
    regularizacion = "Ridge",
    alpha = 0,
    lambda = unname(modelo_multi_ridge$lambda.min)
  ),
  list(
    regularizacion = "Elastic Net",
    alpha = alpha_multi_enet,
    lambda = unname(modelo_multi_enet$lambda.min)
  ),
  list(
    regularizacion = "LASSO",
    alpha = 1,
    lambda = unname(modelo_multi_lasso$lambda.min)
  )
)

stopifnot(
  all(map_lgl(especificaciones_normal, ~ length(.x$lambda) == 1)),
  all(map_lgl(especificaciones_multi, ~ length(.x$lambda) == 1)),
  all(map_dbl(especificaciones_normal, "lambda") > 0),
  all(map_dbl(especificaciones_multi, "lambda") > 0)
)

lambda_utilizados <- bind_rows(
  map_dfr(
    especificaciones_normal,
    ~ tibble(
      familia = "Normal",
      regularizacion = .x$regularizacion,
      alpha = .x$alpha,
      lambda = .x$lambda
    )
  ),
  map_dfr(
    especificaciones_multi,
    ~ tibble(
      familia = "Multinomial",
      regularizacion = .x$regularizacion,
      alpha = .x$alpha,
      lambda = .x$lambda
    )
  )
)

print(lambda_utilizados)

# -----------------------------------------------------------------------------
# 5. Funciones para extraer RAPM y EPTS
# -----------------------------------------------------------------------------

extraer_rapm <- function(ajuste, regularizacion, particion, lambda_fijo) {
  matriz_beta <- as.matrix(coef(ajuste, s = lambda_fijo))

  tibble(
    variable = str_remove_all(rownames(matriz_beta), "`"),
    valor = as.numeric(matriz_beta[, 1])
  ) %>%
    filter(variable != "(Intercept)") %>%
    mutate(
      componente = case_when(
        str_ends(variable, "_off") ~ "Ofensivo",
        str_ends(variable, "_def") ~ "Defensivo",
        TRUE ~ NA_character_
      ),
      jugador = str_remove(variable, "_(off|def)$"),
      metrica = "RAPM",
      regularizacion = regularizacion,
      particion = particion,
      lambda_usado = lambda_fijo
    ) %>%
    filter(!is.na(componente)) %>%
    dplyr::select(
      jugador, componente, metrica, regularizacion,
      particion, valor, lambda_usado
    )
}

softmax <- function(eta) {
  z <- exp(eta - max(eta))
  z / sum(z)
}

extraer_epts <- function(
    ajuste,
    regularizacion,
    particion,
    lambda_fijo,
    valor_3_mas = 3.0304) {

  coefs <- coef(ajuste, s = lambda_fijo)

  matriz_beta <- do.call(
    cbind,
    lapply(coefs, function(z) as.numeric(z[, 1]))
  )

  rownames(matriz_beta) <- str_remove_all(
    rownames(coefs[[1]]),
    "`"
  )
  colnames(matriz_beta) <- names(coefs)

  valores_categoria <- c(
    "0" = 0,
    "1" = 1,
    "2" = 2,
    "3" = valor_3_mas
  )
  valores_categoria <- valores_categoria[colnames(matriz_beta)]

  interceptos <- matriz_beta["(Intercept)", ]
  epts_0 <- sum(valores_categoria * softmax(interceptos))

  variables <- setdiff(rownames(matriz_beta), "(Intercept)")

  map_dfr(variables, function(variable) {
    es_ofensivo <- str_ends(variable, "_off")
    es_defensivo <- str_ends(variable, "_def")

    if (!es_ofensivo && !es_defensivo) return(NULL)

    # La presencia ofensiva está codificada con +1 y la defensiva con -1.
    signo_x <- if (es_ofensivo) 1 else -1

    probabilidades <- softmax(
      interceptos + signo_x * matriz_beta[variable, ]
    )

    tibble(
      jugador = str_remove(variable, "_(off|def)$"),
      componente = if_else(es_ofensivo, "Ofensivo", "Defensivo"),
      metrica = "EPTS",
      regularizacion = regularizacion,
      particion = particion,
      valor = sum(valores_categoria * probabilidades),
      epts_0 = epts_0,
      lambda_usado = lambda_fijo
    )
  })
}

# -----------------------------------------------------------------------------
# 6. Reajuste de los modelos en cada partición
# -----------------------------------------------------------------------------

ajustar_normales_particion <- function(particion) {
  idx <- which(particion_filas == particion)
  X_sub <- X[idx, , drop = FALSE]
  y_sub <- y[idx]
  # Se eliminan únicamente las columnas sin ninguna aparición en esta mitad.
  activas <- colSums(X_sub != 0) > 0
  X_sub <- X_sub[, activas, drop = FALSE]

  map_dfr(
    especificaciones_normal,
    function(esp) {
      message(
        "Ajustando Normal - ", esp$regularizacion,
        " - partición ", particion,
        " - lambda fijo = ", signif(esp$lambda, 6)
      )

      tiempo_inicio <- Sys.time()

      ajuste <- glmnet(
        x = X_sub,
        y = y_sub,
        family = "gaussian",
        alpha = esp$alpha,
        lambda = esp$lambda,
        standardize = FALSE
      )

      message(
        "Finalizado en ",
        round(as.numeric(difftime(Sys.time(), tiempo_inicio, units = "secs")), 1),
        " segundos"
      )

      extraer_rapm(
        ajuste,
        regularizacion = esp$regularizacion,
        particion = particion,
        lambda_fijo = esp$lambda
      )
    }
  )
}

ajustar_multinomiales_particion <- function(particion) {
  idx <- which(particion_filas == particion)
  X_sub <- X[idx, , drop = FALSE]
  y_sub <- ifelse(y[idx] >= 3, 3, y[idx])
  activas <- colSums(X_sub != 0) > 0
  X_sub <- X_sub[, activas, drop = FALSE]

  map_dfr(
    especificaciones_multi,
    function(esp) {
      message(
        "Ajustando Multinomial - ", esp$regularizacion,
        " - partición ", particion,
        " - lambda fijo = ", signif(esp$lambda, 6)
      )

      tiempo_inicio <- Sys.time()

      ajuste <- glmnet(
        x = X_sub,
        y = factor(y_sub, levels = 0:3),
        family = "multinomial",
        type.multinomial = "grouped",
        alpha = esp$alpha,
        lambda = esp$lambda,
        standardize = FALSE
      )

      message(
        "Finalizado en ",
        round(as.numeric(difftime(Sys.time(), tiempo_inicio, units = "secs")), 1),
        " segundos"
      )

      extraer_epts(
        ajuste,
        regularizacion = esp$regularizacion,
        particion = particion,
        lambda_fijo = esp$lambda,
        valor_3_mas = valor_3_mas
      )
    }
  )
}

rapm_A <- ajustar_normales_particion("A")
rapm_B <- ajustar_normales_particion("B")

epts_A <- ajustar_multinomiales_particion("A")
epts_B <- ajustar_multinomiales_particion("B")

# -----------------------------------------------------------------------------
# 7. Pesos de participación para wEPTS dentro de cada partición
# -----------------------------------------------------------------------------

# Para un jugador que actuó en un solo equipo:
#     W = posesiones del jugador / posesiones de su equipo.
#
# Para los jugadores que actuaron en más de un equipo dentro de una partición,
# el denominador suma las posesiones de todos esos equipos. Esto evita asignar
# arbitrariamente al jugador a solo uno de ellos.
calcular_pesos_particion <- function(particion) {
  idx <- which(particion_filas == particion)

  X_sub <- X[idx, , drop = FALSE]
  pbp_sub <- poss_by_poss_temporada[idx, , drop = FALSE]

  map_dfr(colnames(X_sub), function(variable) {
    es_ofensivo <- str_ends(variable, "_off")
    es_defensivo <- str_ends(variable, "_def")

    if (!es_ofensivo && !es_defensivo) return(NULL)

    presente <- X_sub[, variable] != 0
    n_jugador <- sum(presente)

    if (n_jugador == 0) return(NULL)

    equipo_fila <- if (es_ofensivo) {
      as.character(pbp_sub$equipo_limpio)
    } else {
      as.character(pbp_sub$equipo_limpio_def)
    }

    equipos_jugador <- unique(equipo_fila[presente & !is.na(equipo_fila)])
    n_equipos <- sum(equipo_fila %in% equipos_jugador, na.rm = TRUE)

    tibble(
      jugador = str_remove(str_remove_all(variable, "`"), "_(off|def)$"),
      componente = if_else(es_ofensivo, "Ofensivo", "Defensivo"),
      particion = particion,
      posesiones_jugador = n_jugador,
      posesiones_equipos = n_equipos,
      cantidad_equipos = length(equipos_jugador),
      equipos = paste(sort(equipos_jugador), collapse = ", "),
      peso = n_jugador / n_equipos
    )
  })
}

pesos_A <- calcular_pesos_particion("A")
pesos_B <- calcular_pesos_particion("B")
pesos_particiones <- bind_rows(pesos_A, pesos_B)

stopifnot(
  all(pesos_particiones$peso >= 0, na.rm = TRUE),
  all(pesos_particiones$peso <= 1, na.rm = TRUE)
)

crear_wepts <- function(epts, pesos) {
  epts %>%
    left_join(
      pesos %>%
        dplyr::select(
          jugador, componente, particion,
          posesiones_jugador, peso
        ),
      by = c("jugador", "componente", "particion")
    ) %>%
    mutate(
      metrica = "wEPTS",
      valor = peso * valor + (1 - peso) * epts_0
    )
}

wepts_A <- crear_wepts(epts_A, pesos_A)
wepts_B <- crear_wepts(epts_B, pesos_B)

# -----------------------------------------------------------------------------
# 8. Base final de ratings de cada mitad
# -----------------------------------------------------------------------------

ratings_A <- bind_rows(
  rapm_A %>%
    left_join(
      pesos_A %>%
        dplyr::select(jugador, componente, posesiones_jugador),
      by = c("jugador", "componente")
    ),
  epts_A %>%
    left_join(
      pesos_A %>%
        dplyr::select(jugador, componente, posesiones_jugador),
      by = c("jugador", "componente")
    ),
  wepts_A
) %>%
  dplyr::select(
    jugador, componente, metrica, regularizacion,
    particion, valor, lambda_usado, posesiones_jugador
  )

ratings_B <- bind_rows(
  rapm_B %>%
    left_join(
      pesos_B %>%
        dplyr::select(jugador, componente, posesiones_jugador),
      by = c("jugador", "componente")
    ),
  epts_B %>%
    left_join(
      pesos_B %>%
        dplyr::select(jugador, componente, posesiones_jugador),
      by = c("jugador", "componente")
    ),
  wepts_B
) %>%
  dplyr::select(
    jugador, componente, metrica, regularizacion,
    particion, valor, lambda_usado, posesiones_jugador
  )

ratings_pareados <- ratings_A %>%
  transmute(
    jugador,
    componente,
    metrica,
    regularizacion,
    valor_A = valor,
    lambda_A = lambda_usado,
    posesiones_A = posesiones_jugador
  ) %>%
  inner_join(
    ratings_B %>%
      transmute(
        jugador,
        componente,
        metrica,
        regularizacion,
        valor_B = valor,
        lambda_B = lambda_usado,
        posesiones_B = posesiones_jugador
      ),
    by = c("jugador", "componente", "metrica", "regularizacion")
  ) %>%
  filter(
    posesiones_A >= min_posesiones_por_mitad,
    posesiones_B >= min_posesiones_por_mitad,
    complete.cases(valor_A, valor_B)
  )

# Comprobación: A y B utilizaron exactamente los mismos lambda fijos.
lambda_seleccionados <- ratings_pareados %>%
  distinct(metrica, regularizacion, lambda_A, lambda_B) %>%
  arrange(metrica, regularizacion)

print(lambda_seleccionados)

stopifnot(all(dplyr::near(
  lambda_seleccionados$lambda_A,
  lambda_seleccionados$lambda_B
)))

# -----------------------------------------------------------------------------
# 9. Las 18 correlaciones observadas
# -----------------------------------------------------------------------------

cor_segura <- function(x, y, method = "pearson") {
  completos <- complete.cases(x, y)
  x <- x[completos]
  y <- y[completos]

  if (length(x) < 3 || sd(x) == 0 || sd(y) == 0) return(NA_real_)

  cor(x, y, method = method)
}

consistencia_observada <- ratings_pareados %>%
  group_by(metrica, regularizacion, componente) %>%
  summarise(
    jugadores_comparados = n(),
    correlacion_pearson = cor_segura(valor_A, valor_B, "pearson"),
    correlacion_spearman = cor_segura(valor_A, valor_B, "spearman"),
    .groups = "drop"
  )

stopifnot(nrow(consistencia_observada) == 18)

# -----------------------------------------------------------------------------
# 10. Distribución de referencia por permutaciones
# -----------------------------------------------------------------------------

# No se trata de un séptimo modelo. En cada repetición se mantienen los ratings
# de ambas mitades, pero se permutan las identidades de los jugadores en B. Así
# se obtiene la correlación esperable si no existiera correspondencia entre el
# rendimiento de un mismo jugador en A y en B.
set.seed(semilla_azar)

consistencia_azar <- ratings_pareados %>%
  group_by(metrica, regularizacion, componente) %>%
  group_modify(~ {
    tibble(
      simulacion = seq_len(B_azar),
      correlacion_azar = replicate(
        B_azar,
        cor_segura(.x$valor_A, sample(.x$valor_B), "pearson")
      )
    )
  }) %>%
  ungroup()

resumen_azar <- consistencia_azar %>%
  group_by(metrica, regularizacion, componente) %>%
  summarise(
    azar_p025 = quantile(correlacion_azar, 0.025, na.rm = TRUE),
    azar_mediana = median(correlacion_azar, na.rm = TRUE),
    azar_p975 = quantile(correlacion_azar, 0.975, na.rm = TRUE),
    .groups = "drop"
  )

resultados_consistencia <- consistencia_observada %>%
  left_join(
    resumen_azar,
    by = c("metrica", "regularizacion", "componente")
  ) %>%
  left_join(
    consistencia_azar %>%
      inner_join(
        consistencia_observada %>%
          dplyr::select(
            metrica, regularizacion, componente,
            correlacion_pearson
          ),
        by = c("metrica", "regularizacion", "componente")
      ) %>%
      group_by(metrica, regularizacion, componente) %>%
      summarise(
        p_permutacion = (
          1 + sum(
            abs(correlacion_azar) >= abs(correlacion_pearson),
            na.rm = TRUE
          )
        ) / (1 + sum(!is.na(correlacion_azar))),
        .groups = "drop"
      ),
    by = c("metrica", "regularizacion", "componente")
  ) %>%
  mutate(
    supera_azar_95 = correlacion_pearson > azar_p975,
    metrica = factor(metrica, levels = c("RAPM", "EPTS", "wEPTS")),
    regularizacion = factor(
      regularizacion,
      levels = c("Ridge", "Elastic Net", "LASSO")
    ),
    componente = factor(
      componente,
      levels = c("Ofensivo", "Defensivo")
    )
  ) %>%
  arrange(metrica, regularizacion, componente)

tabla_consistencia <- resultados_consistencia %>%
  transmute(
    Metrica = metrica,
    Regularizacion = regularizacion,
    Componente = componente,
    Jugadores = jugadores_comparados,
    Pearson = correlacion_pearson,
    Spearman = correlacion_spearman,
    Mediana_azar = azar_mediana,
    LI_azar = azar_p025,
    LS_azar = azar_p975,
    p_permutacion
  )

print(tabla_consistencia)

# -----------------------------------------------------------------------------
# 11. Gráfico de las 18 correlaciones
# -----------------------------------------------------------------------------

colores_componente <- c(
  "Ofensivo" = "steelblue3",
  "Defensivo" = "#E38D65"
)

posicion <- position_dodge(width = 0.55)

grafico_consistencia <- ggplot(
  resultados_consistencia,
  aes(
    x = correlacion_pearson,
    y = regularizacion,
    color = componente,
    group = componente
  )
) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed",
    color = "grey45",
    linewidth = 0.6
  ) +
  geom_errorbar(
    aes(
      xmin = azar_p025,
      xmax = azar_p975
    ),
    orientation = "y",
    position = posicion,
    width = 0.16,
    linewidth = 1.1,
    color = "grey65"
  ) +
  geom_point(
    position = posicion,
    size = 2
  ) +
  facet_wrap(~ metrica, nrow = 1) +
  scale_color_manual(values = colores_componente) +
  coord_cartesian(xlim = c(-0.25, 1)) +
  labs(
    x = "Correlación de Pearson entre particiones",
    y = NULL,
    color = "Componente",
    caption = paste(
      "Los segmentos grises representan el intervalo central del 95%",
      "de las correlaciones obtenidas al permutar los jugadores."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    legend.position = "bottom"
  )

grafico_consistencia

tabla_consistencia_final <- tabla_consistencia

# saveRDS(tabla_consistencia_final, "tabla_consistencia.RDS")

# tabla_consistencia_partidos_completos <- tabla_consistencia

# ggsave(
#   "img/consistencia_modelos.pdf",
#   grafico_consistencia,
#   width = 7,
#   height = 5
# )

# -----------------------------------------------------------------------------
# 12. Tabla opcional con kableExtra
# -----------------------------------------------------------------------------

# tabla_consistencia %>%
#   mutate(
#     across(
#       c(Pearson, Spearman, Mediana_azar, LI_azar, LS_azar, p_permutacion),
#       ~ round(.x, 3)
#     )
#   ) %>%
#   knitr::kable(
#     col.names = c(
#       "Métrica", "Regularización", "Componente", "Jugadores",
#       "Pearson", "Spearman", "Mediana azar", "LI azar",
#       "LS azar", "p"
#     ),
#     caption = "Consistencia de los ratings entre particiones",
#     booktabs = TRUE,
#     linesep = ""
#   ) %>%
#   kableExtra::kable_styling(
#     full_width = FALSE,
#     position = "center"
#   )
