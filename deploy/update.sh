#!/usr/bin/env bash
# =================================================================
# update.sh — Actualizar Rasa Deportes en producción
# Uso: bash deploy/update.sh [--no-pull]
#   --no-pull  No hace git pull (útil si subiste los archivos por scp)
# =================================================================
set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
info()  { echo -e "\n${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Configuración ─────────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_URL="http://localhost:8080/actuator/health"
HEALTH_RETRIES=30
HEALTH_INTERVAL=5
NO_PULL=false

[[ "${1:-}" == "--no-pull" ]] && NO_PULL=true

cd "$APP_DIR"
[[ ! -f docker-compose.yml ]] && die "No se encontró docker-compose.yml en $APP_DIR"

# ── 1. Git pull ───────────────────────────────────────────────────
if [[ "$NO_PULL" == false ]]; then
    info "Obteniendo últimos cambios del repositorio..."
    if git rev-parse --git-dir &>/dev/null; then
        CURRENT_COMMIT=$(git rev-parse --short HEAD)
        git fetch origin
        BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "0")

        if [[ "$BEHIND" -eq 0 ]]; then
            ok "Ya estás en la versión más reciente ($CURRENT_COMMIT)"
            echo -n "¿Forzar rebuild de todas formas? [s/N]: "
            read -r FORCE
            [[ ! "$FORCE" =~ ^[sS]$ ]] && exit 0
        fi

        git pull origin main
        NEW_COMMIT=$(git rev-parse --short HEAD)
        ok "Actualizado: $CURRENT_COMMIT → $NEW_COMMIT"
    else
        warn "No es un repo git. Continuando sin git pull."
    fi
fi

# ── 2. Guardar estado actual como respaldo ────────────────────────
info "Guardando imagen actual como respaldo..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
IMAGE_NAME="rasaapp-app"

# Tag de la imagen actual para rollback
if docker image inspect "${IMAGE_NAME}:latest" &>/dev/null; then
    docker tag "${IMAGE_NAME}:latest" "${IMAGE_NAME}:rollback-${TIMESTAMP}"
    ok "Imagen actual etiquetada como rollback-${TIMESTAMP}"
fi

# ── 3. Construir nueva imagen ─────────────────────────────────────
info "Construyendo nueva imagen Docker..."
docker compose build --no-cache app
ok "Imagen construida"

# ── 4. Aplicar la actualización ───────────────────────────────────
info "Reiniciando servicio de aplicación..."
docker compose up -d --no-deps app
ok "Contenedor reiniciado"

# ── 5. Verificar salud ────────────────────────────────────────────
info "Verificando salud de la aplicación..."
echo -n "Esperando"
HEALTHY=false
for i in $(seq 1 $HEALTH_RETRIES); do
    sleep $HEALTH_INTERVAL
    echo -n "."
    if curl -sf "$HEALTH_URL" | grep -q '"status":"UP"' 2>/dev/null; then
        HEALTHY=true
        break
    fi
done
echo ""

# ── 6. Resultado ──────────────────────────────────────────────────
if [[ "$HEALTHY" == true ]]; then
    ok "Aplicación saludable. Actualización exitosa."

    # Limpiar imágenes de rollback antiguas (conservar las últimas 3)
    docker images --format '{{.Tag}} {{.ID}}' \
        | grep "^rollback-" \
        | sort -r \
        | tail -n +4 \
        | awk '{print $2}' \
        | xargs -r docker rmi 2>/dev/null || true

    # Limpiar imágenes huérfanas
    docker image prune -f >/dev/null 2>&1 || true

    echo ""
    echo -e "${GREEN}  Versión desplegada: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')${NC}"
    echo -e "${GREEN}  Estado: $(curl -s $HEALTH_URL 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["status"])' 2>/dev/null || echo 'UP')${NC}"
else
    warn "La aplicación no respondió en $((HEALTH_RETRIES * HEALTH_INTERVAL))s. Iniciando rollback..."

    # Buscar imagen de rollback
    ROLLBACK_IMAGE=$(docker images --format '{{.Tag}}' \
        | grep "^rollback-" | sort -r | head -1)

    if [[ -n "$ROLLBACK_IMAGE" ]]; then
        docker tag "${IMAGE_NAME}:${ROLLBACK_IMAGE}" "${IMAGE_NAME}:latest"
        docker compose up -d --no-deps app

        sleep 10
        if curl -sf "$HEALTH_URL" | grep -q '"status":"UP"' 2>/dev/null; then
            warn "Rollback exitoso. La versión anterior fue restaurada."
        else
            die "Rollback también falló. Revisa los logs: docker compose logs app"
        fi
    else
        die "No hay imagen de rollback disponible. Revisa: docker compose logs app"
    fi

    exit 1
fi
