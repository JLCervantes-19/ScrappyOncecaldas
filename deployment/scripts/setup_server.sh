#!/bin/bash
# Script de configuración inicial del servidor Azure VM
# Este script debe ejecutarse una sola vez en el servidor

set -e

echo "=== Iniciando configuración del servidor ==="

# Variables (ajustar según sea necesario)
DOMAIN_NAME="${DOMAIN_NAME:-example.com}"
EMAIL="${EMAIL:-admin@example.com}"
PROJECT_DIR="/home/azureuser/scrappy"
APP_USER="${APP_USER:-azureuser}"

echo "Dominio: $DOMAIN_NAME"
echo "Email: $EMAIL"
echo "Usuario: $APP_USER"

# Actualizar sistema
echo "Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
echo "Instalando dependencias..."
sudo apt install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    ufw

# Configurar firewall
echo "Configurando firewall..."
sudo ufw --force enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw status

# Crear directorio del proyecto si no existe
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Clonando repositorio..."
    git clone https://github.com/USUARIO/REPO.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
else
    echo "El directorio del proyecto ya existe"
    cd "$PROJECT_DIR"
fi

# Crear entorno virtual
echo "Creando entorno virtual Python..."
python3.11 -m venv venv
source venv/bin/activate

# Instalar dependencias Python
echo "Instalando dependencias Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Crear archivo de servicio systemd
echo "Creando servicio systemd..."
sudo tee /etc/systemd/system/scrappy.service > /dev/null << EOF
[Unit]
Description=Scrappy - ESPN Football Scraper
After=network.target

[Service]
Type=notify
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
Environment="FLASK_ENV=production"
Environment="PORT=5000"
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 120 --access-logfile - --error-logfile - main:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Configurar nginx
echo "Configurando nginx..."
sudo cp deployment/nginx/scrappy.conf /etc/nginx/sites-available/scrappy.conf

# Actualizar dominio en configuración de nginx
sudo sed -i "s/your-domain.com/$DOMAIN_NAME/g" /etc/nginx/sites-available/scrappy.conf

# Habilitar sitio
sudo ln -sf /etc/nginx/sites-available/scrappy.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Verificar configuración de nginx
sudo nginx -t

# Reiniciar nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

# Habilitar e iniciar servicio
sudo systemctl daemon-reload
sudo systemctl enable scrappy
sudo systemctl start scrappy

# Verificar estado del servicio
sudo systemctl status scrappy --no-pager

# Configurar SSL con Let's Encrypt
echo "Configurando SSL con Let's Encrypt..."
echo "IMPORTANTE: Asegúrate de que el dominio $DOMAIN_NAME apunte a esta IP antes de continuar"
read -p "¿Continuar con la configuración SSL? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos -m "$EMAIL" --redirect

    # Configurar renovación automática
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer

    echo "SSL configurado exitosamente!"
else
    echo "Configuración SSL omitida. Puedes ejecutarla manualmente con:"
    echo "sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos -m $EMAIL --redirect"
fi

echo ""
echo "=== Configuración completada ==="
echo "La aplicación debería estar corriendo en:"
echo "  - HTTP: http://$DOMAIN_NAME"
echo "  - HTTPS: https://$DOMAIN_NAME (si configuraste SSL)"
echo ""
echo "Comandos útiles:"
echo "  - Ver logs: sudo journalctl -u scrappy -f"
echo "  - Reiniciar: sudo systemctl restart scrappy"
echo "  - Estado: sudo systemctl status scrappy"
echo "  - Renovar SSL: sudo certbot renew --dry-run"
