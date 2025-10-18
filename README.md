# Scrappy

Herramienta de web scraping para obtener estadísticas y resultados de Once Caldas desde ESPN.com.co, diseñada para análisis de apuestas deportivas.

## Características

- Extracción de estadísticas de jugadores (goleadores, asistencias)
- Resultados de partidos por temporada
- Selector de temporada (2015 - presente)
- Insights automáticos para análisis de apuestas
- Exportación de datos a CSV

## Requisitos

- Python 3.11+
- pip

## Instalación

1. Clonar el repositorio:
```bash
git clone https://github.com/JLCervantes-19/ScrappyOncecaldas.git
cd ScrappyOncecaldas
```

2. Crear entorno virtual:
```bash
python3 -m venv venv
```

3. Activar entorno virtual:
```bash
source venv/bin/activate
```

4. Instalar dependencias:
```bash
pip install -r requirements.txt
```

## Uso Local

1. Ejecutar la aplicación:
```bash
python app.py
```

2. Abrir en el navegador:
```
http://localhost:5000
```

3. Seleccionar año y cargar estadísticas

## Despliegue en Azure VM

Ver [DEPLOYMENT.md](DEPLOYMENT.md) para instrucciones detalladas de despliegue en Azure con GitHub Actions, nginx y SSL.

## Tecnologías

- **Backend**: Flask, BeautifulSoup4, Requests
- **Frontend**: HTML, CSS, JavaScript (Vanilla)
- **Servidor**: Gunicorn, Nginx (producción)

## API Endpoints

- `GET /` - Interfaz web
- `GET /api/years` - Años disponibles
- `GET /api/scrape?year=YYYY` - Obtener estadísticas
- `GET /api/export/csv?year=YYYY` - Exportar CSV

## Estructura del Proyecto

```
scrappy/
├── app.py                    # Aplicación Flask principal
├── main.py                   # Entry point para Gunicorn
├── requirements.txt          # Dependencias Python
├── static/
│   └── index.html           # Interfaz web
├── deployment/              # Configuraciones de despliegue
│   ├── nginx/
│   │   └── scrappy.conf    # Configuración Nginx
│   └── scripts/
│       ├── setup_server.sh  # Script de configuración inicial
│       └── deploy.sh        # Script de despliegue
└── .github/
    └── workflows/
        └── deploy.yml       # GitHub Actions workflow
```

## Licencia

MIT
