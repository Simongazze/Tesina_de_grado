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

a =pbp_preprocesado_temporada %>%
  group_by(partido_key, cuarto) %>%
  count()

hist(a$n)  

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

#Corregimos error y eliminamos al jugador que no corresponde, Merchant

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

#Revision de posesiones con cantidad de puntos raras, habia -2,-4,0,1,2,3,4,5,6,7 y 8 puntos en una posesión

unique(poss_by_poss_temporada$puntos_pos)

#1)-4 y 8 puntos

prueba = poss_by_poss_temporada %>%
  filter(puntos_pos == -4)

prueba = poss_by_poss_temporada %>%
  filter(puntos_pos == 8)

prueba2 = pbp_preprocesado_temporada %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")

prueba2_a = pbp_preprocesado_temporada1 %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")

prueba3 = df_pbp_final %>%
  filter(partido_key == "QUIMSA vs BOCA (019/10/2024 11:30)")

# se detecta una inconsistencia a la hora de cargar los datos, en el partido QUIMSA vs BOCA (019/10/2024 11:30)
# en el cuarto 3 minutos 02:27 hasta el minuto 00:40 hay un error en el conteo de puntos.
# Este error proviene de la página web, y fue generado (probablemente) por un error en la 
# mesa de control. Con el triple de CUELLO, MARTIN NICOLAS a los 40 segundos del tercer cuarto
# el conteo vuelve al valor correcto, quedan por modificarse las celdas intermedias y el conteo
# de puntos por posesion

prueba3 = poss_by_poss_temporada %>%
  filter(puntos_pos == -2)

prueba4 = pbp_preprocesado_temporada %>%
  filter(partido_key == "OBERA vs OBRAS (027/04/2025 21:00)")

prueba4_a = pbp_preprocesado_temporada1 %>%
  filter(partido_key == "OBERA vs OBRAS (027/04/2025 21:00)")

#Error de carga desde cuarto 2 minuto 00:14 a 00:00

prueba5 = pbp_preprocesado_temporada %>%
  filter(partido_key == "OBERA vs OLIMPICO (LB) (002/02/2025 20:30)")

#Error de carga cuarto 2 minuto 04:15 hasta 03:48

prueba6 = pbp_preprocesado_temporada %>%
  filter(partido_key == "ZARATE BASKET vs PEÑAROL (MDP) (023/10/2024 21:00)")

#Error de carga cuarto 1 minuto 01:00 a 00:57

prueba14 = df_pbp_final %>%
  filter(partido_key == "ZARATE BASKET vs PLATENSE (012/11/2024 20:00)", cuarto == 1)

prueba14a = poss_by_poss_temporada %>%
  filter(partido_key == "ZARATE BASKET vs PLATENSE (012/11/2024 20:00)", cuarto == 1)

#Error de carga cuarto 1 07:46 hasta 07:00, y del 7:30 al 7:28 hay dos CANASTAS DE 2 PUNTOS
#consecutivas sin haber perdidas o cualquier otra acción de por medio.

# Anotaciones altas

prueba = poss_by_poss_temporada %>%
  filter(puntos_pos == 7)

prueba7 = pbp_preprocesado_temporada %>%
  filter(partido_key == "OLIMPICO (LB) vs FERRO (009/12/2024 22:00)")

#hay 3 posesiones en 1, dos canastas de 2 puntos y un triple. El tema es que no hay ninguna accion 
#del rival entre medio, es rarisimo.

prueba = poss_by_poss_temporada %>%
  filter(puntos_pos == 6)

prueba8 = df_pbp_final %>%
  filter(partido_key == "FERRO vs QUIMSA (021/04/2025 16:00)", cuarto == 3) #2 triples

#Revisar FERRO vs QUIMSA (021/04/2025 16:00), en el cuarto 1 y 2 las ultimas acciones
#de cada cuarto estan en el minuto 4 y 3 aproximadamente, lo que da indicios de errores en
#la carga de las acciones porque es imposible que no hallá ninguna acción en ese tiempo

prueba9 = df_pbp_final %>%
  filter(partido_key == "INDEPENDIENTE (O) vs QUIMSA (030/11/2024 20:30)", cuarto == 3)

# En este caso hay un doble, al parecer hay una falta en el momento del tiro al jugador ofensivo que
# peleaba el rebote, como el equipo estaba en bonus fue a la linea, convirtio el primero,
# falló el segundo y tomaron el rebote ofensivo, luego convirtieron un triple obteniendo así
# una única posesión donde se convirtieron 6 puntos.

prueba10 = pbp_preprocesado_temporada1 %>%
  filter(partido_key == "OBERA vs BOCA (005/11/2024 21:00)", cuarto == 1) 
# 2 triples

prueba11 = df_pbp_final %>%
  filter(partido_key == "OLIMPICO (LB) vs ZARATE BASKET (004/11/2024 22:00)", cuarto == 2)
#Triple, falta ofensiva que está a solo 4 segundos del triple por lo q no se cuenta en la base, y otro triple

