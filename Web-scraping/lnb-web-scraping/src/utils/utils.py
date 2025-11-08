from pathlib import Path
import pandas as pd

# Definir la raíz del proyecto
ROOT = Path(__file__).resolve().parent.parent.parent

# Definir diccionario de paths de datos
DATA_PATHS = {
    "html_partidos_temporada": ROOT / "data" / "external" / "elemento_html_partidos_temporada_24_25.txt"
}



######################### FUNCIONES UTILES #################################
# --- FUNCIÓN PARA CALCULAR EL +/- ---
def calcular_plus_minus_corregido(df_enriquecido, roster_completo):
    print("Calculando +/- para cada jugador...")
    plus_minus = {jugador: 0 for jugador in roster_completo.keys()}
    score_anterior = {'local': 0, 'visitante': 0}
    df_enriquecido[['puntos_local', 'puntos_visita']] = df_enriquecido[['puntos_local', 'puntos_visita']].ffill().fillna(0)
    
    for _, row in df_enriquecido.iterrows():
        puntos_actual_local, puntos_actual_visitante = row['puntos_local'], row['puntos_visita']
        if puntos_actual_local != score_anterior['local'] or puntos_actual_visitante != score_anterior['visitante']:
            diferencial_jugada = (puntos_actual_local - score_anterior['local']) - (puntos_actual_visitante - score_anterior['visitante'])
            for p in row['quinteto_local']:
                if p in plus_minus: plus_minus[p] += diferencial_jugada
            for p in row['quinteto_visita']:
                if p in plus_minus: plus_minus[p] -= diferencial_jugada
            score_anterior = {'local': puntos_actual_local, 'visitante': puntos_actual_visitante}
    print("✅ Cálculo de +/- finalizado.")
    return pd.DataFrame(list(plus_minus.items()), columns=['jugador', 'plus_minus'])

# --- NUEVA FUNCIÓN PARA CALCULAR POSESIONES ---
def calcular_posesiones(df_acciones):
    """
    Calcula las posesiones consumidas por cada jugador basándose en palabras clave.

    Args:
        df_acciones (pd.DataFrame): DataFrame con el play-by-play del partido.
            Debe contener las columnas 'accion' y 'jugador'.

    Returns:
        pd.DataFrame: Un DataFrame con las columnas 'jugador' y 'posesiones'.
    """
    # 1. Lista de acciones que cuentan como una posesión consumida
    acciones_de_posesion = [
        "TIRO DE 3 FALLADO",
        "TIRO DE 2 FALLADO",
        "2 TIROS LIBRES PARA",
        "3 TIROS LIBRES PARA",
        "TRIPLE",
        "CANASTA DE 2 PUNTOS",
        "PÉRDIDA DE BALÓN"
    ]
    
    # 2. Crear un patrón de texto para buscar todas las acciones a la vez
    patron_busqueda = '|'.join(acciones_de_posesion)     # El '|' funciona como un 'OR' en la búsqueda de texto.
    
    # 3. Filtrar el DataFrame para obtener solo las filas donde la acción coincide
    df_posesiones_consumidas = df_acciones[df_acciones['accion'].str.contains(patron_busqueda, na=False)].copy()     # 'str.contains' busca el patrón en la columna 'accion'. 'na=False' evita errores con filas vacías.
    
    # 4. Agrupar por jugador y contar cuántas de estas acciones tuvo cada uno
    conteo_posesiones = df_posesiones_consumidas.groupby('jugador').size()

    # 5. Convertir el resultado a un DataFrame con el formato correcto
    df_resultado = conteo_posesiones.reset_index(name='posesiones')
    
    return df_resultado

