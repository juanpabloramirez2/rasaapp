#!/usr/bin/env bash
# =================================================================
# install-ssl.sh — Agrega HTTPS con Let's Encrypt a una instalación
#                  existente hecha con install-ip.sh
# Uso: sudo bash /opt/rasaapp/deploy/install-ssl.sh
# =================================================================
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
info() { echo -e "\n${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Ejecuta como root: sudo bash /opt/rasaapp/deploy/install-ssl.sh"

APP_DIR="/opt/rasaapp"

# ── Leer dominio y email ──────────────────────────────────────────
read -rp $'\033[1;33m[?]\033[0m Dominio principal (sin www): ' DOMAIN
[[ -z "$DOMAIN" ]] && die "El dominio no puede estar vacío"

read -rp $'\033[1;33m[?]\033[0m Email para Let'\''s Encrypt: ' EMAIL
[[ -z "$EMAIL" ]] && die "El email no puede estar vacío"

echo ""
info "Dominio : $DOMAIN"
info "Email   : $EMAIL"

# ── 1. Instalar Certbot ───────────────────────────────────────────
info "Instalando Certbot..."
apt-get update -qq
apt-get install -y -qq certbot python3-certbot-nginx
ok "Certbot instalado"

# ── 2. Nginx temporal para validación webroot ─────────────────────
info "Configurando Nginx para validación Let's Encrypt..."
cat > /etc/nginx/sites-available/rasaapp <<NGINX_HTTP
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${DOMAIN} www.${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
    }
}
NGINX_HTTP

nginx -t && systemctl reload nginx
ok "Nginx listo para validación"

# ── 3. Obtener certificado SSL ────────────────────────────────────
info "Obteniendo certificado SSL para $DOMAIN..."
certbot certonly \
    --webroot -w /var/www/html \
    -d "$DOMAIN" -d "www.$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --no-eff-email
ok "Certificado SSL obtenido"

# ── 4. Nginx con HTTPS completo ───────────────────────────────────
info "Configurando Nginx con HTTPS..."
cat > /etc/nginx/sites-available/rasaapp <<NGINX_HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${DOMAIN} www.${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options           SAMEORIGIN                            always;
    add_header X-Content-Type-Options    nosniff                               always;
    add_header X-XSS-Protection          "1; mode=block"                       always;

    client_max_body_size 10M;

    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;

    access_log /var/log/nginx/rasaapp_access.log;
    error_log  /var/log/nginx/rasaapp_error.log;

    location /actuator/ {
        deny all;
        return 403;
    }

    location ~* \.(js|css|woff2?|ttf|eot|svg|ico)$ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /uploads/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        expires 7d;
    }

    location / {
        proxy_pass         http://localhost:8080;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
}
NGINX_HTTPS

nginx -t && systemctl reload nginx
ok "Nginx configurado con HTTPS"

# ── 5. Renovación automática ──────────────────────────────────────
info "Configurando renovación automática de SSL..."
systemctl enable certbot.timer 2>/dev/null || \
    echo "0 3 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'" \
        > /etc/cron.d/certbot-renew
ok "Renovación automática habilitada"

# ── Resumen ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✓ HTTPS configurado correctamente                ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Sitio web   : https://${DOMAIN}"
echo "  Panel admin : https://${DOMAIN}/login"
echo ""
