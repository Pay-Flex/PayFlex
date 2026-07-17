#!/usr/bin/env bash
#
# verify-backup.sh — Test de restauration automatisé (« restore drill »).
# Restaure la dernière sauvegarde (ou une sauvegarde donnée) dans une base
# temporaire jetable, exécute une requête de sanity check, puis nettoie.
#
# Objectif : une sauvegarde jamais restaurée n'est pas une sauvegarde fiable.
# À exécuter périodiquement (recommandé : mensuel — voir README.md, section
# planification) idéalement sur un serveur/instance MySQL de test, PAS sur la
# base de production (même si ce script utilise une base temporaire dédiée
# et la supprime en fin d'exécution, préférez un serveur MySQL distinct si
# possible pour ne pas ajouter de charge/risque sur la prod).
#
# Usage :
#   ./verify-backup.sh                     # vérifie la sauvegarde la plus récente
#   ./verify-backup.sh /chemin/dump.sql.gz # vérifie une sauvegarde spécifique
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

DB_HOST="${PAYFLEX_DB_HOST:-localhost}"
DB_PORT="${PAYFLEX_DB_PORT:-3306}"
DB_USER="${PAYFLEX_DB_USER:-root}"
DB_PASSWORD="${PAYFLEX_DB_PASSWORD:-}"
BACKUP_DIR="${PAYFLEX_BACKUP_DIR:-/var/backups/payflex/db}"

# Table dont on vérifie qu'elle contient bien des lignes après restauration
# (sanity check minimal — voir README.md pour étoffer la checklist).
SANITY_TABLE="${PAYFLEX_BACKUP_VERIFY_TABLE:-users}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
fail() { log "ERREUR: $*"; exit 1; }

DUMP_FILE="${1:-}"
if [[ -z "${DUMP_FILE}" ]]; then
  DUMP_FILE="$(ls -1t "${BACKUP_DIR}"/payflex_*.sql.gz 2>/dev/null | head -n 1 || true)"
  [[ -z "${DUMP_FILE}" ]] && fail "Aucune sauvegarde trouvée dans ${BACKUP_DIR}."
fi
[[ -f "${DUMP_FILE}" ]] || fail "Fichier introuvable : ${DUMP_FILE}"

command -v mysql >/dev/null 2>&1 || fail "client 'mysql' introuvable."
command -v gzip >/dev/null 2>&1 || fail "gzip introuvable."

VERIFY_DB="payflex_verify_restore_$(date '+%s')"

CREDS_FILE="$(mktemp)"
chmod 600 "${CREDS_FILE}"
cleanup() {
  log "Nettoyage : suppression de la base temporaire '${VERIFY_DB}'..."
  mysql --defaults-extra-file="${CREDS_FILE}" -e "DROP DATABASE IF EXISTS \`${VERIFY_DB}\`;" 2>/dev/null || true
  rm -f "${CREDS_FILE}"
}
trap cleanup EXIT

cat > "${CREDS_FILE}" <<EOF
[client]
user=${DB_USER}
password=${DB_PASSWORD}
host=${DB_HOST}
port=${DB_PORT}
EOF

log "=== Test de restauration : ${DUMP_FILE} ==="
log "Base temporaire jetable : ${VERIFY_DB}"

mysql --defaults-extra-file="${CREDS_FILE}" -e \
  "CREATE DATABASE \`${VERIFY_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

log "Restauration en cours dans '${VERIFY_DB}'..."
START_TIME="$(date '+%s')"
if ! gzip -dc "${DUMP_FILE}" | mysql --defaults-extra-file="${CREDS_FILE}" --force "${VERIFY_DB}"; then
  fail "La restauration a échoué — la sauvegarde est probablement corrompue ou incompatible."
fi
END_TIME="$(date '+%s')"
log "Restauration réussie en $(( END_TIME - START_TIME ))s."

log "Sanity check : comptage des lignes de la table '${SANITY_TABLE}'..."
ROW_COUNT="$(mysql --defaults-extra-file="${CREDS_FILE}" -N -e \
  "SELECT COUNT(*) FROM \`${VERIFY_DB}\`.\`${SANITY_TABLE}\`;" 2>/dev/null || echo "ERREUR")"

if [[ "${ROW_COUNT}" == "ERREUR" ]]; then
  fail "Impossible de lire la table '${SANITY_TABLE}' dans la base restaurée — sauvegarde suspecte."
fi

if [[ "${ROW_COUNT}" -eq 0 ]]; then
  log "AVERTISSEMENT : la table '${SANITY_TABLE}' est restaurée mais VIDE (0 ligne)."
  log "Vérifiez qu'il s'agit bien d'un dump de production et pas d'une base de test vide."
else
  log "OK : ${ROW_COUNT} ligne(s) dans '${SANITY_TABLE}' après restauration."
fi

log "=== Test de restauration terminé avec succès pour : $(basename -- "${DUMP_FILE}") ==="
log "Checklist complémentaire manuelle (voir README.md) : comparer le nombre de"
log "lignes à une valeur attendue connue, vérifier quelques tables clés"
log "(contributions, agents, admin_users), vérifier la date de dernière ligne."
