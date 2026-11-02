#!/usr/bin/env bash
# =====================================================================
# ShieldNet — Script de Sauvegarde Chiffrée Automatisée (PRA / Disaster Recovery)
# Conforme aux normes ISO 27001 et Zero-Vulnerability Standard
# =====================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/shieldnet}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/shieldnet_db_${TIMESTAMP}.sql.gz.enc"
SHA_FILE="${BACKUP_FILE}.sha256"
RETENTION_DAYS=30

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

if [[ -z "${BACKUP_ENCRYPTION_KEY:-}" ]]; then
  echo "[-] ERREUR: Variable BACKUP_ENCRYPTION_KEY non définie. Abandon sécurisé." >&2
  exit 1
fi

echo "[*] Démarrage du dump PostgreSQL sécurisé..."

# Dump compressé et chiffré à la volée en AES-256-CBC
PGPASSWORD="${POSTGRES_PASSWORD:-}" pg_dump \
  -h "${POSTGRES_HOST:-localhost}" \
  -p "${POSTGRES_PORT:-5432}" \
  -U "${POSTGRES_USER:-shieldnet_user}" \
  -d "${POSTGRES_DB:-shieldnet_db}" \
  --format=custom \
  --compress=9 | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -pass env:BACKUP_ENCRYPTION_KEY \
    -out "${BACKUP_FILE}"

# Calcul de l'empreinte d'intégrité SHA-256
sha256sum "${BACKUP_FILE}" > "${SHA_FILE}"
chmod 600 "${BACKUP_FILE}" "${SHA_FILE}"

echo "[+] Sauvegarde chiffrée créée avec succès : ${BACKUP_FILE}"
echo "[+] Empreinte SHA-256 scellée : $(cat "${SHA_FILE}")"

# Rotation des sauvegardes antérieures à 30 jours
echo "[*] Purge des sauvegardes de plus de ${RETENTION_DAYS} jours..."
find "${BACKUP_DIR}" -type f -name "shieldnet_db_*.sql.gz.enc*" -mtime "+${RETENTION_DAYS}" -delete

echo "[+] Processus de sauvegarde PRA terminé avec succès."
