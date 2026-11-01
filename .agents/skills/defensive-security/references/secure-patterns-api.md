# Patterns API sécurisés — Référence

Exemples de code sécurisé pour les API REST et GraphQL.

---

## API REST sécurisée

### Structure d'un endpoint sécurisé

```javascript
// ✅ Pattern complet : validation → auth → authz → rate limit → logique métier
const router = express.Router();

router.post(
  '/api/v1/transfers',
  rateLimiter({ windowMs: 60000, max: 10 }),  // 1. Rate limiting
  authenticate,                                // 2. Authentification
  authorize(['user', 'admin']),                // 3. Autorisation par rôle
  validate(transferSchema),                    // 4. Validation des entrées
  auditLog('TRANSFER_INITIATED'),             // 5. Log d'audit
  async (req, res, next) => {                  // 6. Logique métier
    try {
      const { amount, recipientId } = req.validatedBody;

      // Vérification métier supplémentaire
      if (amount > req.user.dailyLimit) {
        return res.status(403).json({
          error: 'Montant supérieur à la limite quotidienne'
        });
      }

      const result = await transferService.execute({
        senderId: req.user.id, // ID depuis le token, pas du body
        recipientId,
        amount,
      });

      res.status(201).json({ transferId: result.id, status: 'pending' });
    } catch (error) {
      next(error);
    }
  }
);
```

---

## Middleware d'autorisation granulaire

```javascript
// Autorisation basée sur les rôles ET la propriété de la ressource
function authorize(allowedRoles = [], options = {}) {
  return async (req, res, next) => {
    const user = req.user;

    if (!user) {
      return res.status(401).json({ error: 'Non authentifié' });
    }

    // Vérification du rôle
    if (allowedRoles.length > 0 && !allowedRoles.some(r => user.roles.includes(r))) {
      securityLogger.warn({
        event: 'AUTHORIZATION_DENIED',
        userId: user.id,
        requiredRoles: allowedRoles,
        userRoles: user.roles,
        resource: req.originalUrl,
      });
      return res.status(403).json({ error: 'Accès refusé' });
    }

    // Vérification de la propriété (si applicable)
    if (options.checkOwnership && req.params.id) {
      const resourceOwnerId = await options.getOwnerId(req.params.id);
      if (resourceOwnerId !== user.id && !user.roles.includes('admin')) {
        securityLogger.warn({
          event: 'OWNERSHIP_VIOLATION',
          userId: user.id,
          resourceId: req.params.id,
        });
        return res.status(403).json({ error: 'Accès refusé' });
      }
    }

    next();
  };
}

// Usage
router.put(
  '/api/users/:id',
  authenticate,
  authorize(['user', 'admin'], {
    checkOwnership: true,
    getOwnerId: (id) => UserService.getOwnerId(id),
  }),
  updateUser
);
```

---

## Configuration CORS sécurisée

```javascript
const cors = require('cors');

// ❌ MAUVAIS : Wildcard en production
app.use(cors({ origin: '*' }));

// ✅ BON : Whitelist stricte
const ALLOWED_ORIGINS = [
  'https://app.example.com',
  'https://admin.example.com',
];

if (process.env.NODE_ENV === 'development') {
  ALLOWED_ORIGINS.push('http://localhost:3000');
}

app.use(cors({
  origin: (origin, callback) => {
    // Autoriser les requêtes sans origin (mobile apps, curl)
    if (!origin) return callback(null, true);

    if (ALLOWED_ORIGINS.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Non autorisé par CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
  credentials: true,
  maxAge: 86400, // Pré-flight cache : 24h
}));
```

---

## Pagination obligatoire

```javascript
// ✅ Middleware de pagination avec limites
function paginate(defaults = { maxLimit: 100, defaultLimit: 20 }) {
  return (req, res, next) => {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(
      defaults.maxLimit,
      Math.max(1, parseInt(req.query.limit) || defaults.defaultLimit)
    );
    const offset = (page - 1) * limit;

    req.pagination = { page, limit, offset };
    next();
  };
}

// Usage
router.get('/api/users', authenticate, paginate(), async (req, res) => {
  const { limit, offset, page } = req.pagination;

  const { count, rows } = await User.findAndCountAll({
    attributes: ['id', 'name', 'email'], // Projection explicite
    limit,
    offset,
    order: [['createdAt', 'DESC']],
  });

  res.json({
    data: rows,
    pagination: {
      page,
      limit,
      total: count,
      totalPages: Math.ceil(count / limit),
    },
  });
});
```

---

## Réponses d'erreur sécurisées

```javascript
// ✅ Classes d'erreur métier (pas de fuite d'information)
class AppError extends Error {
  constructor(message, statusCode, code) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Ressource') {
    super(`${resource} introuvable`, 404, 'NOT_FOUND');
  }
}

class ForbiddenError extends AppError {
  constructor() {
    super('Accès refusé', 403, 'FORBIDDEN');
  }
}

class ValidationError extends AppError {
  constructor(details) {
    super('Données invalides', 400, 'VALIDATION_ERROR');
    this.details = details;
  }
}

// Middleware global d'erreur
app.use((err, req, res, next) => {
  // Logger en interne
  logger.error({
    event: 'API_ERROR',
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.originalUrl,
    userId: req.user?.id,
    ip: req.ip,
  });

  if (err.isOperational) {
    // Erreurs attendues : renvoyer le message
    const response = {
      error: { code: err.code, message: err.message },
    };
    if (err.details) response.error.details = err.details;
    return res.status(err.statusCode).json(response);
  }

  // Erreurs inattendues : message générique
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'Une erreur interne est survenue',
    },
  });
});
```

