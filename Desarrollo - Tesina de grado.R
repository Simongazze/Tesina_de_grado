#Desarrollo

library(tidyverse)
library(limSolve)
library(MASS)
library(readxl)
library(hms)
#library(dplyr)
#library(tidyr)

poss_by_poss_temporada <- read_csv("data/poss_by_poss_temporada.csv")
poss_by_poss_temporada <- poss_by_poss_temporada[,-1]

#1)Me doy cuenta que hay jugadores repetidos en la base de datos.

#Inicialmente 2 jugadores con 0 posesiones en toda la base hacen surgir esa duda, y se suman 2 jugadores con nombres cargados de distinta manera a lo largo de la temporada
#Se decide unificar estos 4 jugadores repetidos, AGREGAR EN TESIS.

a = as.data.frame(colSums(poss_by_poss_temporada[, 23:373] != 0))

#eliminar: ARN BUSTAMANTE, LUCAS  MARTIN, COSTA,  ALBANO NAHUEL, 

#juntar: GRÜN, FEDERICO JOSE, GRUN, FEDERICO JOSE ... MAINOLDI, LEONARDO ANDRES , MAINOLDI , LEONARDO ANDRES

poss_by_poss_temporada = poss_by_poss_temporada %>% 
  dplyr::select(- c(`ARN BUSTAMANTE, LUCAS  MARTIN`,`COSTA,  ALBANO NAHUEL` ))

poss_by_poss_temporada = poss_by_poss_temporada %>% 
  mutate(`GRÜN, FEDERICO JOSE` = `GRÜN, FEDERICO JOSE` + `GRUN, FEDERICO JOSE`, `MAINOLDI, LEONARDO ANDRES` = `MAINOLDI, LEONARDO ANDRES` + `MAINOLDI , LEONARDO ANDRES`) %>%
  dplyr::select(- c(`GRUN, FEDERICO JOSE`,`MAINOLDI , LEONARDO ANDRES`))

#2)Revisar poss by poss y pbp preprec el tema del equipo_accion

#Error increible, los equipo acción estan mal... ya desde el preprocesado

#SOLUCIONAR, actualmente pueden calcularse los modelos pero servirá a futuro para agregar variables explicativas.
jug_eq1 = poss_by_poss_temporada %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))

#Pero en el play by play estan bien... mmm revisar
jug_eq = df_pbp_final %>%
  group_by(jugador_limpio) %>%
  summarise(equipos = n_distinct(equipo_accion))

#Agregamos una nueva variable que sea equipo_accion_limpio

poss_by_poss_temporada <- poss_by_poss_temporada %>%
  mutate(
    equipos = str_split(partido_key, " vs "),
    equipo_local = str_trim(sapply(equipos, `[`, 1)),
    equipo_visitante = str_trim(sapply(equipos, `[`, 2)),
    
    # opcional: limpiar lo que venga después del nombre (paréntesis, fecha, etc.)
    equipo_local = str_remove(equipo_local, " \\(.*"),
    equipo_visitante = str_remove(equipo_visitante, " \\(.*"),
    
    equipo_limpio = if_else(
      tipo_equipo_accion == "local",
      equipo_local,
      equipo_visitante
    )
  ) %>%
  dplyr::select(-equipos)


#--------------------------------------------------------------------------------------------------------------------------------------

#Box score

box_score <- read_excel("data/Box score - temporada - sin minutos igual a 0.xlsx")

box_score = box_score %>% mutate(Tiempo_mod = as_hms(Tiempo_mod)) 

minutos_jugad = box_score %>% group_by(NombreCompleto_limpio) %>% summarise(Segundos = sum(Tiempo_mod), Minutos = sum(Tiempo_mod)/60, Partidos = n())

minutos_jugad = minutos_jugad %>% mutate(jugador = recode(NombreCompleto_limpio, 
                                                                        "GRUN, FEDERICO JOSE" = "GRÜN, FEDERICO JOSE",
                                                                        "MAINOLDI , LEONARDO ANDRES" = "MAINOLDI, LEONARDO ANDRES")) %>%
  group_by(jugador) %>%
  summarise(
    Segundos = sum(Segundos, na.rm = TRUE),
    Minutos = sum(Minutos, na.rm = TRUE),
    Partidos = sum(Partidos, na.rm = TRUE),
    Minutos_por_part = Minutos/Partidos
  ) %>%
  ungroup()