def contar_posesiones_jugadas_por_equipo(df_acciones, df_box_scores, player_to_team_map):
    """
    Cuenta las posesiones que ocurrieron para el equipo de un jugador mientras
    este se encontraba en la cancha.

    Args:
        df_acciones (pd.DataFrame): DataFrame con el play-by-play y quintetos.
        df_box_scores (pd.DataFrame): DataFrame con el roster de jugadores y equipos.
        player_to_team_map (dict): Diccionario que mapea 'NombreCompleto' a 'equipo'.

    Returns:
        pd.DataFrame: DataFrame con las columnas 'jugador' y 'posesiones_jugadas'.
    """
    # 1. Inicializar el contador para todos los jugadores del partido.
    roster = df_box_scores['NombreCompleto'].tolist()
    posesiones_jugadas = {jugador: 0 for jugador in roster}
    
    nombre_local = df_box_scores['equipo'].unique()[0]     # equipo local para diferenciar quintetos.

    # 2. Identificar las jugadas que finalizan una posesión.
    acciones_de_posesion = [
        "TIRO DE 3 FALLADO",
        "TIRO DE 2 FALLADO",
        "2 TIROS LIBRES PARA",
        "3 TIROS LIBRES PARA",
        "TRIPLE",
        "CANASTA DE 2 PUNTOS",
        "PÉRDIDA DE BALÓN"
    ]
    patron_busqueda = '|'.join(acciones_de_posesion)
    df_fines_de_posesion = df_acciones[df_acciones['accion'].str.contains(patron_busqueda, na=False)].copy()

    # 3. Iterar sobre las jugadas de fin de posesión.
    for _, jugada in df_fines_de_posesion.iterrows():
        jugador_accion = jugada.get('jugador')
        
        if not jugador_accion or pd.isna(jugador_accion): # Si no hay un jugador asociado a la acción, no podemos determinar el equipo.
            continue

        # 4. Determinar qué equipo tuvo la posesión.
        equipo_posesion = player_to_team_map.get(jugador_accion)
        
        # 5. Seleccionar el quinteto correcto (local o visitante).
        quinteto_del_equipo_en_posesion = []
        if equipo_posesion == nombre_local:
            quinteto_del_equipo_en_posesion = jugada['quinteto_local']
        else:
            quinteto_del_equipo_en_posesion = jugada['quinteto_visita']

        # 6. Sumar 1 al contador de cada jugador de ese quinteto.
        for jugador in quinteto_del_equipo_en_posesion:
            if jugador in posesiones_jugadas:
                posesiones_jugadas[jugador] += 1
    
    # 7. Convertir el resultado a un DataFrame.
    df_resultado = pd.DataFrame(list(posesiones_jugadas.items()), columns=['jugador', 'posesiones_jugadas'])
    print("✅ Cálculo de posesiones jugadas finalizado.")
    return df_resultado

# --- FUNCIÓN PARA CALCULAR REBOTES OF/DEF DISPONIBLES ---
def calcular_rebotes_disponibles(df_acciones, df_box_scores, player_to_team_map):
    """
    Calcula la cantidad de oportunidades de rebote ofensivo y defensivo que 
    tuvo cada jugador mientras estaba en la cancha.

    Una oportunidad de rebote ocurre cuando hay un tiro de campo fallado o el
    último tiro libre de una secuencia es fallado.

    - Para el equipo que atacaba, es una oportunidad de rebote OFENSIVO.
    - Para el equipo que defendía, es una oportunidad de rebote DEFENSIVO.

    Args:
        df_acciones (pd.DataFrame): 
            DF con el play-by-play y quintetos, ordenado cronológicamente.
        df_box_scores (pd.DataFrame): 
            DF con el roster de jugadores y equipos.
        player_to_team_map (dict): 
            Diccionario que mapea 'NombreCompleto' a 'equipo'.

    Returns:
        pd.DataFrame: DataFrame con las columnas 'jugador', 'reb_of_disp', y 'reb_def_disp'.
    """
    print(" rebounding... Calculando oportunidades de rebote OFENSIVAS y DEFENSIVAS...")

    # 1. Inicializar contadores para todos los jugadores del partido.
    roster = df_box_scores['NombreCompleto'].tolist()
    reb_of_disponibles = {jugador: 0 for jugador in roster}
    reb_def_disponibles = {jugador: 0 for jugador in roster}
    nombre_local = df_box_scores['equipo'].unique()[0]
    
    # 2. Iterar sobre el índice del DataFrame para poder mirar filas futuras.
    num_acciones = len(df_acciones)
    for i in range(num_acciones):
        jugada = df_acciones.iloc[i]
        accion = jugada['accion']
        es_oportunidad_de_rebote = False
        
        # --- Lógica para detectar una oportunidad de rebote ---
        if "TIRO DE 3 FALLADO" in accion or "TIRO DE 2 FALLADO" in accion:
            es_oportunidad_de_rebote = True
        elif "1 TIRO LIBRE PARA" in accion:
            if (i + 1 < num_acciones) and "TIRO LIBRE FALLADO" in df_acciones.iloc[i + 1]['accion']:
                es_oportunidad_de_rebote = True
        elif "2 TIROS LIBRES PARA" in accion:
            if (i + 2 < num_acciones) and "TIRO LIBRE FALLADO" in df_acciones.iloc[i + 2]['accion']:
                es_oportunidad_de_rebote = True
        elif "3 TIROS LIBRES PARA" in accion:
            if (i + 3 < num_acciones) and "TIRO LIBRE FALLADO" in df_acciones.iloc[i + 3]['accion']:
                es_oportunidad_de_rebote = True

        # 3. Si se encontró una oportunidad, se asigna a ambos equipos.
        if es_oportunidad_de_rebote:
            jugador_accion = jugada.get('jugador')
            if not jugador_accion or pd.isna(jugador_accion):
                continue

            equipo_ofensivo = player_to_team_map.get(jugador_accion)
            if not equipo_ofensivo:
                continue

            # Identificar ambos quintetos, el ofensivo y el defensivo.
            if equipo_ofensivo == nombre_local:
                quinteto_ofensivo = jugada['quinteto_local']
                quinteto_defensivo = jugada['quinteto_visita']
            else:
                quinteto_ofensivo = jugada['quinteto_visita']
                quinteto_defensivo = jugada['quinteto_local']

            # Sumar la oportunidad de REBOTE OFENSIVO a los jugadores del equipo atacante.
            for jugador in quinteto_ofensivo:
                if jugador in reb_of_disponibles:
                    reb_of_disponibles[jugador] += 1
            
            # Sumar la oportunidad de REBOTE DEFENSIVO a los jugadores del equipo defensor.
            for jugador in quinteto_defensivo:
                if jugador in reb_def_disponibles:
                    reb_def_disponibles[jugador] += 1

    # 4. Convertir los diccionarios en DataFrames y unirlos.
    df_ofensivos = pd.DataFrame(list(reb_of_disponibles.items()), columns=['jugador', 'rebote_of_disp'])
    df_defensivos = pd.DataFrame(list(reb_def_disponibles.items()), columns=['jugador', 'rebote_def_disp'])
    
    # Unir los dos dataframes en uno solo usando 'jugador' como clave.
    df_resultado = pd.merge(df_ofensivos, df_defensivos, on='jugador')
    
    return df_resultado

