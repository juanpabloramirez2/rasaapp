#!/usr/bin/env bash
# =================================================================
# backup.sh — Backup de MySQL para Rasa Deportes
# Uso manual : bash deploy/backup.sh
# Automático : cron diario a las 02:00 (configurado por install.sh)
# =================================================================
set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$APP_DIR/backups"
RETENTION_DAYS=30          # cuántos días conservar backups diarios
WEEKLY_RETENTION_WEEKS=12  # cuántas semanas conservar backups semanales
DB_CONTAINER="rasaapp_db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# ── Helpers ───────────────────────────────────────────────────────
log()  { echo "${LOG_PREFIX} $*"; }
fail() { echo "${LOG_PREFIX} [ERROR] $*" >&2; exit 1; }

# ── Cargar variables de entorno ───────────────────────────────────
ENV_FILE="$APP_DIR/.env"
[[ ! -f "$ENV_FILE" ]] && fail "No se encontró $ENV_FILE"
set -o allexport
source "$ENV_FILE"
set +o allexport

# Validar variables requeridas
[[ -z "${DB_NAME:-}"      ]] && DB_NAME="rasadb"
[[ -z "${DB_ROOT_PASS:-}" ]] && fail "DB_ROOT_PASS no está definido en .env"

# ── Verificar que el contenedor está corriendo ────────────────────
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    fail "El contenedor $DB_CONTAINER no está corriendo"
fi

# ── Crear directorio de backups ───────────────────────────────────
mkdir -p "$BACKUP_DIR"

# ── Backup completo ───────────────────────────────────────────────
BACKUP_FILE="${BACKUP_DIR}/rasadb_${TIMESTAMP}.sql.gz"
log "Iniciando backup de $DB_NAME → $BACKUP_FILE"

docker exec "$DB_CONTAINER" \
    mysqldump \
        -uroot -p"${DB_ROOT_PASS}" \
        --single-transaction \
        --routines \
        --triggers \
        --add-drop-table \
        "$DB_NAME" \
    | gzip -9 > "$BACKUP_FILE"

BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup completado: $BACKUP_FILE ($BACKUP_SIZE)"

# ── Copia semanal (domingos) ──────────────────────────────────────
if [[ $(date +%u) -eq 7 ]]; then
    WEEKLY_DIR="$BACKUP_DIR/weekly"
    mkdir -p "$WEEKLY_DIR"
    WEEKLY_FILE="${WEEKLY_DIR}/rasadb_weekly_${TIMESTAMP}.sql.gz"
    cp "$BACKUP_FILE" "$WEEKLY_FILE"
    log "Copia semanal guardada: $WEEKLY_FILE"

    # Limpiar semanales viejos
    find "$WEEKLY_DIR" -name "*.sql.gz" -mtime "+$((WEEKLY_RETENTION_WEEKS * 7))" -delete
    log "Backups semanales mayores a ${WEEKLY_RETENTION_WEEKS} semanas eliminados"
fi

# ── Rotación — eliminar backups diarios viejos ────────────────────
DELETED=$(find "$BACKUP_DIR" -maxdepth 1 -name "rasadb_*.sql.gz" \
    -mtime "+${RETENTION_DAYS}" -print -delete | wc -l)
log "Backups diarios mayores a ${RETENTION_DAYS} días eliminados: $DELETED"

# ── Verificar integridad del backup ──────────────────────────────
if ! gzip -t "$BACKUP_FILE" 2>/dev/null; then
    fail "El backup creado está corrupto: $BACKUP_FILE"
fi
log "Integridad verificada OK"

# ── Resumen ───────────────────────────────────────────────────────
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.sql.gz" | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
log "Backups almacenados: $TOTAL_BACKUPS | Tamaño total: $TOTAL_SIZE"
log "Backup finalizado correctamente"

# ── Restauración (instrucciones) ──────────────────────────────────
# Para restaurar un backup:
#   gunzip -c /ruta/backup.sql.gz | docker exec -i rasaapp_db \
#       mysql -uroot -p${DB_ROOT_PASS} rasadb
