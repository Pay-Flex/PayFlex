#!/usr/bin/env bash
#
# backup-db.sh — Sauvegarde de la base MySQL PayFlex (mysqldump + compression
# + rétention GFS grandfather-father-son + upload hors-site optionnel via rclone).
#
# Usage :
#   ./backup-db.sh
#
# Variables d'environnement (voir .env.example dans ce dossier) :
#   PAYFLEX_DB_HOST, PAYFLEX_DB_PORT, PAYFLEX_DB_NAME,
#   PAYFLEX_DB_USER, PAYFLEX_DB_PASSWORD,
#   PAYFLEX_BACKUP_DIR,
#   PAYFLEX_BACKUP_RETENTION_DAILY, PAYFLEX_BACKUP_RETENTION_WEEKLY, PAYFLEX_BACKUP_RETENTION_MONTHLY,
#   PAYFLEX_BACKUP_RCLONE_REMOTE, PAYFLEX_BACKUP_RCLONE_PATH,
#   PAYFLEX_BACKUP_LOG_FILE
#
# Prérequis système : mysqldump (client MySQL 8+), gzip. rclone optionnel.
#
# Rendre exécutable avant le premier lancement :
#   chmod +x backup-db.sh restore-db.sh verify-backup.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Charge le fichier .env local du dossier scripts/backup/ s'il existe
# (sans écraser des variables déjà exportées par l'environnement/cron).
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

# --- Valeurs par défaut (alignées sur payflex_backend/.env.example) --------
DB_HOST="${PAYFLEX_DB_HOST:-localhost}"
DB_PORT="${PAYFLEX_DB_PORT:-3306}"
DB_NAME="${PAYFLEX_DB_NAME:-payflexdb}"
DB_USER="${PAYFLEX_DB_USER:-root}"
DB_PASSWORD="${PAYFLEX_DB_PASSWORD:-}"

BACKUP_DIR="${PAYFLEX_BACKUP_DIR:-/var/backups/payflex/db}"
RETENTION_DAILY="${PAYFLEX_BACKUP_RETENTION_DAILY:-7}"
RETENTION_WEEKLY="${PAYFLEX_BACKUP_RETENTION_WEEKLY:-4}"
RETENTION_MONTHLY="${PAYFLEX_BACKUP_RETENTION_MONTHLY:-3}"

RCLONE_REMOTE="${PAYFLEX_BACKUP_RCLONE_REMOTE:-}"
RCLONE_PATH="${PAYFLEX_BACKUP_RCLONE_PATH:-}"

LOG_FILE="${PAYFLEX_BACKUP_LOG_FILE:-}"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "${msg}"
  if [[ -n "${LOG_FILE}" ]]; then
    mkdir -p "$(dirname -- "${LOG_FILE}")"
    echo "${msg}" >> "${LOG_FILE}"
  fi
}

fail() {
  log "ERREUR: $*"
  exit 1
}

command -v mysqldump >/dev/null 2>&1 || fail "mysqldump introuvable. Installez le client MySQL (mysql-client / mysql-community-client)."
command -v gzip >/dev/null 2>&1 || fail "gzip introuvable."

mkdir -p "${BACKUP_DIR}"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/payflex_${DB_NAME}_${TIMESTAMP}.sql.gz"

log "Démarrage sauvegarde de la base '${DB_NAME}' (${DB_HOST}:${DB_PORT}) -> ${BACKUP_FILE}"

# Identifiants via fichier « defaults-extra-file » temporaire (chmod 600) plutôt
# que --password en ligne de commande (visible dans `ps`) ou MYSQL_PWD (visible
# dans /proc/<pid>/environ). Nettoyage garanti même en cas d'erreur (trap).
CREDS_FILE="$(mktemp)"
chmod 600 "${CREDS_FILE}"
trap 'rm -f "${CREDS_FILE}"' EXIT

cat > "${CREDS_FILE}" <<EOF
[client]
user=${DB_USER}
password=${DB_PASSWORD}
host=${DB_HOST}
port=${DB_PORT}
EOF

if ! mysqldump --defaults-extra-file="${CREDS_FILE}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --events \
    --default-character-set=utf8mb4 \
    --databases "${DB_NAME}" \
    | gzip -9 > "${BACKUP_FILE}"; then
  rm -f "${BACKUP_FILE}"
  fail "mysqldump a échoué — aucune sauvegarde partielle conservée."
fi

