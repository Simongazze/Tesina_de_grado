# Ejecutar desde la raiz del repositorio:
# source("actualizar_rankings.R")
# df_rankings <- actualizar_rankings(df_rankings)
#
# Sin argumentos, lee y actualiza el CSV publicado, sin cargar los modelos:
# actualizar_rankings()

actualizar_rankings <- function(df_rankings = NULL,
                                archivo = file.path("docs", "rankings.csv")) {
  if (is.null(df_rankings)) {
    if (!file.exists(archivo)) stop("No existe el CSV: ", archivo)
    df_rankings <- read.csv(
      archivo, stringsAsFactors = FALSE, check.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }

  requeridas <- c("jugador", "equipo_del_jugador", "posesiones_totales", "plus_minus_100")
  faltantes <- setdiff(requeridas, names(df_rankings))
  if (length(faltantes)) stop("Faltan columnas: ", paste(faltantes, collapse = ", "))
  if (!nrow(df_rankings)) stop("La base de rankings esta vacia.")
  if (!is.numeric(df_rankings$posesiones_totales) ||
      !is.numeric(df_rankings$plus_minus_100)) {
    stop("Posesiones y plus_minus_100 deben ser columnas numericas.")
  }
  if (anyNA(df_rankings$equipo_del_jugador) ||
      any(!is.finite(df_rankings$posesiones_totales)) ||
      any(!is.finite(df_rankings$plus_minus_100))) {
    stop("Faltan datos validos para calcular el plus-minus estandarizado.")
  }

  # Misma definicion que en Desarrollo - Tesina de grado.Rmd.
  # La referencia se calcula una vez por equipo, con mas de 500 posesiones.
  equipos <- unique(as.character(df_rankings$equipo_del_jugador))
  centros <- dispersiones <- setNames(numeric(length(equipos)), equipos)
  for (equipo in equipos) {
    referencia <- df_rankings$plus_minus_100[
      df_rankings$equipo_del_jugador == equipo &
        df_rankings$posesiones_totales > 500
    ]
    if (!length(referencia)) stop("Sin referencia de mas de 500 posesiones: ", equipo)
    centros[[equipo]] <- median(referencia)
    dispersiones[[equipo]] <- mad(referencia, constant = 1.4826)
    if (!is.finite(dispersiones[[equipo]]) || dispersiones[[equipo]] <= 0) {
      stop("MAD nulo o no valido en ", equipo, "; revisar antes de publicar.")
    }
  }
  grupo <- as.character(df_rankings$equipo_del_jugador)
  df_rankings$pm_estand_median <- unname(
    (df_rankings$plus_minus_100 - centros[grupo]) / dispersiones[grupo]
  )

  dir.create(dirname(archivo), recursive = TRUE, showWarnings = FALSE)
  write.csv(df_rankings, archivo, row.names = FALSE, fileEncoding = "UTF-8")
  message("Actualizado ", archivo, ": ", nrow(df_rankings), " registros.")
  invisible(df_rankings)
}