---

## GraphQL — Sécurisation

### Protections essentielles

```javascript
const { ApolloServer } = require('@apollo/server');
const depthLimit = require('graphql-depth-limit');
const costAnalysis = require('graphql-cost-analysis');
const { rateLimitDirective } = require('graphql-rate-limit-directive');

const server = new ApolloServer({
  typeDefs,
  resolvers,
  validationRules: [
    // ✅ Limiter la profondeur des requêtes (empêche les requêtes récursives)
    depthLimit(5),

    // ✅ Limiter la complexité des requêtes
    costAnalysis({
      maximumCost: 1000,
      defaultCost: 1,
      variables: {},
      onComplete: (cost) => {
        if (cost > 800) {
          logger.warn({ event: 'GRAPHQL_HIGH_COST', cost });
        }
      },
    }),
  ],

  // ✅ Désactiver l'introspection en production
  introspection: process.env.NODE_ENV !== 'production',

  // ✅ Ne pas exposer les erreurs internes
  formatError: (formattedError, error) => {
    // Logger l'erreur complète
    logger.error({ event: 'GRAPHQL_ERROR', error: error.message });

    // Renvoyer une erreur nettoyée
    if (process.env.NODE_ENV === 'production') {
      if (formattedError.extensions?.code === 'INTERNAL_SERVER_ERROR') {
        return { message: 'Erreur interne', extensions: { code: 'INTERNAL_ERROR' } };
      }
    }
    return formattedError;
  },

  // ✅ Limiter la taille des requêtes
  plugins: [{
    requestDidStart: async () => ({
      didResolveOperation: async (requestContext) => {
        const query = requestContext.request.query || '';
        if (query.length > 10000) {
          throw new Error('Requête trop longue');
        }
      },
    }),
  }],
});
```

### Autorisation dans les resolvers

```javascript
const resolvers = {
  Query: {
    // ✅ Vérification d'autorisation dans chaque resolver
    user: async (_, { id }, context) => {
      if (!context.user) {
        throw new AuthenticationError('Non authentifié');
      }

      // Un utilisateur ne peut voir que son propre profil (sauf admin)
      if (id !== context.user.id && !context.user.roles.includes('admin')) {
        throw new ForbiddenError('Accès refusé');
      }

      return await User.findByPk(id, {
        attributes: ['id', 'name', 'email'], // Projection
      });
    },

    users: async (_, { limit = 20, offset = 0 }, context) => {
      if (!context.user?.roles.includes('admin')) {
        throw new ForbiddenError('Accès réservé aux administrateurs');
      }

      // ✅ Pagination obligatoire
      const safeLimit = Math.min(Math.max(1, limit), 100);
      const safeOffset = Math.max(0, offset);

      return await User.findAll({
        attributes: ['id', 'name', 'email'],
        limit: safeLimit,
        offset: safeOffset,
      });
    },
  },
};
```

---

## API Key Management

```javascript
const crypto = require('crypto');

// ✅ Génération d'API keys sécurisée
function generateApiKey() {
  const prefix = 'sk_live_'; // Préfixe identifiable
  const key = crypto.randomBytes(32).toString('base64url');
  return `${prefix}${key}`;
}

// ✅ Stockage : ne stocker que le hash de la clé
async function createApiKey(userId, name) {
  const apiKey = generateApiKey();
  const hash = crypto.createHash('sha256').update(apiKey).digest('hex');

  await db.apiKeys.create({
    userId,
    name,
    keyHash: hash,
    prefix: apiKey.substring(0, 12), // Pour identifier la clé
    permissions: ['read'],
    expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 an
    createdAt: new Date(),
  });

  // ✅ Retourner la clé complète UNIQUEMENT à la création
  return {
    apiKey, // Visible uniquement ici, jamais réaffichée
    prefix: apiKey.substring(0, 12),
    expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  };
}

// ✅ Validation d'API key
async function validateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey) {
    return res.status(401).json({ error: 'API key requise' });
  }

  const hash = crypto.createHash('sha256').update(apiKey).digest('hex');
  const keyRecord = await db.apiKeys.findOne({
    where: {
      keyHash: hash,
      expiresAt: { [Op.gt]: new Date() },
      revokedAt: null,
    },
  });

  if (!keyRecord) {
    return res.status(401).json({ error: 'API key invalide ou expirée' });
  }

  // Logger l'utilisation
  await keyRecord.update({ lastUsedAt: new Date() });

  req.apiKeyUser = {
    userId: keyRecord.userId,
    permissions: keyRecord.permissions,
  };
  next();
}
```

---

## Idempotence

```javascript
// ✅ Clé d'idempotence pour les opérations critiques (paiements, etc.)
async function idempotencyMiddleware(req, res, next) {
  const idempotencyKey = req.headers['idempotency-key'];

  if (!idempotencyKey) {
    return res.status(400).json({ error: 'Header Idempotency-Key requis' });
  }

  // Vérifier si la requête a déjà été traitée
  const existing = await redis.get(`idempotency:${idempotencyKey}`);
  if (existing) {
    const cached = JSON.parse(existing);
    return res.status(cached.statusCode).json(cached.body);
  }

  // Intercepter la réponse pour la mettre en cache
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    redis.setex(
      `idempotency:${idempotencyKey}`,
      86400, // 24h
      JSON.stringify({ statusCode: res.statusCode, body })
    );
    return originalJson(body);
  };

  next();
}

router.post('/api/payments', authenticate, idempotencyMiddleware, processPayment);
```

