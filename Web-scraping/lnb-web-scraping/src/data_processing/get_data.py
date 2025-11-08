from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import pandas as pd
import re
import json
import time
from tqdm import tqdm
from src.utils.utils import DATA_PATHS
from src.utils.utils import (
    calcular_plus_minus_corregido,
    calcular_posesiones,
    contar_posesiones_jugadas_por_equipo,
    calcular_rebotes_disponibles,
    calcular_posesiones_individuales,
    calcular_puntos_ultimo_cuarto,
    calcular_puntos_clutch,
)

def extraer_boxscore_y_pbp(partido_link):
    """Extrae boxscore y play-by-play de un partido dado su link."""
    all_player_stats = []
    acciones_del_partido = []
    driver = None
    df_box_scores = None
    df_acciones_final = None

    try:
        # --- BOX SCORE ---
        options = Options()
        options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
        driver.get(partido_link)
        wait = WebDriverWait(driver, 20)
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.TAG_NAME, "iframe")))
        tab_selector = (By.CSS_SELECTOR, "li.pestana-estadisticas")
        estadisticas_tab_element = wait.until(EC.visibility_of_element_located(tab_selector))
        driver.execute_script("arguments[0].click();", estadisticas_tab_element)
        time.sleep(1)
        iframe_de_datos_selector = (By.CSS_SELECTOR, "div.contenido-estadisticas.activo iframe")
        wait.until(EC.frame_to_be_available_and_switch_to_it(iframe_de_datos_selector))
        html_box_scores = driver.page_source
        soup = BeautifulSoup(html_box_scores, "html.parser")
        divs_nombres = soup.find_all("div", class_="nombre-equipo")
        equipo_local_nombre = divs_nombres[0].get_text(strip=True) if len(divs_nombres) >= 2 else "Local"
        equipo_visitante_nombre = divs_nombres[1].get_text(strip=True) if len(divs_nombres) >= 2 else "Visitante"
        tablas = soup.find_all("table", class_="tabla-estadisticas")
        if len(tablas) >= 2:
            for idx, equipo_nombre in enumerate([equipo_local_nombre, equipo_visitante_nombre]):
                for fila in tablas[idx].find("tbody").find_all("tr", onclick=True):
                    onclick_attr = fila["onclick"]
                    match = re.search(r"(\{.*\})", onclick_attr)
                    if match:
                        json_str = match.group(1).replace("'", '"')
                        player_data = json.loads(json_str)
                        player_data['equipo'] = equipo_nombre
                        all_player_stats.append(player_data)
        if all_player_stats:
            df_box_scores = pd.DataFrame(all_player_stats)
            columnas = ['IdJugador', 'IdClub', 'IdEquipo', 'Nombre', 'NombreCompleto',
                        'Puntos', 'TirosDos', 'TirosTres', 'TirosLibres',
                        'ReboteDefensivo', 'ReboteOfensivo', 'RebotesTotales',
                        'Asistencias', 'Recuperaciones', 'Perdidas',
                        'TaponCometido','TaponRecibido', 'FaltaCometida','FaltaRecibida','Valoracion',
                        'TiempoJuego', 'CincoInicial', 'equipo']
            df_box_scores = df_box_scores[[col for col in columnas if col in df_box_scores.columns]]
            columnas_con_diccionarios = ['TirosDos', 'TirosTres', 'TirosLibres']
            for columna in columnas_con_diccionarios:
                if columna in df_box_scores.columns:
                    df_box_scores[f'{columna}Aciertos'] = df_box_scores[columna].apply(lambda x: x.get('Aciertos', 0))
                    df_box_scores[f'{columna}Fallos'] = df_box_scores[columna].apply(lambda x: x.get('Fallos', 0))
            df_box_scores = df_box_scores.drop(columns=[c for c in columnas_con_diccionarios if c in df_box_scores.columns])
        else:
            return None, None

        # --- PLAY BY PLAY ---
        driver.switch_to.default_content()
        driver.get(partido_link)
        wait = WebDriverWait(driver, 20)
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.TAG_NAME, "iframe")))
        en_vivo_tab = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "li.pestana-en-vivo")))
        driver.execute_script("arguments[0].click();", en_vivo_tab)
        iframe_pbp_selector = (By.CSS_SELECTOR, "div.contenido-en-vivo div:nth-child(2) iframe")
        wait.until(EC.frame_to_be_available_and_switch_to_it(iframe_pbp_selector))
        html_pbp = driver.page_source
        soup = BeautifulSoup(html_pbp, "html.parser")
        contenedor_acciones = soup.find("ul", class_="listadoAccionesPartido")
        if contenedor_acciones:
            acciones = contenedor_acciones.find_all("li", class_="accion")
            for accion in acciones:
                tipo_accion = jugador = cuarto = tiempo = ""
                puntos_local = None 
                puntos_visita = None
                titulo_tag = accion.find("strong", class_="titulo")
                if titulo_tag:
                    tipo_accion = titulo_tag.get_text(strip=True)
                spans_info = accion.find_all("span", class_="informacion")
                if len(spans_info) >= 2:
                    jugador = spans_info[0].get_text(strip=True)
                    tiempo_text = spans_info[1].get_text(strip=True)
                    match = re.search(r"Cuarto\s*(\d+)\s*-\s*(\d{2}:\d{2}:\d{2})", tiempo_text)
                    if match:
                        cuarto = match.group(1)
                        tiempo = match.group(2)
                marcador_tag = accion.find("strong", class_="informacionAdicional")
                if marcador_tag:
                    marcador_texto = marcador_tag.get_text(strip=True)
                    partes_marcador = marcador_texto.split('-')
                    if len(partes_marcador) == 2:
                        try:
                            puntos_local = int(partes_marcador[0].strip())
                            puntos_visita = int(partes_marcador[1].strip())
                        except ValueError:
                            pass
                acciones_del_partido.append({
                    "cuarto": cuarto,
                    "tiempo": tiempo,
                    "accion": tipo_accion,
                    "jugador": jugador,
                    "puntos_local": puntos_local,
                    "puntos_visita": puntos_visita
                })
        if acciones_del_partido:
            df_acciones = pd.DataFrame(acciones_del_partido)
        else:
            return df_box_scores, None

        # --- GENERAR QUINTETOS ---
        player_to_team_map = pd.Series(df_box_scores.equipo.values, index=df_box_scores.NombreCompleto).to_dict()
        nombre_local = df_box_scores['equipo'].unique()[0]
        df_cronologico = df_acciones.iloc[::-1].reset_index(drop=True)
        jugadores_en_cancha = set()
        lista_de_quintetos_mixtos = []
        for _, row in df_cronologico.iterrows():
            accion = row.get('accion', '')
            jugador = row.get('jugador', '')
            accion_upper = accion.upper() if isinstance(accion, str) else ''
            if "ENTRA A PISTA" in accion_upper or "CAMBIO-ENTRA" in accion_upper:
                if pd.notna(jugador) and jugador != '':
                    jugadores_en_cancha.add(jugador)
            elif "ABANDONA LA PISTA" in accion_upper or "CAMBIO-SALE" in accion_upper:
                if pd.notna(jugador) and jugador != '':
                    jugadores_en_cancha.discard(jugador)
            lista_de_quintetos_mixtos.append(sorted(list(jugadores_en_cancha)))
        df_cronologico['quinteto_en_cancha'] = lista_de_quintetos_mixtos
        def dividir_quinteto(quinteto_mixto, roster_map, equipo_local_nombre):
            quinteto_local, quinteto_visita = [], []
            for jugador in quinteto_mixto:
                if roster_map.get(jugador) == equipo_local_nombre:
                    quinteto_local.append(jugador)
                else:
                    quinteto_visita.append(jugador)
            return sorted(quinteto_local), sorted(quinteto_visita)
        nuevas_columnas = df_cronologico['quinteto_en_cancha'].apply(
            lambda q: pd.Series(dividir_quinteto(q, player_to_team_map, nombre_local))
        )
        nuevas_columnas.columns = ['quinteto_local', 'quinteto_visita']
        df_cronologico = pd.concat([df_cronologico, nuevas_columnas], axis=1)
        df_cronologico = df_cronologico.drop(columns=['quinteto_en_cancha'])
        df_acciones_final = df_cronologico.iloc[::-1].reset_index(drop=True)
        return df_box_scores, df_acciones_final
    except Exception as e:
        print(f"Error procesando partido: {e}")
        return None, None
    finally:
        if driver:
            driver.quit()

