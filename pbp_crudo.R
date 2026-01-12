library(dplyr)
library(stringr)
library(writexl)

#faltas cometidas revision

acciones_partido_crudo %>%
  filter(accion == "FALTA COMETIDA") %>%
  count()

pbp_preprocesado_temporada %>%
  filter(accion == "FALTA COMETIDA") %>%
  count()

#Pareceria correcto, en la fila 88 pareciera haber un error



a =pbp.partido.crudo %>%
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

#Partido con error

partido1 = `pbp_preprocesado_temporada.(1)` %>%
  filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)")

partido1$quinteto_local[259]

partido11 = pbp_preprocesado_temporada %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")


a = pbp.partido.crudo %>%
  mutate(
    local = str_count(quinteto_local, "'"),
    visitante = str_count(quinteto_visita, "'")
  )


accion_vacia = pbp.partido.crudo %>%
                filter(jugador == "")

unique(accion_vacia$accion)

