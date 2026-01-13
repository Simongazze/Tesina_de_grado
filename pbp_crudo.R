library(dplyr)
library(stringr)
library(writexl)

#faltas cometidas revision

df_pbp_final %>%
  filter(accion == "FALTA COMETIDA") %>%
  count()

pbp_preprocesado_temporada %>%
  filter(accion == "FALTA COMETIDA") %>%
  count()

#Pareceria correcto, en la fila 88 pareciera haber un error



a =df_pbp_final %>%
  group_by(partido_key, cuarto) %>%
  count()

hist(a$n)  



b = pbp.partido.crudo %>%
  filter(cuarto == 5) %>%
  distinct(partido_key)

pbp.crudo.temporada %>% semi_join(b, by = "partido_key") %>%
  count(partido_key)

unique(pbp_preprocesado_temporada$accion)

write_xlsx(c, "acciones.xlsx")

maximos = pbp_preprocesado_temporada %>%
             group_by(partido_key)%>%
             summarise(max(posesion))

sum(maximos$`max(posesion)`)

write.csv(df_pbp_final, "df_pbp_final.csv")

#Partido con error

partido1 = df_pbp_final %>%
  filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)", cuarto == 2)

partido2 = pbp_preprocesado_temporada %>%
  filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)", cuarto == 2)

unique(partido1$quinteto_local)
unique(partido2$quinteto_local)

#Corregimos error y eliminamos al jugador que no corresponde

library(stringr)

# 1. Definimos el rango exacto de filas afectadas
# Esto crea un vector con todos los números desde 60979 hasta 61041
filas_afectadas <- 60979:61041

# 2. Corregimos la variable numérica (restamos 1)
# Solo modificamos las filas indicadas en el índice
df_pbp_final$jugadores_en_cancha[filas_afectadas] <- df_pbp_final$jugadores_en_cancha[filas_afectadas] - 1

# 3. Eliminamos al jugador 'MERCHANT, EDGAR HENRY'
# IMPORTANTE: Observa que en el patrón a eliminar incluyo ", " (coma y espacio)
# al principio. Esto es para borrar ", 'MERCHANT...'" y que la lista no quede
# con dos comas seguidas (ej: 'JUGADOR A', , 'JUGADOR C').

df_pbp_final$quinteto_local[filas_afectadas] <- str_remove(
  string = df_pbp_final$quinteto_local[filas_afectadas], 
  pattern = ", 'MERCHANT, EDGAR HENRY'"
)

#Otra cosa

#No olvidar el error producido por las posesiones que arrancan en un quinteto y terminan con otro.

# Error de nombres con espacio
partido11 = pbp_preprocesado_temporada %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")

#   Cuento jugadores locales y visitantes
a = poss_by_poss_temporada %>%
  mutate(
    local = str_count(quinteto_local, "'"),
    visitante = str_count(quinteto_visita, "'")
  )

local = a %>%
  filter(local == 9)

local$MAXWELL..DU.VAUGHN.ELISHA

visitante = a %>%
  filter(visitante == 9)

visitante$MAXWELL..DU.VAUGHN.ELISHA

accion_vacia = df_pbp_final %>%
                filter(jugador == "")

unique(accion_vacia$accion)