jug_eq2 = box_score %>%
  group_by(NombreCompleto_limpio) %>%
  summarise(equipos = n_distinct(equipo_normalizado))


#--------------------------------------------------------------------------------------------------------------------------------------
#Cálculo del +/-

plus_minus = poss_by_poss_temporada[, 24:369]*poss_by_poss_temporada[[23]]

df_plus_minus <- plus_minus %>%
  summarise(across(everything(), sum))%>%
  pivot_longer(
    cols = everything(),
    names_to = "jugador",
    values_to = "+/-"
  )

library(tidyverse)

# 1. Definimos el vector con los nombres de los jugadores
#jugador_cols <- colnames(poss_by_poss_temporada)[24:369]

# 2. Transformación y cálculo
#plus_minus_por_equipo <- poss_by_poss_temporada %>%
  # Pasamos de 350 columnas de jugadores a 2 columnas: "jugador" y "presencia"
#  pivot_longer(
#    cols = all_of(jugador_cols),
#    names_to = "jugador_id",
#    values_to = "presencia"
#  ) %>%
  # Nos quedamos solo con las filas donde el jugador participó (1 o -1)
#  filter(presencia != 0) %>%
  # Identificamos en qué equipo estaba jugando en esa posesión
  # Si presencia es 1, estaba en el equipo local. Si es -1, en el visitante.
#  mutate(
#    equipo_del_jugador = if_else(presencia == 1, equipo_limpio, if_else(equipo_limpio == equipo_local,equipo_visitante,equipo_local))
#  ) %>%
  # Agrupamos por el nombre del jugador Y por el equipo en el que estaba
#  group_by(jugador_id, equipo_del_jugador) %>%
#  summarise(
#    plus_minus_total = sum(puntos_pos * presencia, na.rm = TRUE),
#    posesiones_totales = n(),
#    .groups = "drop"
#  ) %>%
  # Opcional: Calcular el +/- cada 100 posesiones para que sea comparable
#  mutate(plus_minus_100 = (plus_minus_total / posesiones_totales) * 100)
#
#plus_minus_por_equipo = plus_minus_por_equipo %>% rename(jugador = jugador_id)

#saveRDS(plus_minus_por_equipo, "plus_minus_por_equipo.RDS")

#Faltaría agregar los equipos a esa tabla de jugadores y +/- creo que sería de interes. Hay algunos jugadores que estuvieron en más de un equipo a lo largo de la temporada, ver que hacer en ese caso. También la cantidad de partidos, quizas sería rico.

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

beta_hat <- data.frame(
  NombreCompleto_limpio = names(beta_hat),
  coeficiente = as.numeric(beta_hat)
)

beta_hat$NombreCompleto_limpio <- gsub("`", "", beta_hat$NombreCompleto_limpio)

# Con Moore-Penrose

beta_mp <- ginv(X) %*% y
beta_mp <- as.vector(beta_mp)
names(beta_mp) <- colnames(X)
beta_mp = as.data.frame(beta_mp)

# La solución de Moore–Penrose coincide con el estimador de mínimos cuadrados bajo restricción de suma cero, ya que la dirección de no identificabilidad coincide con el vector constante.

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Estimación del modelo omitiendo los LTPs Players

# vamos a calcular los minutos en cancha y las posesiones en cancha

posesiones_jug = colSums(poss_by_poss_temporada[, 24:369] != 0)

posesiones_jug <- data.frame(
  NombreCompleto_limpio = names(posesiones_jug),
  posesiones = as.numeric(posesiones_jug)
)

posesiones_jug = posesiones_jug %>% left_join(minutos_jugad)

posesiones_jug = posesiones_jug %>% left_join(beta_hat)

posesiones_jug = posesiones_jug %>% left_join(df_plus_minus)

#-------------------------------------------------

#Separar el efecto del aporte ofensivo y defensivo

#Calcular Ridge

#Pensar en comparar los errores de los parámetros

#Hacerlo con los segmentos
