#!/usr/bin/env bash
# ==============================================================================
# Script d'Initialisation Sécurisée du Nœud PostgreSQL Primaire
# Configure les droits de réplication en SCRAM-SHA-256 (CWE-250)
# ==============================================================================
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Création de l'utilisateur de réplication avec privilèges minimaux
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
            CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';
        END IF;
    END
    \$\$;
EOSQL

# Autorisation de la réplication depuis le réseau local Docker
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host replication $POSTGRES_USER all scram-sha-256" >> "$PGDATA/pg_hba.conf"
