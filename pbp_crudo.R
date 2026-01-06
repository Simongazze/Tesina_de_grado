library(dplyr)
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
