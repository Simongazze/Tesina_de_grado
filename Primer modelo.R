library(readxl)
library(lm)

datos_01 <- read_excel("datos_01.xlsx")

lm(puntos_pos ~ `THORNTON, WILLIE ALFORD`, data = datos_01)

sum(datos_01$puntos_pos*datos_01$`WALLACE, DEVANTE RASHAD-KEITH`)