# --- FUNCIÓN PARA CALCULAR POSESIONES INDIVIDUALES ESTIMADAS ---
def calcular_posesiones_individuales(df_box_score):
    """
    Estima las posesiones finalizadas por cada jugador individualmente usando
    la fórmula de Dean Oliver.

    Args:
        df_box_score (pd.DataFrame): 
            DataFrame que contiene las estadísticas
            detalladas por jugador. Debe incluir columnas de aciertos y fallos para 
            cada tipo de tiro,'ReboteOfensivo' y 'Perdidas'.

    Returns:
        pd.DataFrame: 
            El DataFrame original con una nueva columna llamada 'posesiones_estimadas'.
    """
    # Se crea una copia para evitar advertencias de SettingWithCopyWarning
    df = df_box_score.copy()

    # 1. Calcular Tiros de Campo Intentados (TCI)
    tci_individual = (df['TirosDosAciertos'] + df['TirosDosFallos'] +
                      df['TirosTresAciertos'] + df['TirosTresFallos'])

    # 2. Calcular Tiros Libres Intentados (TLI)
    tli_individual = df['TirosLibresAciertos'] + df['TirosLibresFallos']
    
    # 3. Aplicar la fórmula de Oliver y crear la nueva columna
    df['posesiones_estimadas'] = (
        tci_individual +
        0.44 * tli_individual -
        df['ReboteOfensivo'] +
        df['Perdidas']
    ).clip(lower=0).round(2)
    
    return df