BACKUP_SIZE="$(du -h "${BACKUP_FILE}" | cut -f1)"
log "Sauvegarde terminée : ${BACKUP_FILE} (${BACKUP_SIZE})"

# --- Upload hors-site optionnel (rclone) ------------------------------------
if [[ -n "${RCLONE_REMOTE}" ]]; then
  if command -v rclone >/dev/null 2>&1; then
    log "Upload hors-site via rclone vers ${RCLONE_REMOTE}:${RCLONE_PATH}..."
    if rclone copy "${BACKUP_FILE}" "${RCLONE_REMOTE}:${RCLONE_PATH}" --log-level ERROR; then
      log "Upload hors-site réussi."
    else
      log "ERREUR: échec de l'upload hors-site (le backup local reste disponible dans ${BACKUP_DIR})."
    fi
  else
    log "AVERTISSEMENT: rclone configuré (PAYFLEX_BACKUP_RCLONE_REMOTE) mais binaire 'rclone' introuvable — upload ignoré."
  fi
else
  log "Upload hors-site désactivé (PAYFLEX_BACKUP_RCLONE_REMOTE vide) — voir README.md pour le configurer."
fi

# --- Rétention GFS (grandfather-father-son) ---------------------------------
# Règle pragmatique appliquée sur les fichiers déjà présents dans BACKUP_DIR :
#   - Quotidien : tout fichier dont l'âge <= RETENTION_DAILY jours est conservé.
#   - Hebdomadaire : au-delà, tout fichier produit un dimanche (jour ISO 7) est
#     conservé jusqu'à RETENTION_DAILY + RETENTION_WEEKLY*7 jours d'âge.
#   - Mensuel : au-delà, tout fichier produit le 1er du mois est conservé
#     jusqu'à RETENTION_DAILY + RETENTION_WEEKLY*7 + RETENTION_MONTHLY*31 jours.
#   - Tout le reste est supprimé.
# Hypothèse : le script tourne une fois par jour sans interruption prolongée
# (voir README.md — section limites). Nécessite GNU date (Linux).
log "Application de la politique de rétention (quotidien=${RETENTION_DAILY}j, hebdo=${RETENTION_WEEKLY}sem, mensuel=${RETENTION_MONTHLY}mois)..."

NOW_EPOCH="$(date '+%s')"
WEEKLY_MAX_AGE_DAYS=$(( RETENTION_DAILY + RETENTION_WEEKLY * 7 ))
MONTHLY_MAX_AGE_DAYS=$(( RETENTION_DAILY + RETENTION_WEEKLY * 7 + RETENTION_MONTHLY * 31 ))

DELETED_COUNT=0
shopt -s nullglob
for f in "${BACKUP_DIR}"/payflex_*.sql.gz; do
  [[ -e "${f}" ]] || continue

  # Extrait AAAAMMJJ_HHMMSS depuis le nom de fichier : payflex_<db>_<ts>.sql.gz
  base="$(basename -- "${f}")"
  ts="${base##*_}"          # HHMMSS.sql.gz -> garde après dernier _
  date_part="${base%_*}"    # retire _HHMMSS.sql.gz
  date_part="${date_part##*_}" # ne garde que AAAAMMJJ

  if [[ ! "${date_part}" =~ ^[0-9]{8}$ ]]; then
    continue # nom de fichier non reconnu, on ne touche pas (sécurité)
  fi

  file_epoch="$(date -d "${date_part}" '+%s' 2>/dev/null || echo "")"
  [[ -z "${file_epoch}" ]] && continue

  age_days=$(( (NOW_EPOCH - file_epoch) / 86400 ))
  day_of_week="$(date -d "${date_part}" '+%u')"   # 1=lundi ... 7=dimanche
  day_of_month="$(date -d "${date_part}" '+%d')"

  keep=false
  if (( age_days <= RETENTION_DAILY )); then
    keep=true
  elif [[ "${day_of_week}" == "7" ]] && (( age_days <= WEEKLY_MAX_AGE_DAYS )); then
    keep=true
  elif [[ "${day_of_month}" == "01" ]] && (( age_days <= MONTHLY_MAX_AGE_DAYS )); then
    keep=true
  fi

  if [[ "${keep}" == "false" ]]; then
    log "Suppression sauvegarde expirée : ${base} (âge ${age_days}j)"
    rm -f "${f}"
    DELETED_COUNT=$((DELETED_COUNT + 1))
  fi
done

log "Rétention appliquée : ${DELETED_COUNT} sauvegarde(s) expirée(s) supprimée(s)."
log "Sauvegarde terminée avec succès."
