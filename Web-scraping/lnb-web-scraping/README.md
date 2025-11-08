
# Liga Nacional de Basquet: Web Scraping de la carta de tiro


## Objetivo

Conseguir de forma masiva los datos que publica la liga nacional de basquet para sus partidos.

## Estructura del proyecto

```
├───data                           # Carpeta para datos de ejemplo o testing.
│   ├───external                   # Bases externas / catálogos.
│   ├───interim                    # Datos intermedios.
│   ├───raw                        # Datos sin procesar.
│   └───test                       # Bases creadas para testeos.
├───docs                           # Documentación del repositorio (README, guías, etc.).
├───examples                       # Ejemplos de uso de las funciones.
│   ├───notebooks                  # Notebooks de ejemplo.
│   └───scripts                    # Scripts de ejemplo.
├───logs                           # Logs de ejecución.
├───src                            # Código fuente principal.
│   ├───data_processing            # Funciones para procesamiento de datos.
│   │   ├───blob_storage           # Funciones para interactuar con Azure Blob Storage.
│   │   ├───s3_buckets             # Funciones para interactuar con AWS S3.
│   │   └───data_transformation    # Funciones para transformaciones de datos.
│   ├───eda                        # Funciones para análisis exploratorio de datos (EDA).
│   │   ├───binary_response        # Funciones para EDA con respuesta binaria.
│   │   ├───categorical_response   # Funciones para EDA con respuesta categórica.
│   │   └───utils                  # Utilidades generales para EDA.
│   ├───models                     # Funciones relacionadas con modelado.
│   │   ├───preprocessing          # Preprocesamiento de datos para modelos.
│   │   ├───evaluation             # Evaluación de modelos.
│   │   └───utils                  # Utilidades para modelado.
│   └───utils                      # Utilidades generales para el repositorio.
│       ├───logging                # Funciones para manejo de logs.
│       ├───config                 # Configuraciones y constantes.
│       └───helpers                # Funciones auxiliares.
└───tests                          # Pruebas unitarias y de integración.
    ├───data_processing            # Pruebas para funciones de procesamiento de datos.
    ├───eda                        # Pruebas para funciones de EDA.
    ├───models                     # Pruebas para funciones de modelado.
    └───utils                      # Pruebas para utilidades generales.
```
## Instalación del ambiente con Poetry

### Requisitos
- Python 3.11 o superior
- Poetry instalado (si no lo tienes: `pip install poetry` o sigue las instrucciones oficiales)

### Configuración del ambiente

1. Clonar el repositorio y ubicarse en la raíz del proyecto

*NOTA:* Por default, Poetry instalará los ambientes virtuales en la carpeta ` ~/.cache/pypoetry/virtualenvs/`. Si deseamos instalar el ambiente virtual en la raiz del proyecto ejecutar:
```shell
poetry config virtualenvs.in-project true
```

2. Instalar las dependencias:
```shell
poetry install
```
Esto creará un ambiente virtual e instalará todas las dependencias que figuran en el archivo [pyproject.toml](pyproject.toml) . 

### Uso del ambiente

Para activar el ambiente virtual:

```shell
poetry env activate
```
Esto devolvera la ubicación del archivo .bat que activa el ambiente, se bede copiar y ejecutar en la terminal

*NOTA:* En caso de que tengas un ambiente **Conda** activado anteriormente, deberas activar el ambiente **Poetry** de manera explicita:
```shell
.venv\Scripts\activate
```
Siempre y cuando tu ambiente virtual este instalado en la raiz del proyecto.


Ademá, puedes ver cuales son tus ambientes creados y cual esta activo ejecutando 
```shell
poetry env list
```

Tambien puedes ejecutar comandos directamente sin activar el shell:
```shell
poetry run python tu_script.py
```

### Actualización de dependencias

Para agregar nuevas dependencias:

```shell
poetry add nombre_paquete
```

Actualizar todas las dependencias [pyproject.toml](pyproject.toml) a sus últimas versiones compatibles

```shell
poetry update
```
### Comandos útiles

- Ver dependencias instaladas:

```shell
poetry show
```

- Exportar dependencias del proyecto a requirements.txt (si es necesario):
```shell
poetry export -f requirements.txt --output requirements.txt
```

En caso de querer eliminar el ambiente virtual:
```shell
poetry env remove python
```

### Desarrollo

Para instalar dependencias de PROD + DEV (como Jupyter):

```shell
poetry install --with dev
```
Para agregar dependencias de desarrollo:
```shell
poetry add --group dev nombre_paquete
```

### Consideraciones

- Poetry maneja automáticamente los ambientes virtuales

- El archivo *poetry.lock* y *pyproject.toml* debe ser commitado para asegurar versiones consistentes

- No es necesario editar manualmente el pyproject.toml para agregar dependencias básicas