prueba12 = df_pbp_final %>%
  filter(partido_key == "PLATENSE vs OBRAS (026/03/2025 20:30)", cuarto == 1)
#2 triples

prueba13 = df_pbp_final %>%
  filter(partido_key == "REGATAS (C) vs GIMNASIA (CR) (002/12/2024 21:30)", cuarto == 2)
#triple, doble y luego libre, muy raro, deberian ser 2 posesiones triple y luego las otras

#Faltaria revisar los de 5 puntos pero es claro que los errores son de carga

prueba = poss_by_poss_temporada %>%
  filter(puntos_pos == 5)

#diferencia de tiempo entre acciones PENDIENTE

#Cantidad de puntos por posesion

a = poss_by_poss_temporada %>%
      group_by(puntos_pos) %>%
      count()

sum(a$n*a$puntos_pos)

#Yo creo que si soluciono los negativos y los de 6,7 y 8 puntos estaría bien, quizas los de 5 y 4 tengan varios errores pero debere convivir con ellos

#podriamos llevar el conteo de puntos de manera diferente para evitar estos problemas

#Solución al problema de los puntos mal cargados: Al identificar errores en la página web a la hora
#de ir contabilizando los puntos, decidi corregir esto "manualmente". Se identificó que solo hay 3 posibles
#tipos de acciones que suman puntos: TIRO LIBRE ANOTADO, CANASTA DE 2 PUNTOS y TRIPLE. Así que se agregan
#2 nuevas columnas, puntos_local_manual y puntos_visitante_manual en los cuales acumularemos los puntos
#identificados a traves de la columna accion para de esta manera no tener ese tipo de errores

pbp_preprocesado_temporada1 <- pbp_preprocesado_temporada %>%
  group_by(partido_key) %>%
  mutate(
    # Incrementos de puntos por acción
    inc_local = case_when(
      accion == "TIRO LIBRE ANOTADO" & tipo_equipo_accion == "local" ~ 1,
      accion == "CANASTA DE 2 PUNTOS" & tipo_equipo_accion == "local" ~ 2,
      accion == "TRIPLE" & tipo_equipo_accion == "local" ~ 3,
      TRUE ~ 0
    ),
    inc_visitante = case_when(
      accion == "TIRO LIBRE ANOTADO" & tipo_equipo_accion == "visitante" ~ 1,
      accion == "CANASTA DE 2 PUNTOS" & tipo_equipo_accion == "visitante" ~ 2,
      accion == "TRIPLE" & tipo_equipo_accion == "visitante" ~ 3,
      TRUE ~ 0
    ),
    
    # Acumulados por partido (el orden ya es correcto)
    puntos_acum_local_manual = rev(cumsum(rev(inc_local))),
    puntos_acum_visitante_manual = rev(cumsum(rev(inc_visitante)))
  ) %>%
  ungroup() %>%
  select(-inc_local, -inc_visitante)

# Reemplazo pts_fin_loc y pts_fin_vis

pbp_preprocesado_temporada1 = pbp_preprocesado_temporada1 %>%
                                    mutate(pts_fin_loc = ifelse(is.na(pts_fin_loc), pts_fin_loc, puntos_acum_local_manual),
                                          pts_fin_vis = ifelse(is.na(pts_fin_vis), pts_fin_vis, puntos_acum_visitante_manual))


#write.csv(pbp_preprocesado_temporada1, "df_pbp_final_preproc.csv")

#Identificar acciones imposibles juntas

acciones_validas <- c("CANASTA DE 2 PUNTOS", "TRIPLE")

pbp_dobles_consecutivos <- pbp_preprocesado_temporada1 %>%
  group_by(partido_key, cuarto) %>%
  mutate(
    accion_prev  = lag(accion),
    equipo_prev  = lag(tipo_equipo_accion),
    accion_next  = lead(accion),
    equipo_next  = lead(tipo_equipo_accion),
    
    es_segunda = accion %in% acciones_validas &
      accion_prev %in% acciones_validas &
      tipo_equipo_accion == equipo_prev,
    
    es_primera = accion %in% acciones_validas &
      accion_next %in% acciones_validas &
      tipo_equipo_accion == equipo_next
  ) %>%
  ungroup() %>%
  filter(es_primera | es_segunda)

pbp_multi_anotacion_sin_ro <- pbp_preprocesado_temporada1 %>%
  group_by(partido_key, posesion) %>%
  filter(
    # ≥ 2 anotaciones válidas
    sum(accion %in% acciones_validas, na.rm = TRUE) >= 2,
    
    # NO existe "REBOTE OFENSIVO" en la posesión
    !any(grepl("REBOTE OFENSIVO", accion))
  ) %>%
  ungroup()

# Voy a cortar acá la limpieza de los datos, queda por revisar en un futuro las faltas cometidas que dejo y las
#posesiones con mas de un tipo de anotación y que no presentan rebote ofensivo

# No veria mal pasar lo que haya hecho acá a python para quedar con el trabajo de los datos ahí
