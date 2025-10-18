#!/bin/bash
# Script de despliegue manual para Azure VM
# Ejecutar desde la VM: bash ~/scrappy/deployment/scripts/deploy.sh

set -e

PROJECT_DIR="/home/azureuser/scrappy"

echo "=== Iniciando despliegue de Scrappy ==="

# Navegar al directorio del proyecto
cd "$PROJECT_DIR" || { echo "Error: Directorio del proyecto no encontrado"; exit 1; }

# Guardar cambios locales si existen
if [[ -n $(git status -s) ]]; then
    echo "Guardando cambios locales..."
    git stash
fi

# Obtener última versión
echo "Obteniendo últimos cambios del repositorio..."
git fetch origin
git reset --hard origin/main

# Restaurar cambios locales si existen
if git stash list | grep -q stash@{0}; then
    echo "Restaurando cambios locales..."
    git stash pop || true
fi

# Activar entorno virtual
echo "Activando entorno virtual..."
source venv/bin/activate

# Actualizar dependencias
echo "Actualizando dependencias Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Reiniciar servicio
echo "Reiniciando servicio..."
sudo systemctl restart scrappy

# Esperar a que el servicio esté listo
sleep 3

# Verificar estado del servicio
if sudo systemctl is-active --quiet scrappy; then
    echo "✓ Servicio scrappy está corriendo"
else
    echo "✗ Error: El servicio scrappy no está corriendo"
    sudo systemctl status scrappy --no-pager
    exit 1
fi

# Verificar que la aplicación responde
echo "Verificando que la aplicación responde..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/ || echo "000")

if [ "$response" = "200" ]; then
    echo "✓ Aplicación respondiendo correctamente"
else
    echo "✗ Error: La aplicación no responde (HTTP $response)"
    echo "Mostrando últimos logs:"
    sudo journalctl -u scrappy -n 50 --no-pager
    exit 1
fi

echo ""
echo "=== Despliegue completado exitosamente ==="
echo ""
echo "Comandos útiles:"
echo "  - Ver logs en tiempo real: sudo journalctl -u scrappy -f"
echo "  - Ver estado del servicio: sudo systemctl status scrappy"
echo "  - Reiniciar servicio: sudo systemctl restart scrappy"
echo "  - Ver logs de nginx: sudo tail -f /var/log/nginx/scrappy_error.log"
