#!/usr/bin/env bash
# Uso: bash /opt/rasaapp/deploy/update.sh
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; RED='\033[1;31m'; NC='\033[0m'
info() { echo -e "\n${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

APP_DIR="/opt/rasaapp"
REPO="https://github.com/juanpabloramirez2/rasaapp.git"
TMP_DIR="/tmp/rasaapp-update"

info "Descargando última versión de GitHub..."
rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO" "$TMP_DIR"

info "Copiando archivos (sin tocar .env ni uploads)..."
rsync -a --exclude='.git' --exclude='.env' --exclude='uploads/' "$TMP_DIR/" "$APP_DIR/"

info "Reconstruyendo imagen..."
cd "$APP_DIR"
docker compose build --no-cache app

info "Reiniciando aplicación..."
docker compose up -d --no-deps app

info "Esperando que la app esté lista..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8080/actuator/health >/dev/null 2>&1; then
        ok "Actualización completada"
        exit 0
    fi
    echo -n "."
    sleep 5
done

echo ""
die "La app no respondió. Revisa: docker compose -C $APP_DIR logs app"
