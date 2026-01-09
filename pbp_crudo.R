library(dplyr)
library(stringr)
library(writexl)

c = data.frame(a = unique(pbp.partido.crudo$accion))

a =pbp.partido.crudo %>%
  group_by(partido_key) %>%
  count()

hist(a$n)  



b = pbp.partido.crudo %>%
  filter(cuarto == 5) %>%
  distinct(partido_key)

pbp.crudo.temporada %>% semi_join(b, by = "partido_key") %>%
  count(partido_key)

write_xlsx(c, "acciones.xlsx")

maximos = pbp_preprocesado_temporada %>%
             group_by(partido_key)%>%
             summarise(max(posesion))

partido1 = pbp.partido.crudo %>%
  filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)")

partido11 = pbp_preprocesado_temporada %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")


a = pbp.partido.crudo %>%
  mutate(
    n_comillas_simples = str_count(quinteto_local, "'")
  )

unique(a$n_comillas_simples)
