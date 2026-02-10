#Desarrollo

#Cálculo del +/-

library(tidyverse)

poss_by_poss_temporada <- read_csv("data/poss_by_poss_temporada.csv")
poss_by_poss_temporada <- poss_by_poss_temporada[,-1]

plus_minus = poss_by_poss_temporada[, 24:373]*poss_by_poss_temporada[[23]]

df_plus_minus <- plus_minus %>%
  summarise(across(everything(), sum))%>%
  pivot_longer(
    cols = everything(),
    names_to = "Jugador",
    values_to = "+/-"
  )


#Faltaría agregar los equipos a esa tabla de jugadores y +/- creo que sería de interes. Hay algunos jugadores que estuvieron en más de un equipo a lo largo de la temporada, ver que hacer en ese caso.



#Error increible, los equipo acción estan mal
jug_eq1 = poss_by_poss_temporada %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))

#Pero en el play by play estan bien... mmm revisar
jug_eq2 = df_pbp_final %>%
          group_by(jugador_limpio) %>%
          summarise(equipos = n_distinct(equipo_accion))
