# Architecture Haute Disponibilité (HA) & Clustering Base de Données — ShieldNet

Ce document détaille l'architecture de clustering et de haute disponibilité de la base de données PostgreSQL pour **ShieldNet**, dimensionnée pour supporter plusieurs millions de citoyens québécois et nord-américains sans interruption de service (objectif 99.99 % de disponibilité).

---

## 1. Schéma d'Architecture Haute Disponibilité

```
                           [ Trafic Citoyens & Modération ]
                                         │
                                         ▼
                            [ Nginx Reverse Proxy / ALB ]
                                         │
                                         ▼
                             [ API Django REST Framework ]
                                (PrimaryReplicaRouter)
                                   /                \
                       (Écritures / DDL)         (Lectures / Lookups)
                                 /                    \
                                ▼                      ▼
                       [ PgBouncer Pooler ]   [ PostgreSQL Réplique ]
                       (Transaction Mode)       (Standby Read-Only)
                                │                      ▲
                                ▼                      │ (Streaming WAL
                     [ PostgreSQL Primaire ] ──────────┘   SCRAM-SHA-256)
                       (Master Read/Write)
```

---

## 2. Principes Fondamentaux de la Solution

1. **Séparation Lecture / Écriture (Read/Write Splitting) :**
   - 95 % des requêtes ShieldNet sont des opérations de lecture (vérification de numéros, radar des arnaques, avis communautaires). Ces requêtes sont dirigées vers le nœud **PostgreSQL Réplique** via le routeur applicatif `PrimaryReplicaDatabaseRouter`.
   - Les 5 % restants (signalements de spam, création de comptes, modifications de listes personnelles) sont dirigés vers le nœud **PostgreSQL Primaire**.
2. **Streaming Replication Asynchrone Sécurisée :**
   - Les modifications sont répliquées en temps réel par flux de WAL (*Write-Ahead Logging*) chiffré avec authentification **SCRAM-SHA-256**.
   - Le délai de réplication moyen (*replication lag*) est inférieur à 10 millisecondes en réseau local.
3. **Pooler de Connexions PgBouncer :**
   - Maintient jusqu'à **10 000 connexions clientes actives** avec un coût mémoire minimal (< 2 Ko par connexion).
   - Mode `transaction pooling` : libère la connexion serveur dès que la transaction SQL est achevée.
4. **Confinement des Migrations :**
   - Le routeur `PrimaryReplicaDatabaseRouter` garantit formellement que la commande `python manage.py migrate` s'exécute **uniquement** sur le nœud primaire (`default`), protégeant la réplique en lecture seule de toute corruption de schéma.

---

## 3. Configuration Applicative Django

### 3.1. Routeur de Base de Données (`shield_api/routers.py`)

Le routeur dynamique `PrimaryReplicaDatabaseRouter` sépare les flux automatiquement :

```python
class PrimaryReplicaDatabaseRouter:
    def db_for_read(self, model, **hints):
        if 'replica' in getattr(settings, 'DATABASES', {}):
            return 'replica'
        return 'default'

    def db_for_write(self, model, **hints):
        return 'default'

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == 'default'
```

### 3.2. Variables d'Environnement de Production

| Variable | Description | Exemple |
| :--- | :--- | :--- |
| `POSTGRES_HOST` | Hôte du pooler ou du nœud primaire | `pgbouncer` ou `db-primary.shieldnet.internal` |
| `POSTGRES_PORT` | Port du pooler PgBouncer | `6432` ou `5432` |
| `POSTGRES_REPLICA_HOST` | Hôte du nœud réplique en lecture seule | `postgres_replica` ou `db-ro.shieldnet.internal` |
| `POSTGRES_REPLICA_PORT` | Port de la réplique en lecture | `5432` |
| `DB_CONN_MAX_AGE` | Durée de vie des connexions persistantes (sec) | `300` |

---

## 4. Déploiement Local & Test du Cluster

Pour lancer l'environnement complet avec Primary, Replica et PgBouncer :

```powershell
docker-compose -f docker-compose.ha.yml up -d
```

### Vérification de l'état de la réplication :

Exécuter la requête suivante sur le nœud primaire :

```sql
SELECT 
    client_addr, 
    state, 
    sync_state, 
    replay_lag, 
    write_lag 
FROM pg_stat_replication;
```

---

## 5. Stratégie de Failover & Haute Disponibilité Cloud

En production sur le Cloud (AWS / GCP / Azure ou OpenShift) :
* **AWS RDS Multi-AZ / Aurora Serverless v2 :** Basculement automatique en moins de 35 secondes en cas de défaillance du nœud primaire avec bascule transparente de l'adresse DNS du cluster.
* **On-Premise (Bare Metal / VM) :** Utilisation de **Patroni** adossé à un cluster **etcd** à 3 nœuds pour l'élection de leader par consensus Raft et la promotion instantanée du standby en primaire.
