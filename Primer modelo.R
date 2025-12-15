library(readxl)
library(lm)

datos_01 <- read_excel("datos_01.xlsx")

lm(puntos_pos ~ `THORNTON, WILLIE ALFORD`, data = datos_01)

sum(datos_01$puntos_pos*datos_01$`WALLACE, DEVANTE RASHAD-KEITH`)

datos_02 <- read_excel("poss_by_poss_temporada.xlsx")

datos_03 <- read_excel("match_data.xlsx")

a = unique(datos_02$partido_key)

b = datos_03$Match_Key

setdiff(b,a)

library(dplyr)

df_max <- datos_02 %>%
  group_by(partido_key) %>%
  summarise(
    max_posesiones = max(posesion, na.rm = TRUE)
  )