if __name__ == "__main__":
    # Nombre del archivo de texto que contiene el HTML
    file_name = DATA_PATHS["html_partidos_temporada"]

    # Diccionario para almacenar los datos de los partidos
    match_data = {}
    try:
        # 1. Leer el contenido del archivo .txt
        with open(file_name, "r", encoding="utf-8") as f:
            html_content = f.read()

        # 2. Crear un objeto BeautifulSoup para parsear el HTML
        soup = BeautifulSoup(html_content, "html.parser")
        
        # 3. Buscar todas las filas de la tabla (<tr>)
        filas_partidos = soup.find_all("tr", role="row")
        
        print(f"Extrayendo datos de {len(filas_partidos)} partidos...")

        for fila in filas_partidos:
            # Extraer los datos de las celdas (<td>) de cada fila
            celdas = fila.find_all("td")

            # Asegurarse de que la fila tiene la estructura esperada
            if len(celdas) > 8:
                # Extraer los datos por su índice de celda
                fecha_hora = celdas[0].get_text(strip=True)[-17:]
                nombre_local = celdas[1].get_text(strip=True)
                puntos_local = celdas[3].get_text(strip=True)
                puntos_visita = celdas[4].get_text(strip=True)
                nombre_visita = celdas[6].get_text(strip=True)
                
                # El link está dentro de la celda en el índice 8 (anteriormente 9)
                link_tag = celdas[8].find("a", href=True)
                link_estadisticas = link_tag.get('href') if link_tag else None
                
                # Usar una combinación única como clave del diccionario
                match_key = f"{nombre_local} vs {nombre_visita} ({fecha_hora})"
                
                # Guardar los datos en el diccionario
                match_data[match_key] = {
                    "nombre_local": nombre_local,
                    "puntos_local": puntos_local,
                    "nombre_visita": nombre_visita,
                    "puntos_visita": puntos_visita,
                    "link_estadisticas": link_estadisticas
                }
        
    except FileNotFoundError:
        print(f"Error: No se encontró el archivo '{file_name}'. Asegúrate de que el archivo existe en la ruta correcta.")
    except Exception as e:
        print(f"Ocurrió un error al procesar el archivo: {e}")

    resultados = []
    llaves_partidos = list(match_data.keys())[:10]
    for partido_key in tqdm(llaves_partidos, desc="Procesando partidos"):
        partido_link = match_data[partido_key]["link_estadisticas"]
        df_box_scores, df_acciones_final = extraer_boxscore_y_pbp(partido_link)
        if df_box_scores is None or df_acciones_final is None:
            continue
        player_to_team_map = pd.Series(df_box_scores.equipo.values, index=df_box_scores.NombreCompleto).to_dict()
        df_sorted = df_acciones_final.iloc[::-1].reset_index(drop=True)
        df_plus_minus = calcular_plus_minus_corregido(df_sorted.copy(), player_to_team_map)
        df_posesiones_consumidas = calcular_posesiones(df_sorted.copy())
        df_posesiones_consumidas.rename(columns={'posesiones': 'posesiones_consumidas'}, inplace=True)
        df_posesiones_jugadas = contar_posesiones_jugadas_por_equipo(df_sorted.copy(), df_box_scores.copy(), player_to_team_map)
        df_rebotes_disponibles = calcular_rebotes_disponibles(df_sorted.copy(), df_box_scores.copy(), player_to_team_map)
        df_puntos_q4 = calcular_puntos_ultimo_cuarto(df_acciones_final.copy(), df_box_scores.copy())
        df_puntos_clutch = calcular_puntos_clutch(df_acciones_final.copy(), df_box_scores.copy())
        resultado_final = df_box_scores.copy()
        lista_de_stats = [df_plus_minus, df_posesiones_consumidas, df_posesiones_jugadas, 
                            df_rebotes_disponibles, df_puntos_q4, df_puntos_clutch]
        for df_stat in lista_de_stats:
            df_stat.rename(columns={'jugador': 'NombreCompleto'}, inplace=True)
            resultado_final = pd.merge(resultado_final, df_stat, on='NombreCompleto', how='left')
        cols_a_rellenar = ['plus_minus', 'posesiones_consumidas', 'posesiones_jugadas', 
                            'rebote_of_disp', 'rebote_def_disp', 'puntos_q4_y_prorroga', 'puntos_clutch']
        for col in cols_a_rellenar:
            if col in resultado_final.columns:
                resultado_final[col] = resultado_final[col].fillna(0).astype(int)
        resultado_final = calcular_posesiones_individuales(resultado_final)
        resultado_final['partido_key'] = partido_key
        resultados.append(resultado_final)

    # --- CONCATENAR TODOS LOS RESULTADOS ---
    if resultados:
        df_resultado_final = pd.concat(resultados, ignore_index=True)
        print("\nDemension de la base")
        print(df_resultado_final.shape)
    else:
        print("No se pudieron procesar partidos correctamente.")