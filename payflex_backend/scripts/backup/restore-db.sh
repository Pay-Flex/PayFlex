#!/usr/bin/env bash
#
# restore-db.sh — Restaure un dump PayFlex (.sql ou .sql.gz) dans une base
# MySQL cible, avec garde-fous (confirmation explicite, vérification fichier).
#
# Usage :
#   ./restore-db.sh /var/backups/payflex/db/payflex_payflexdb_20260717_030000.sql.gz
#   ./restore-db.sh <fichier.sql.gz> --target-db payflexdb_test   # base cible différente
#   ./restore-db.sh <fichier.sql.gz> --force                      # sans confirmation (CI/scripts)
#
# Variables d'environnement (voir .env.example) :
#   PAYFLEX_DB_HOST, PAYFLEX_DB_PORT, PAYFLEX_DB_NAME,
#   PAYFLEX_DB_USER, PAYFLEX_DB_PASSWORD
#
# ATTENTION : ce script ÉCRASE le contenu de la base cible. Il est conçu pour
# restaurer un dump de secours en cas de sinistre, ou pour tester une
# restauration (voir verify-backup.sh pour un test automatisé et sans risque).
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

usage() {
  echo "Usage: $0 <fichier_dump.sql|.sql.gz> [--target-db NOM_BASE] [--force]"
  exit 1
}

DUMP_FILE=""
TARGET_DB="${PAYFLEX_DB_NAME:-payflexdb}"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-db)
      TARGET_DB="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "${DUMP_FILE}" ]]; then
        DUMP_FILE="$1"
        shift
      else
        echo "Argument inconnu : $1" >&2
        usage
      fi
      ;;
  esac
done

[[ -z "${DUMP_FILE}" ]] && usage

DB_HOST="${PAYFLEX_DB_HOST:-localhost}"
DB_PORT="${PAYFLEX_DB_PORT:-3306}"
DB_USER="${PAYFLEX_DB_USER:-root}"
DB_PASSWORD="${PAYFLEX_DB_PASSWORD:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
fail() { log "ERREUR: $*"; exit 1; }

# --- Garde-fou 1 : le fichier de dump doit exister et être lisible ---------
[[ -f "${DUMP_FILE}" ]] || fail "Fichier introuvable : ${DUMP_FILE}"
[[ -r "${DUMP_FILE}" ]] || fail "Fichier non lisible : ${DUMP_FILE}"

command -v mysql >/dev/null 2>&1 || fail "client 'mysql' introuvable. Installez le client MySQL."
if [[ "${DUMP_FILE}" == *.gz ]]; then
  command -v gzip >/dev/null 2>&1 || fail "gzip introuvable (nécessaire pour décompresser ${DUMP_FILE})."
fi

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

# --- Garde-fou 2 : la base cible doit-elle déjà exister ? -------------------
DB_EXISTS="$(mysql --defaults-extra-file="${CREDS_FILE}" -N -e \
  "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${TARGET_DB}';")"

log "Cible : base '${TARGET_DB}' sur ${DB_HOST}:${DB_PORT} (existe déjà : ${DB_EXISTS})"
log "Fichier de dump : ${DUMP_FILE}"

# --- Garde-fou 3 : confirmation explicite avant d'écraser -------------------
if [[ "${FORCE}" == "false" ]]; then
  if [[ "${DB_EXISTS}" == "1" ]]; then
    echo ""
    echo "/!\\ ATTENTION : la base '${TARGET_DB}' existe déjà et va être ÉCRASÉE"
    echo "    par le contenu de : ${DUMP_FILE}"
    echo "    Cette opération est IRRÉVERSIBLE (aucun rollback automatique)."
    echo ""
  else
    echo ""
    echo "La base '${TARGET_DB}' n'existe pas encore, elle sera créée puis peuplée"
    echo "depuis : ${DUMP_FILE}"
    echo ""
  fi
  read -r -p "Tapez exactement CONFIRMER pour continuer : " CONFIRMATION
  if [[ "${CONFIRMATION}" != "CONFIRMER" ]]; then
    log "Restauration annulée par l'utilisateur (confirmation non reçue)."
    exit 1
  fi
fi

log "Création de la base '${TARGET_DB}' si nécessaire..."
mysql --defaults-extra-file="${CREDS_FILE}" -e \
  "CREATE DATABASE IF NOT EXISTS \`${TARGET_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

log "Démarrage de la restauration (peut prendre plusieurs minutes selon la taille)..."
START_TIME="$(date '+%s')"

# Le dump généré par backup-db.sh contient --databases (CREATE DATABASE + USE),
# donc on ne force pas la cible via `mysql <db>` : on laisse le dump piloter,
# sauf si --target-db diffère du nom encodé dans le dump (cas restauration
# vers une base de test) — dans ce cas on redirige explicitement via USE.
if [[ "${DUMP_FILE}" == *.gz ]]; then
  if [[ "${TARGET_DB}" != "${PAYFLEX_DB_NAME:-payflexdb}" ]]; then
    gzip -dc "${DUMP_FILE}" | mysql --defaults-extra-file="${CREDS_FILE}" --force "${TARGET_DB}"
  else
    gzip -dc "${DUMP_FILE}" | mysql --defaults-extra-file="${CREDS_FILE}"
  fi
else
  if [[ "${TARGET_DB}" != "${PAYFLEX_DB_NAME:-payflexdb}" ]]; then
    mysql --defaults-extra-file="${CREDS_FILE}" --force "${TARGET_DB}" < "${DUMP_FILE}"
  else
    mysql --defaults-extra-file="${CREDS_FILE}" < "${DUMP_FILE}"
  fi
fi

END_TIME="$(date '+%s')"
log "Restauration terminée en $(( END_TIME - START_TIME ))s dans la base '${TARGET_DB}'."
log "Pensez à relancer le backend (Flyway vérifiera la cohérence du schéma au démarrage)."
