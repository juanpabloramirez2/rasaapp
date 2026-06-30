#!/usr/bin/env bash
# =================================================================
# install-ip.sh — Instalación sin dominio ni SSL (acceso por IP)
# Uso: sudo bash deploy/install-ip.sh
# Ejecutar desde la raíz del proyecto (donde está docker-compose.yml)
# =================================================================
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
info() { echo -e "\n${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Ejecuta como root: sudo bash deploy/install-ip.sh"
[[ ! -f docker-compose.yml ]] && die "Ejecuta desde la raíz del proyecto"

echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Rasa Deportes — Instalación sin dominio (HTTP)   ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"

APP_DIR="/opt/rasaapp"
APP_USER="rasaapp"

# ── 1. Actualizar sistema ─────────────────────────────────────────
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
    ok "Nginx instalado"
else
    ok "Nginx ya instalado"
fi

# ── 4. Crear usuario del sistema ──────────────────────────────────
info "Configurando usuario $APP_USER..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d "$APP_DIR" "$APP_USER"
    ok "Usuario $APP_USER creado"
fi
usermod -aG docker "$APP_USER"

# ── 5. Copiar proyecto ────────────────────────────────────────────
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

# ── 6. Crear .env ─────────────────────────────────────────────────
if [[ ! -f "$APP_DIR/.env" ]]; then
    cp "$APP_DIR/.env.example" "$APP_DIR/.env"
    chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env"
    warn "Archivo .env creado en $APP_DIR/.env"
    warn "Edítalo con tus credenciales reales:"
    echo ""
    echo "  nano $APP_DIR/.env"
    echo ""
    read -rp $'\033[1;33m[?]\033[0m Presiona ENTER cuando hayas guardado el .env...'
else
    ok ".env ya existe"
fi

set -o allexport; source "$APP_DIR/.env"; set +o allexport

# ── 7. Firewall ───────────────────────────────────────────────────
info "Configurando firewall..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable
ok "Firewall: SSH y puerto 80 abiertos"

# ── 8. Nginx HTTP → proxy a Spring Boot ──────────────────────────
info "Configurando Nginx..."
cat > /etc/nginx/sites-available/rasaapp <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    client_max_body_size 10M;

    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;

    location /actuator/ {
        deny all;
        return 403;
    }

    location /uploads/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_cache_valid 200 7d;
    }

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/rasaapp /etc/nginx/sites-enabled/rasaapp
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
ok "Nginx configurado"

# ── 9. Servicio systemd ───────────────────────────────────────────
info "Creando servicio systemd..."
cat > /etc/systemd/system/rasaapp.service <<SYSTEMD
[Unit]
Description=Rasa Deportes — Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
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

# ── 10. Arrancar la aplicación ────────────────────────────────────
info "Arrancando la aplicación (puede tardar 2-3 minutos)..."
cd "$APP_DIR"
systemctl start rasaapp.service

MAX_WAIT=180
WAITED=0
until curl -sf "http://localhost:8080/actuator/health" >/dev/null 2>&1; do
    sleep 5
    WAITED=$((WAITED + 5))
    echo -n "."
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo ""
        warn "La app tardó más de ${MAX_WAIT}s. Revisa los logs:"
        warn "  docker compose -C $APP_DIR logs app"
        break
    fi
done
echo ""

# ── Resumen ───────────────────────────────────────────────────────
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✓ Instalación completada                         ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Sitio web      : http://${SERVER_IP}"
echo "  Panel admin    : http://${SERVER_IP}/login"
echo "  App dir        : $APP_DIR"
echo "  Ver logs       : docker compose -C $APP_DIR logs -f app"
echo "  Estado         : systemctl status rasaapp"
echo ""
echo "  Cuando tengas un dominio, ejecuta:"
echo "  sudo bash $APP_DIR/deploy/install-ssl.sh"
echo ""
