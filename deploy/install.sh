#!/usr/bin/env bash
# =================================================================
# install.sh — Instalación de Rasa Deportes en Ubuntu 22.04 / 24.04
# Uso: sudo bash deploy/install.sh
# Ejecutar desde la raíz del proyecto (donde está docker-compose.yml)
# =================================================================
set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
info()    { echo -e "\n${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
ask()     { local prompt="$1"; local default="${2:-}"; local result
            if [[ -n "$default" ]]; then
                read -rp "$(echo -e "${YELLOW}[?]${NC} ${prompt} [${default}]: ")" result
                echo "${result:-$default}"
            else
                read -rp "$(echo -e "${YELLOW}[?]${NC} ${prompt}: ")" result
                echo "$result"
            fi }

# ── Validaciones previas ──────────────────────────────────────────
[[ $EUID -ne 0 ]] && die "Ejecuta como root: sudo bash deploy/install.sh"
[[ ! -f docker-compose.yml ]] && die "Ejecuta desde la raíz del proyecto (donde está docker-compose.yml)"

UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "0")
[[ "${UBUNTU_VER%%.*}" -lt 20 ]] && warn "Probado en Ubuntu 20.04+. Tu versión: $UBUNTU_VER"

# ── Configuración ─────────────────────────────────────────────────
echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Rasa Deportes — Instalación en servidor VPS      ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"

DOMAIN=$(ask "Dominio principal del sitio (sin www)")
[[ -z "$DOMAIN" ]] && die "El dominio no puede estar vacío"

EMAIL=$(ask "Email para Let's Encrypt (notificaciones de renovación)")
[[ -z "$EMAIL" ]] && die "El email no puede estar vacío"

APP_DIR=$(ask "Directorio de instalación" "/opt/rasaapp")
APP_USER=$(ask "Usuario del sistema para la app" "rasaapp")

