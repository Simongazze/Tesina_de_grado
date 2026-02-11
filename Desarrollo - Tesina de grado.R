#Desarrollo

#Cálculo del +/-

library(tidyverse)
#library(dplyr)
#library(tidyr)

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

#Error increible, los equipo acción estan mal... ya desde el preprocesado
jug_eq1 = poss_by_poss_temporada %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))

#Pero en el play by play estan bien... mmm revisar
jug_eq = df_pbp_final %>%
          group_by(jugador_limpio) %>%
          summarise(equipos = n_distinct(equipo_accion))


# Modelo de prueba - pocos partidos - 1 partido

df_1partido = poss_by_poss_temporada %>% 
                     filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)")
# +/-

plus_minus_1partido = df_1partido[, 24:373]*df_1partido[[23]]

cols_ceros = names(plus_minus_1partido)[colSums(plus_minus_1partido != 0) == 0 ]

plus_minus_1partido = plus_minus_1partido %>% 
                        select(-cols_ceros)

df_plus_minus_1partido <- plus_minus_1partido %>%
  summarise(across(everything(), sum))%>%
  pivot_longer(
    cols = everything(),
    names_to = "jugador_limpio",
    values_to = "+/-"
  )

jug_eq_1partido = df_1partido %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = unique(equipo_accion))

df_plus_minus_1partido = df_plus_minus_1partido %>% 
                              left_join(jug_eq_1partido)


# Modelo de regresión lineal múltiple

dfmod_1partido = poss_by_poss_temporada %>% 
  filter(partido_key == "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)") %>% 
  select(23:373)%>% 
  select(-cols_ceros)

modelo1 = lm(puntos_pos ~ . , data = dfmod_1partido)

summary(modelo1) #Analizar más

alias(modelo1)

round(cor(x = dfmod_1partido, method = "pearson"), 3)

# como la suma de la filas siempre da 0 hay que reparametrizar

X <- model.matrix(~ . - 1, data = dfmod_1partido[, -which(names(dfmod_1partido) == "puntos_pos")])
qr(X)$rank
ncol(X)

library(MASS)
Z <- Null(t(X))
dim(Z)




# Modelo de prueba - pocos partidos - 3 partido

df_3partido = poss_by_poss_temporada %>% 
  filter(partido_key %in% c("ATENAS (C) vs BOCA (007/10/2024 22:10)", "BOCA vs ZARATE BASKET (012/10/2024 11:30)", "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)"))

# +/-

plus_minus_3partido = df_3partido[, 24:373]*df_3partido[[23]]

cols_ceros_3 = names(plus_minus_3partido)[colSums(plus_minus_3partido != 0) == 0 ]

plus_minus_3partido = plus_minus_3partido %>% select(-cols_ceros_3)

df_plus_minus_3partido <- plus_minus_3partido %>%
  summarise(across(everything(), sum))%>%
  pivot_longer(
    cols = everything(),
    names_to = "jugador_limpio",
    values_to = "+/-"
  )

# Modelo de regresión lineal múltiple

dfmod_3partido = poss_by_poss_temporada %>% 
  filter(partido_key %in% c("ATENAS (C) vs BOCA (007/10/2024 22:10)", "BOCA vs ZARATE BASKET (012/10/2024 11:30)", "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)")) %>% 
  select(23:373)%>% 
  select(-cols_ceros_3)

modelo2 = lm(puntos_pos ~ . , data = dfmod_3partido)

summary(modelo2) #Analizar más


a = as.data.frame(modelo2$coefficients)

#Probar con 10 partidos

#Probar con toda la base

#Probar con ridge

#probar quitando jugadores con menos de 300 minutos




