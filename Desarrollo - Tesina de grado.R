#Desarrollo

library(tidyverse)
library(limSolve)
library(MASS)
#library(dplyr)
#library(tidyr)

poss_by_poss_temporada <- read_csv("data/poss_by_poss_temporada.csv")
poss_by_poss_temporada <- poss_by_poss_temporada[,-1]

#1)Me doy cuenta que hay jugadores repetidos en la base de datos.

#Que mierda pasa con ARN BUSTAMANTE, LUCAS MARTIN... está repetido, el y muchos otros! revisar

a = as.data.frame(colSums(poss_by_poss_temporada[, 23:373] != 0))

#eliminar: ARN BUSTAMANTE, LUCAS  MARTIN, COSTA,  ALBANO NAHUEL, 

#juntar: GRÜN, FEDERICO JOSE, GRUN, FEDERICO JOSE ... MAINOLDI, LEONARDO ANDRES , MAINOLDI , LEONARDO ANDRES

poss_by_poss_temporada = poss_by_poss_temporada %>% 
  select(- c(`ARN BUSTAMANTE, LUCAS  MARTIN`,`COSTA,  ALBANO NAHUEL` ))

poss_by_poss_temporada = poss_by_poss_temporada %>% 
  mutate(`GRÜN, FEDERICO JOSE` = `GRÜN, FEDERICO JOSE` + `GRUN, FEDERICO JOSE`, `MAINOLDI, LEONARDO ANDRES` = `MAINOLDI, LEONARDO ANDRES` + `MAINOLDI , LEONARDO ANDRES`) %>%
  select(- c(`GRUN, FEDERICO JOSE`,`MAINOLDI , LEONARDO ANDRES`))

#2)Revisar poss by poss y pbp preprec el tema del equipo_accion

#Error increible, los equipo acción estan mal... ya desde el preprocesado
jug_eq1 = poss_by_poss_temporada %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))

#Pero en el play by play estan bien... mmm revisar
jug_eq = df_pbp_final %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))
#--------------------------------------------------------------------------------------------------------------------------------------

#Cálculo del +/-

plus_minus = poss_by_poss_temporada[, 24:369]*poss_by_poss_temporada[[23]]

df_plus_minus <- plus_minus %>%
  summarise(across(everything(), sum))%>%
  pivot_longer(
    cols = everything(),
    names_to = "Jugador",
    values_to = "+/-"
  )

#Faltaría agregar los equipos a esa tabla de jugadores y +/- creo que sería de interes. Hay algunos jugadores que estuvieron en más de un equipo a lo largo de la temporada, ver que hacer en ese caso.

# Modelo de prueba - pocos partidos - 1 partido

df_1partido = poss_by_poss_temporada %>% 
                     filter(partido_key == "BOCA vs ZARATE BASKET (012/10/2024 11:30)")
# +/-

plus_minus_1partido = df_1partido[, 24:369]*df_1partido[[23]]

cols_ceros = names(df_1partido[, 24:369])[colSums(df_1partido[, 24:369] != 0) == 0 ]

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
  filter(partido_key == "BOCA vs ZARATE BASKET (012/10/2024 11:30)") %>% 
  select(23:369)%>% 
  select(-cols_ceros)

modelo1 = lm(puntos_pos ~ . , data = dfmod_1partido)

summary(modelo1) #Analizar más

alias(modelo1)

#Hay 4 coeficientes que no se pueden estimar debido a singularidades ya que son pocas filas y muchos jugadores comparten todos los minutos en cancha, lo que genera dependencia lineal en las columnas

# Modelo de prueba - pocos partidos - 3 partido

df_3partido = poss_by_poss_temporada %>% 
  filter(partido_key %in% c("ATENAS (C) vs BOCA (007/10/2024 22:10)", "BOCA vs ZARATE BASKET (012/10/2024 11:30)", "ZARATE BASKET vs ATENAS (C) (010/12/2024 21:00)"))

# +/-

plus_minus_3partido = df_3partido[, 24:369]*df_3partido[[23]]

cols_ceros_3 = names(df_3partido[, 24:369])[colSums(df_3partido[, 24:369] != 0) == 0 ]

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
  select(23:369)%>% 
  select(-cols_ceros_3)

modelo2 = lm(puntos_pos ~ . , data = dfmod_3partido)

summary(modelo2) #Analizar más

#Hay 4 coeficientes que no se pueden estimar debido a singularidades ya que son pocas filas y muchos jugadores comparten todos los minutos en cancha, lo que genera dependencia lineal en las columnas

# Toda la base

# Modelo de regresión lineal múltiple

plus_minus_temporada = poss_by_poss_temporada[, 24:369]*poss_by_poss_temporada[[23]]

#cols_ceros_temp = names(poss_by_poss_temporada[, 24:369])[colSums(poss_by_poss_temporada[, 24:369] != 0) == 0 ]

dfmod_temporada = poss_by_poss_temporada %>% select(23:369)

modelo_temp = lm(puntos_pos ~ . , data = dfmod_temporada)

summary(modelo_temp)

#Solo 1 coeficiente no pudo estimarse por singularidad, y se debe a que la suma de las filas dan siempre 0

Coeficientes = as.data.frame(modelo_temp$coefficients)

#Mínimos cuadrados restringidos

X <- model.matrix(
  puntos_pos ~ . - 1,
  data = dfmod_temporada
)

y <- dfmod_temporada$puntos_pos

##Calculo el modelo con la restricción (suma de betas igual a 0)

C <- matrix(1, nrow = 1, ncol = ncol(X))  # vector de 1s
d <- 0 # resultado de la suma

# Ajuste de coeficientes

fit <- lsei(A = X, B = y, E = C, F = d)

beta_hat <- fit$X

beta_hat <- setNames(beta_hat, colnames(X))
beta_hat = as.data.frame(beta_hat)

# Con Moore-Penrose

beta_mp <- ginv(X) %*% y
beta_mp <- as.vector(beta_mp)
names(beta_mp) <- colnames(X)
beta_mp = as.data.frame(beta_mp)
