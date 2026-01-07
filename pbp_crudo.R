library(dplyr)
library(stringr)
library(writexl)

c = data.frame(a = unique(pbp.crudo.temporada$accion))

a =pbp.crudo.temporada %>%
  group_by(partido_key) %>%
  count()

hist(a$n)  



b = pbp.crudo.temporada %>%
  filter(cuarto == 5) %>%
  distinct(partido_key)

pbp.crudo.temporada %>% semi_join(b, by = "partido_key") %>%
  count(partido_key)

write_xlsx(c, "acciones.xlsx")

maximos = pbp_preprocesado_temporada %>%
             group_by(partido_key)%>%
             summarise(max(posesion))

partido1 = pbp.crudo.temporada %>%
  filter(partido_key == "GIMNASIA (CR) vs REGATAS (C) (003/05/2025 20:30)")

partido11 = pbp_preprocesado_temporada %>%
  filter(partido_key == "GIMNASIA (CR) vs REGATAS (C) (003/05/2025 20:30)")


a = partido1 %>%
  mutate(
    n_comillas_simples = str_count(quinteto_local, "'")
  )

partido1$quinteto_local