# --- FUNCIÓN PARA CALCULAR PUNTOS EN EL ÚLTIMO CUARTO ---
def calcular_puntos_ultimo_cuarto(df_acciones, df_box_scores):
    """
    Calcula los puntos anotados por cada jugador en el último cuarto (Q4) y
    cualquier prórroga posterior.

    Args:
        df_acciones (pd.DataFrame): 
            DataFrame con el play-by-play del partido. Debe contener las columnas 'accion', 'jugador' y 'cuarto'.
        df_box_scores (pd.DataFrame): 
            DataFrame con el roster de jugadores para inicializar los contadores.

    Returns:
        pd.DataFrame: Un DataFrame con las columnas 'jugador' y 'puntos_q4_y_prorroga'.
    """

    # 1. Inicializar el contador de puntos.
    roster = df_box_scores['NombreCompleto'].tolist()
    puntos_finales = {jugador: 0 for jugador in roster}

    # 2. Filtrar las acciones que NO ocurrieron en los primeros 3 cuartos.
    cuartos_a_excluir = ['1', '2', '3']
    df_momentos_finales = df_acciones[~df_acciones['cuarto'].isin(cuartos_a_excluir)].copy()

    # 3. Definir los puntos por acción.
    puntos_por_accion = {
        "TRIPLE": 3,
        "CANASTA DE 2 PUNTOS": 2,
        "TIRO LIBRE ANOTADO": 1
    }

    # 4. Iterar sobre las jugadas de los momentos finales y sumar los puntos.
    for _, jugada in df_momentos_finales.iterrows():
        accion = jugada.get('accion')
        jugador = jugada.get('jugador')
        
        if accion in puntos_por_accion and pd.notna(jugador):
            if jugador in puntos_finales:
                puntos_finales[jugador] += puntos_por_accion[accion]
    
    # 5. Convertir a DataFrame y renombrar la columna para mayor claridad.
    df_resultado = pd.DataFrame(list(puntos_finales.items()), columns=['jugador', 'puntos_q4_y_prorroga'])
    
    return df_resultado

# --- FUNCIÓN PARA CALCULAR PUNTOS "CLUTCH" ---
def calcular_puntos_clutch(df_acciones, df_box_scores):
    """
    Calcula los puntos anotados por cada jugador en situaciones "clutch".

    Una situación "clutch" se define como:
    - Ocurre en los últimos 5 minutos del 4º cuarto o en cualquier prórroga.
    - La diferencia de puntos entre ambos equipos es de 5 o menos.

    Args:
        df_acciones (pd.DataFrame): 
            DataFrame con el play-by-play. Debe contener 'cuarto', 'tiempo' (formato "HH:MM:SS"), 
            'puntos_local', 'puntos_visita', 'accion' y 'jugador'.
        df_box_scores (pd.DataFrame):
            DataFrame con el roster para inicializar contadores.

    Returns:
        pd.DataFrame: Un DataFrame con 'jugador' y 'puntos_clutch'.
    """
    print(" 🎯 Calculando puntos en situaciones 'clutch'...")

    # 1. Inicializar contadores y preparar datos.
    roster = df_box_scores['NombreCompleto'].tolist()
    puntos_clutch = {jugador: 0 for jugador in roster}
    
    df_acciones_copy = df_acciones.copy()
    df_acciones_copy[['puntos_local', 'puntos_visita']] = df_acciones_copy[['puntos_local', 'puntos_visita']].ffill().fillna(0)

    # 2. Definir los puntos por cada tipo de anotación.
    puntos_por_accion = {
        "TRIPLE": 3,
        "CANASTA DE 2 PUNTOS": 2,
        "TIRO LIBRE ANOTADO": 1
    }

    # 3. Iterar sobre cada jugada del partido para evaluar las condiciones.
    for _, jugada in df_acciones_copy.iterrows():
        # --- CONDICIÓN 1: PERÍODO DEL JUEGO (Q4 o Prórroga) ---
        if jugada['cuarto'] not in ['1', '2', '3']:
            
            # --- CONDICIÓN 2: TIEMPO RESTANTE (Últimos 5 minutos) ---
            try:
                parts = jugada['tiempo'].split(':')
                minutos = int(parts[1])
                
                if minutos < 5:
                    
                    # --- CONDICIÓN 3: MARCADOR APRETADO (Diferencia <= 5) ---
                    diferencia_puntos = abs(jugada['puntos_local'] - jugada['puntos_visita'])
                    if diferencia_puntos <= 5:
                        
                        accion = jugada.get('accion')
                        jugador = jugada.get('jugador')
                        
                        if accion in puntos_por_accion and pd.notna(jugador):
                            if jugador in puntos_clutch:
                                puntos_clutch[jugador] += puntos_por_accion[accion]
            except (ValueError, AttributeError, IndexError):
                # Ignora filas donde el formato de tiempo no es el esperado.
                continue
    
    # 4. Convertir el resultado a un DataFrame.
    df_resultado = pd.DataFrame(list(puntos_clutch.items()), columns=['jugador', 'puntos_clutch'])
    
    return df_resultado