echo ""
info "Configuración:"
echo "  Dominio   : $DOMAIN"
echo "  Email SSL : $EMAIL"
echo "  Directorio: $APP_DIR"
echo "  Usuario   : $APP_USER"
read -rp $'\n\033[1;33m[?]\033[0m ¿Continuar con la instalación? [s/N]: ' CONFIRM
[[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Instalación cancelada."; exit 0; }

# ── 1. Actualizar el sistema ──────────────────────────────────────
info "Actualizando sistema..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
apt-get install -y -qq curl git ca-certificates gnupg lsb-release ufw
ok "Sistema actualizado"

# ── 2. Instalar Docker ────────────────────────────────────────────
info "Instalando Docker..."
if ! command -v docker &>/dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    ok "Docker instalado: $(docker --version)"
else
    ok "Docker ya instalado: $(docker --version)"
fi

# ── 3. Instalar Nginx ─────────────────────────────────────────────
info "Instalando Nginx..."
if ! command -v nginx &>/dev/null; then
    apt-get install -y -qq nginx
    systemctl enable nginx
    ok "Nginx instalado: $(nginx -v 2>&1)"
else
    ok "Nginx ya instalado: $(nginx -v 2>&1)"
fi

# ── 4. Instalar Certbot ───────────────────────────────────────────
info "Instalando Certbot..."
if ! command -v certbot &>/dev/null; then
    apt-get install -y -qq certbot python3-certbot-nginx
    ok "Certbot instalado: $(certbot --version)"
else
    ok "Certbot ya instalado: $(certbot --version)"
fi

# ── 5. Crear usuario del sistema ──────────────────────────────────
info "Configurando usuario $APP_USER..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d "$APP_DIR" "$APP_USER"
    usermod -aG docker "$APP_USER"
    ok "Usuario $APP_USER creado"
else
    usermod -aG docker "$APP_USER"
    ok "Usuario $APP_USER ya existe"
fi

# ── 6. Copiar proyecto al directorio de instalación ───────────────
info "Copiando proyecto a $APP_DIR..."
mkdir -p "$APP_DIR"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$SRC_DIR" != "$APP_DIR" ]]; then
    rsync -a --exclude='.git' --exclude='target/' --exclude='uploads/' \
          --exclude='*.log' --exclude='.env' \
          "$SRC_DIR/" "$APP_DIR/"
fi

chown -R "$APP_USER:$APP_USER" "$APP_DIR"
mkdir -p "$APP_DIR/uploads" "$APP_DIR/logs" "$APP_DIR/backups"
chown "$APP_USER:$APP_USER" "$APP_DIR/uploads" "$APP_DIR/logs" "$APP_DIR/backups"
ok "Proyecto copiado a $APP_DIR"

# ── 7. Crear .env si no existe ────────────────────────────────────
if [[ ! -f "$APP_DIR/.env" ]]; then
    if [[ -f "$APP_DIR/.env.example" ]]; then
        cp "$APP_DIR/.env.example" "$APP_DIR/.env"
        chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
        chmod 600 "$APP_DIR/.env"
        warn "Archivo .env creado desde .env.example en $APP_DIR/.env"
        warn "DEBES editar ese archivo con tus credenciales reales antes de continuar"
        echo ""
        echo "  nano $APP_DIR/.env"
        echo ""
        read -rp $'\033[1;33m[?]\033[0m Presiona ENTER cuando hayas editado el .env...'
    else
        die "No se encontró .env.example. Crea $APP_DIR/.env manualmente."
    fi
else
    ok ".env ya existe"
fi

# Cargar variables del .env
set -o allexport
source "$APP_DIR/.env"
set +o allexport

# ── 8. Configurar Firewall (UFW) ──────────────────────────────────
info "Configurando firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
ok "Firewall configurado (SSH + HTTP + HTTPS)"

# ── 9. Configurar Nginx — HTTP (para certbot) ─────────────────────
info "Configurando Nginx para validación SSL..."
NGINX_CONF="/etc/nginx/sites-available/rasaapp"

cat > "$NGINX_CONF" <<NGINX_HTTP
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
NGINX_HTTP

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/rasaapp
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
ok "Nginx configurado para HTTP"

# ── 10. Obtener certificado SSL ───────────────────────────────────
info "Obteniendo certificado SSL para $DOMAIN..."
certbot certonly \
    --webroot -w /var/www/html \
    -d "$DOMAIN" -d "www.$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --no-eff-email

ok "Certificado SSL obtenido"

# ── 11. Configurar Nginx — HTTPS completo ─────────────────────────
info "Configurando Nginx con HTTPS..."
DEPLOY_DIR="$(dirname "${BASH_SOURCE[0]}")"
sed "s/__DOMAIN__/${DOMAIN}/g" "$DEPLOY_DIR/nginx.conf" > "$NGINX_CONF"

nginx -t
systemctl reload nginx
ok "Nginx configurado con HTTPS"

# ── 12. Crear servicio systemd ────────────────────────────────────
info "Creando servicio systemd..."
cat > /etc/systemd/system/rasaapp.service <<SYSTEMD
[Unit]
Description=Rasa Deportes — Docker Compose
Documentation=https://${DOMAIN}
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStartPre=-/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose up -d
TimeoutStartSec=300
TimeoutStopSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable rasaapp.service
ok "Servicio systemd creado y habilitado"

# ── 13. Configurar backup automático con cron ─────────────────────
info "Configurando backup automático..."
BACKUP_SCRIPT="$APP_DIR/deploy/backup.sh"
chmod +x "$BACKUP_SCRIPT" 2>/dev/null || true

CRON_LINE="0 2 * * * $APP_USER bash $BACKUP_SCRIPT >> $APP_DIR/logs/backup.log 2>&1"
CRON_FILE="/etc/cron.d/rasaapp-backup"

echo "$CRON_LINE" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
ok "Backup diario configurado a las 02:00"

# ── 14. Configurar logrotate para logs de la app ──────────────────
info "Configurando rotación de logs..."
cat > /etc/logrotate.d/rasaapp <<LOGROTATE
${APP_DIR}/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d
}
LOGROTATE
ok "Logrotate configurado"

# ── 15. Renovación automática de SSL ─────────────────────────────
info "Verificando renovación automática de SSL..."
systemctl enable certbot.timer 2>/dev/null || {
    # Fallback a cron si certbot.timer no está disponible
    echo "0 3 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'" \
        > /etc/cron.d/certbot-renew
}
ok "Renovación SSL automática habilitada"

# ── 16. Arrancar la aplicación ────────────────────────────────────
info "Arrancando la aplicación..."
cd "$APP_DIR"
systemctl start rasaapp.service

echo ""
info "Esperando que la aplicación esté lista..."
MAX_WAIT=120
WAITED=0
until curl -sf "http://localhost:8080/actuator/health" >/dev/null 2>&1; do
    sleep 5
    WAITED=$((WAITED + 5))
    echo -n "."
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo ""
        warn "La app tardó más de ${MAX_WAIT}s en arrancar."
        warn "Revisa los logs: docker compose -f $APP_DIR/docker-compose.yml logs app"
        break
    fi
done
echo ""

# ── 17. Verificación final ────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✓ Instalación completada exitosamente            ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Sitio          : https://${DOMAIN}"
echo "  App dir        : $APP_DIR"
echo "  Logs app       : docker compose -C $APP_DIR logs -f app"
echo "  Estado servicio: systemctl status rasaapp"
echo "  Backup manual  : bash $APP_DIR/deploy/backup.sh"
echo "  Actualizar     : bash $APP_DIR/deploy/update.sh"
echo ""
echo "  DNS: asegúrate de que ${DOMAIN} y www.${DOMAIN} apunten a la IP de este servidor."
echo ""
