# Guía de Despliegue - Scrappy en Azure VM

Esta guía describe cómo configurar y desplegar la aplicación Scrappy en una máquina virtual de Azure con SSL y dominio personalizado.

## Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Configuración Inicial de Azure VM](#configuración-inicial-de-azure-vm)
3. [Configuración del Servidor](#configuración-del-servidor)
4. [Configuración de GitHub Actions](#configuración-de-github-actions)
5. [Configuración de Dominio y DNS](#configuración-de-dominio-y-dns)
6. [Configuración de SSL](#configuración-de-ssl)
7. [Despliegue](#despliegue)
8. [Mantenimiento](#mantenimiento)
9. [Solución de Problemas](#solución-de-problemas)

---

## Requisitos Previos

- Una máquina virtual de Azure (Ubuntu 22.04 LTS o superior)
- Un dominio registrado
- Cuenta de GitHub con permisos para configurar Actions
- Acceso SSH a la VM

### Especificaciones Mínimas de la VM

- **Sistema Operativo**: Ubuntu 22.04 LTS
- **vCPUs**: 1
- **RAM**: 1 GB
- **Disco**: 30 GB
- **Puertos abiertos**: 22 (SSH), 80 (HTTP), 443 (HTTPS)

---

## Configuración Inicial de Azure VM

### 1. Crear la Máquina Virtual

1. En Azure Portal, crea una nueva VM con Ubuntu 22.04 LTS
2. Configura la autenticación SSH con clave pública
3. Abre los puertos necesarios en el Network Security Group:
   - Puerto 22 (SSH)
   - Puerto 80 (HTTP)
   - Puerto 443 (HTTPS)

### 2. Conectarse a la VM

```bash
ssh azureuser@<IP_DE_TU_VM>
```

### 3. Generar Par de Claves SSH para GitHub Actions

En tu VM, genera una clave SSH específica para el despliegue:

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy
```

Agrega la clave pública a las claves autorizadas:

```bash
cat ~/.ssh/github_deploy.pub >> ~/.ssh/authorized_keys
```

**Guarda la clave privada** (`~/.ssh/github_deploy`), la necesitarás para GitHub Secrets.

```bash
cat ~/.ssh/github_deploy
```

---

## Configuración del Servidor

### 1. Clonar el Repositorio

```bash
cd ~
git clone https://github.com/TU_USUARIO/scrappy.git
cd scrappy
```

### 2. Ejecutar Script de Configuración

```bash
# Configurar variables de entorno
export DOMAIN_NAME="tu-dominio.com"
export EMAIL="tu-email@example.com"

# Ejecutar script de configuración
sudo bash deployment/scripts/setup_server.sh
```

Este script realizará automáticamente:

- Instalación de Python 3.11, nginx, certbot
- Configuración del firewall (ufw)
- Creación del entorno virtual Python
- Instalación de dependencias
- Configuración del servicio systemd
- Configuración de nginx como reverse proxy
- Configuración de SSL con Let's Encrypt (si el dominio está configurado)

### 3. Verificar Instalación

```bash
# Verificar que el servicio está corriendo
sudo systemctl status scrappy

# Verificar nginx
sudo systemctl status nginx

# Verificar que la aplicación responde
curl http://localhost:5000/
```

---

## Configuración de GitHub Actions

### 1. Configurar Secrets en GitHub

Ve a tu repositorio en GitHub: `Settings > Secrets and variables > Actions`

Agrega los siguientes secrets:

| Secret Name | Descripción | Ejemplo |
|------------|-------------|---------|
| `AZURE_SSH_KEY` | Clave privada SSH generada anteriormente | Contenido de `~/.ssh/github_deploy` |
| `AZURE_VM_HOST` | IP pública o hostname de tu VM | `20.123.45.67` |
| `AZURE_VM_USER` | Usuario SSH de la VM | `azureuser` |
| `DOMAIN_NAME` | Tu dominio | `scrappy.tudominio.com` |

### 2. Verificar Workflow

El workflow de GitHub Actions está en [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

Se ejecutará automáticamente en cada push a la rama `main`.

### 3. Probar Despliegue Manual

Puedes probar el workflow manualmente:

1. Ve a `Actions` en tu repositorio
2. Selecciona `Deploy to Azure VM`
3. Haz clic en `Run workflow`

---

## Configuración de Dominio y DNS

### 1. Configurar Registros DNS

En tu proveedor de DNS (GoDaddy, Cloudflare, etc.), agrega los siguientes registros:

```
Tipo    Nombre              Valor                   TTL
A       scrappy            <IP_DE_TU_VM>           3600
A       www.scrappy        <IP_DE_TU_VM>           3600
```

O si usas un subdominio:

```
Tipo    Nombre              Valor                   TTL
A       @                  <IP_DE_TU_VM>           3600
A       www                <IP_DE_TU_VM>           3600
```

### 2. Verificar Propagación DNS

Espera a que los registros DNS se propaguen (puede tomar hasta 48 horas, pero generalmente es más rápido):

```bash
# En tu computadora local
nslookup scrappy.tudominio.com
dig scrappy.tudominio.com
```

---

## Configuración de SSL

### Opción 1: Durante la Configuración Inicial

El script `setup_server.sh` te preguntará si deseas configurar SSL. Asegúrate de que el DNS esté configurado antes de continuar.

### Opción 2: Configuración Manual Posterior

Si omitiste la configuración SSL durante el setup inicial:

```bash
# Conectarse a la VM
ssh azureuser@<IP_DE_TU_VM>

# Ejecutar certbot
sudo certbot --nginx -d tu-dominio.com -d www.tu-dominio.com \
  --non-interactive --agree-tos -m tu-email@example.com --redirect
```

### Verificar SSL

```bash
# Verificar certificado
sudo certbot certificates

# Probar renovación automática
sudo certbot renew --dry-run
```

La renovación automática está configurada para ejecutarse automáticamente cada 12 horas.

---

## Despliegue

### Despliegue Automático (Recomendado)

Cada vez que hagas push a `main`, GitHub Actions desplegará automáticamente:

```bash
git add .
git commit -m "Update application"
git push origin main
```

### Despliegue Manual desde la VM

```bash
# Conectarse a la VM
ssh azureuser@<IP_DE_TU_VM>

# Ejecutar script de despliegue
cd ~/scrappy
bash deployment/scripts/deploy.sh
```

---

## Mantenimiento

### Ver Logs de la Aplicación

```bash
# Logs en tiempo real
sudo journalctl -u scrappy -f

# Últimas 100 líneas
sudo journalctl -u scrappy -n 100

# Logs de hoy
sudo journalctl -u scrappy --since today
```

### Ver Logs de Nginx

```bash
# Error logs
sudo tail -f /var/log/nginx/scrappy_error.log

# Access logs
sudo tail -f /var/log/nginx/scrappy_access.log
```

### Reiniciar Servicios

```bash
# Reiniciar aplicación
sudo systemctl restart scrappy

# Reiniciar nginx
sudo systemctl restart nginx

# Ver estado
sudo systemctl status scrappy
sudo systemctl status nginx
```

### Actualizar Dependencias

```bash
cd ~/scrappy
source venv/bin/activate
pip install --upgrade -r requirements.txt
sudo systemctl restart scrappy
```

### Renovar Certificado SSL

Los certificados se renuevan automáticamente, pero puedes forzar una renovación:

```bash
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

---

## Solución de Problemas

### La aplicación no inicia

```bash
# Ver logs detallados
sudo journalctl -u scrappy -xe

# Verificar archivo de servicio
sudo systemctl cat scrappy

# Reiniciar servicio
sudo systemctl restart scrappy
```

### Error 502 Bad Gateway

```bash
# Verificar que la aplicación esté corriendo
sudo systemctl status scrappy
curl http://localhost:5000/

# Verificar configuración de nginx
sudo nginx -t

# Revisar logs
sudo tail -f /var/log/nginx/scrappy_error.log
```

### Error de SSL

```bash
# Verificar certificados
sudo certbot certificates

# Renovar certificado
sudo certbot renew

# Verificar configuración nginx
sudo nginx -t
sudo systemctl restart nginx
```

### GitHub Actions falla

Verifica:

1. Los secrets están configurados correctamente
2. La clave SSH tiene permisos correctos en la VM
3. El usuario puede ejecutar `sudo systemctl restart scrappy` sin contraseña

Para permitir sudo sin contraseña para el servicio:

```bash
sudo visudo
# Agregar al final:
azureuser ALL=(ALL) NOPASSWD: /bin/systemctl restart scrappy
azureuser ALL=(ALL) NOPASSWD: /bin/systemctl status scrappy
```

### Aplicación lenta o no responde

```bash
# Verificar recursos del sistema
htop
df -h

# Verificar memoria de la aplicación
sudo systemctl status scrappy

# Aumentar workers de Gunicorn (editar servicio)
sudo systemctl edit scrappy
# Agregar: Environment="WORKERS=4"
sudo systemctl daemon-reload
sudo systemctl restart scrappy
```

---

## Comandos Útiles de Referencia

```bash
# Estado general del sistema
sudo systemctl status scrappy nginx

# Logs combinados
sudo journalctl -u scrappy -u nginx -f

# Limpiar caché de nginx
sudo rm -rf /var/cache/nginx/scrappy/*
sudo systemctl reload nginx

# Verificar puertos abiertos
sudo netstat -tulpn | grep -E ':(80|443|5000)'

# Verificar firewall
sudo ufw status

# Reiniciar todo
sudo systemctl restart scrappy nginx
```

---

## Arquitectura del Despliegue

```
Internet
    ↓
Azure Load Balancer (Puerto 443/80)
    ↓
Nginx (Reverse Proxy + SSL Termination)
    ↓
Gunicorn (Puerto 5000)
    ↓
Flask Application
    ↓
ESPN.com.co (Web Scraping)
```

---

## Seguridad

- SSL/TLS habilitado (Let's Encrypt)
- Firewall configurado (UFW)
- Rate limiting en nginx
- Headers de seguridad configurados
- Servicio corriendo como usuario no-root
- SSH con clave pública solamente

---

## Soporte

Para reportar problemas o solicitar ayuda:

1. Revisa esta documentación
2. Revisa los logs
3. Crea un issue en GitHub
4. Contacta al administrador del sistema

---

**Última actualización**: 2025-10-17
