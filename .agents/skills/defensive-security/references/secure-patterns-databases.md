# Patterns de Sécurité des Bases de Données (SQL & NoSQL) — Référence

Ce document détaille les patterns d'implémentation défensifs et les bonnes pratiques pour sécuriser les bases de données relationnelles et non-relationnelles, leurs ORMs et leurs connexions.

---

## 📋 Table des matières

1. [Principes Généraux de Sécurité des Données](#1-principes-généraux-de-sécurité-des-données)
2. [Bases de Données Relationnelles (SQL)](#2-bases-de-données-relationnelles-sql)
   - [Protection contre l'Injection SQL (SQLi)](#protection-contre-linjection-sql-sqli)
   - [Row-Level Security (RLS) sur PostgreSQL](#row-level-security-rls-sur-postgresql)
   - [Principe du Moindre Privilège (Rôles & Permissions)](#principe-du-moindre-privilège-rôles--permissions)
   - [Chiffrement en Transit (SSL/TLS) et au Repos](#chiffrement-en-transit-ssltls-et-au-repos)
   - [Chiffrement au Niveau Colonne (PII & Données Sensibles)](#chiffrement-au-niveau-colonne-pii--données-sensibles)
3. [Bases de Données NoSQL](#3-bases-de-données-nosql)
   - [MongoDB : Prévention des Injections NoSQL](#mongodb--prévention-des-injections-nosql)
   - [Redis : Authentification, ACL et Commandes Dangereuses](#redis--authentification-acl-et-commandes-dangereuses)
   - [Firebase / Firestore : Règles de Sécurité Granulaires](#firebase--firestore--règles-de-sécurité-granulaires)
   - [AWS DynamoDB : Politiques IAM et Chiffrement KMS](#aws-dynamodb--politiques-iam-et-chiffrement-kms)
4. [ORMs & Query Builders Sécurisés par Langage](#4-orms--query-builders-sécurisés-par-langage)
5. [Journalisation & Traçabilité (Audit Logs)](#5-journalisation--traçabilité-audit-logs)

---

## 1. Principes Généraux de Sécurité des Données

1. **Défense en Profondeur :**
   - Ne pas compter uniquement sur le pare-feu réseau : authentification forte, TLS, chiffrement au repos et permissions granulaires sont requis.
2. **Moindre Privilège :**
   - L'application ne doit jamais se connecter en tant que superadministrateur (`postgres`, `root`, `sa`).
   - Séparer les utilisateurs de base de données : un rôle pour les migrations/DDL, un rôle restreint pour les opérations courantes (DML : `SELECT`, `INSERT`, `UPDATE`, `DELETE`), et un rôle en lecture seule pour le reporting.
3. **Zéro Secret dans le Code :**
   - Les chaînes de connexion (ex: `DATABASE_URL`) doivent être injectées via des variables d'environnement chiffrées ou des coffres-forts (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault).

---

## 2. Bases de Données Relationnelles (SQL)

### Protection contre l'Injection SQL (SQLi)

L'injection SQL se produit lorsque des entrées non fiables sont directement concaténées ou interpolées dans une instruction SQL.

#### ❌ Exemples Vulnérables (À PROSCRIRE)

```sql
-- ❌ DANGEREUX : Concaténation de chaîne
query = "SELECT * FROM users WHERE email = '" + userInput + "' AND password = '" + pass + "'";
```

```javascript
// ❌ Node.js raw query vulnérable
db.query(`SELECT * FROM products WHERE category = '${req.query.category}'`);
```

```python
# ❌ Python raw query vulnérable
cursor.execute(f"SELECT * FROM accounts WHERE id = {account_id}")
```

#### ✅ Exemples Sécurisés (Requêtes Préparées / Paramétrées)

```javascript
// ✅ Node.js (pg / PostgreSQL) : Paramètres typés ($1, $2)
const query = 'SELECT id, email, role FROM users WHERE email = $1 AND status = $2';
const values = [email, 'active'];
const res = await pool.query(query, values);
```

```python
# ✅ Python (psycopg2 / sqlite3) : Paramètres préparés
cursor.execute(
    "SELECT id, balance FROM accounts WHERE user_id = %s AND currency = %s",
    (user_id, currency)
)
```

```java
// ✅ Java (JDBC PreparedStatement)
String sql = "SELECT id, username, email FROM users WHERE organization_id = ? AND status = ?";
try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
    pstmt.setLong(1, organizationId);
    pstmt.setString(2, status);
    ResultSet rs = pstmt.executeQuery();
}
```

```csharp
// ✅ C# (ADO.NET SqlCommand)
string query = "SELECT Id, Name FROM Customers WHERE TenantId = @TenantId AND Email = @Email";
using (var cmd = new SqlCommand(query, conn)) {
    cmd.Parameters.Add("@TenantId", SqlDbType.UniqueIdentifier).Value = tenantId;
    cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 255).Value = email;
    using (var reader = cmd.ExecuteReader()) { /* ... */ }
}
```

```php
// ✅ PHP (PDO avec requêtes préparées et émulation désactivée)
$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
$stmt = $pdo->prepare('SELECT id, name FROM users WHERE email = :email AND status = :status');
$stmt->execute(['email' => $email, 'status' => 'active']);
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);
```

```go
// ✅ Go (database/sql)
row := db.QueryRowContext(ctx, "SELECT id, email, created_at FROM users WHERE id = $1 AND is_active = $2", userID, true)
```

---

### Row-Level Security (RLS) sur PostgreSQL

Le Row-Level Security permet d'isoler les données directement au niveau du moteur de la base de données. Très utile pour les architectures multi-tenants (SaaS).

```sql
-- 1. Activer RLS sur la table sensible
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- 2. Forcer RLS même pour le propriétaire de la table (facultatif mais recommandé)
ALTER TABLE documents FORCE ROW LEVEL SECURITY;

-- 3. Définir une politique pour la lecture : l'utilisateur ne lit que les documents de son organisation
CREATE POLICY tenant_isolation_policy_select ON documents
    FOR SELECT
    USING (organization_id = NULLIF(current_setting('app.current_org_id', true), '')::uuid);

-- 4. Définir une politique pour l'écriture : l'utilisateur n'insère que pour son organisation
CREATE POLICY tenant_isolation_policy_insert ON documents
    FOR INSERT
    WITH CHECK (organization_id = NULLIF(current_setting('app.current_org_id', true), '')::uuid);

-- Application dans le code (avant chaque transaction) :
-- SET LOCAL app.current_org_id = '123e4567-e89b-12d3-a456-426614174000';
```

---

### Principe du Moindre Privilège (Rôles & Permissions)

Créer des rôles séparés pour l'exécution applicative, les migrations et la lecture seule :

```sql
-- Création du rôle applicatif sans droits d'administration
CREATE ROLE app_user WITH LOGIN PASSWORD 'Secur3_Str0ng_P@ssw0rd!';

-- Ne donner l'accès qu'au schéma nécessaire
GRANT USAGE ON SCHEMA public TO app_user;

-- Accorder uniquement les permissions DML nécessaires (jamais DROP ou ALTER TABLE)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Définir les droits par défaut pour les futures tables créées par les migrations
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_user;

-- Révoquer les privilèges publics excessifs
REVOKE ALL ON SCHEMA public FROM PUBLIC;
```

---

### Chiffrement en Transit (SSL/TLS) et au Repos

#### Connexion SSL/TLS Forcée (Exemple chaîne de connexion)

```ini
# PostgreSQL (Exiger la validation stricte du certificat de l'autorité racine)
DATABASE_URL=postgresql://app_user:password@db.example.com:5432/production?sslmode=verify-full&sslrootcert=/etc/ssl/certs/db-ca.pem

# MySQL
DATABASE_URL=mysql://app_user:password@db.example.com:3306/production?ssl-mode=VERIFY_IDENTITY&ssl-ca=/etc/ssl/certs/db-ca.pem
```

#### Chiffrement au repos (Transparent Data Encryption - TDE)
- **PostgreSQL / AWS RDS :** Activer KMS Encryption sur le volume de stockage EBS.
- **MySQL / InnoDB :** Activer `innodb_sys_tablespace_encrypt = ON` et le plugin keyring (Keyring Vault ou AWS KMS).
- **SQL Server :** Activer TDE (`CREATE DATABASE ENCRYPTION KEY ... WITH ALGORITHM = AES_256`).

---

### Chiffrement au Niveau Colonne (PII & Données Sensibles)

Pour les données très sensibles (numéros de sécurité sociale, données médicales), utiliser un chiffrement applicatif avant insertion en base, ou le module `pgcrypto`.

```python
# Exemple de chiffrement applicatif de colonne (Python avec Fernet / AES-128-CBC + HMAC)
from cryptography.fernet import Fernet
import os

key = os.environ["FIELD_ENCRYPTION_KEY"].encode()
cipher_suite = Fernet(key)

def encrypt_sensitive_field(plaintext: str) -> bytes:
    return cipher_suite.encrypt(plaintext.encode("utf-8"))

def decrypt_sensitive_field(ciphertext: bytes) -> str:
    return cipher_suite.decrypt(ciphertext).decode("utf-8")
```

---

## 3. Bases de Données NoSQL

### MongoDB : Prévention des Injections NoSQL

Dans MongoDB, les requêtes sont souvent construites à partir d'objets JSON provenant de `req.body` ou `req.query`. Si les types ne sont pas validés, un attaquant peut envoyer un opérateur comme `{"$gt": ""}` pour contourner l'authentification.

#### ❌ Vulnérabilité d'Authentification NoSQL

```javascript
// ❌ Si req.body.password est { "$ne": null }, la condition est TOUJOURS vraie !
app.post('/api/login', async (req, res) => {
  const user = await db.collection('users').findOne({
    username: req.body.username,
    password: req.body.password // Danger si objet injecté
  });
  if (user) res.send("Connecté !");
});
```

#### ✅ Contre-mesures MongoDB

1. **Validation stricte de schéma (Zod / Joi) :**
```javascript
const loginSchema = z.object({
  username: z.string().min(3).max(50),
  password: z.string().min(8).max(128) // Force un string pur, rejette les objets {$ne: ...}
});
```

2. **Désinfection des entrées avec `mongo-sanitize` :**
```javascript
const sanitize = require('mongo-sanitize');

app.post('/api/login', async (req, res) => {
  const cleanUsername = sanitize(req.body.username);
  const cleanPassword = sanitize(req.body.password);
  // Tout préfixe '$' ou '.' est supprimé
});
```

3. **Désactiver le moteur JavaScript côté serveur (Server-Side JS) :**
Lancer mongod avec l'option `--noscripting` pour interdire l'utilisation de l'opérateur dangereux `$where` et `mapReduce`.

---

### Redis : Authentification, ACL et Commandes Dangereuses

Redis est extrêmement rapide mais exécutait historiquement les commandes sans restriction.

#### Configuration Sécurisée `redis.conf` :

```text
# 1. Ne pas écouter sur toutes les interfaces
bind 127.0.0.1 10.0.1.5
protected-mode yes
port 6379

# 2. TLS / SSL pour les connexions distantes
tls-port 6380
port 0
tls-cert-file /etc/redis/tls/redis.crt
tls-key-file /etc/redis/tls/redis.key
tls-ca-cert-file /etc/redis/tls/ca.crt

# 3. Désactiver ou renommer les commandes dangereuses
rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command KEYS ""
rename-command DEBUG ""
rename-command SHUTDOWN "SHUTDOWN_SECRET_RESTRICTED"

# 4. ACL granulaire (Redis 6+)
# Créer un utilisateur applicatif qui n'a accès qu'à son namespace de clés
user app_cache on >Str0ngCacheP@ssw0rd! ~cache:* +@read +@write -@admin
```

---

### Firebase / Firestore : Règles de Sécurité Granulaires

Par défaut, les bases Firestore sont ouvertes si mal configurées. Toujours imposer des règles de sécurité basées sur l'authentification et les droits de propriété.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper : utilisateur connecté
    function isAuthenticated() {
      return request.auth != null;
    }

    // Helper : propriétaire de la ressource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // Règles pour les profils utilisateurs
    match /users/{userId} {
      // Lecture autorisée aux membres authentifiés
      allow read: if isAuthenticated();
      // Modification autorisée uniquement au propriétaire avec validation de schéma
      allow write: if isOwner(userId)
                    && request.resource.data.keys().hasAll(['email', 'name'])
                    && request.resource.data.role == resource.data.role; // Empêcher l'escalade de privilège
    }

    // Règles pour les commandes
    match /orders/{orderId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if false; // Immuable une fois créée
    }
  }
}
```

---

### AWS DynamoDB : Politiques IAM et Chiffrement KMS

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAppAccessToSpecificTableOnly",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:eu-west-1:123456789012:table/AppOrders",
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${cognito-identity.amazonaws.com:sub}"]
        }
      }
    }
  ]
}
```

---

## 4. ORMs & Query Builders Sécurisés par Langage

### Node.js (Prisma & Drizzle)
```typescript
// ✅ Prisma : toujours typer les filtres et sélectionner uniquement les champs requis
const user = await prisma.user.findUnique({
  where: { id: req.params.id },
  select: { id: true, email: true, createdAt: true }, // Projection explicite
});

// ✅ Drizzle ORM avec requête préparée
const prepareUserById = db
  .select({ id: users.id, name: users.name })
  .from(users)
  .where(eq(users.id, sql.placeholder('id')))
  .prepare('getUserById');

const result = await prepareUserById.execute({ id: userId });
```

### Python (SQLAlchemy 2.0)
```python
from sqlalchemy import select, text
from sqlalchemy.orm import Session

# ✅ ORM avec select() typé
stmt = select(User).where(User.email == email, User.is_active == True)
user = session.scalars(stmt).first()

# ✅ Requête SQL brute paramétrée (text() avec bindparams)
stmt_raw = text("SELECT id, name FROM users WHERE tenant_id = :tenant_id").bindparams(tenant_id=tenant_id)
results = session.execute(stmt_raw).mappings().all()
```

### Java / Kotlin (Spring Data JPA)
```java
public interface UserRepository extends JpaRepository<User, Long> {
    // ✅ Requête dérivée générée de façon sécurisée
    Optional<User> findByEmailAndStatus(String email, String status);

    // ✅ Requête JPQL paramétrée
    @Query("SELECT u FROM User u WHERE u.organization.id = :orgId AND u.role = :role")
    List<User> findByOrgAndRole(@Param("orgId") Long orgId, @Param("role") String role);

    // ❌ JAMAIS de concaténation dans @Query native
}
```

### C# (.NET Entity Framework Core)
```csharp
// ✅ LINQ génère du SQL paramétré
var activeUsers = await context.Users
    .AsNoTracking()
    .Where(u => u.TenantId == currentTenantId && u.IsActive)
    .Select(u => new UserDto { Id = u.Id, Email = u.Email })
    .ToListAsync();

// ✅ Si SQL brut nécessaire, utiliser FromSqlInterpolated (protège contre l'injection)
var reports = await context.Reports
    .FromSqlInterpolated($"SELECT * FROM Reports WHERE OwnerId = {userId}")
    .ToListAsync();

// ❌ ÉVITER : FromSqlRaw avec string formaté manuellement
```

---

## 5. Journalisation & Traçabilité (Audit Logs)

Toute modification de données sensibles en base doit être tracée pour la conformité et la détection d'intrusions :

```sql
-- Table d'audit générique
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    record_id UUID NOT NULL,
    old_values JSONB,
    new_values JSONB,
    performed_by VARCHAR(64) NOT NULL,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);
```
