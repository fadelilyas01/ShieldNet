# Patterns Web sécurisés — Référence

Exemples de code sécurisé pour les frameworks web courants.

---

## Authentification

### JWT sécurisé (Node.js / Express)

```javascript
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// Configuration
const JWT_SECRET = process.env.JWT_SECRET; // ≥ 256 bits, stocké dans env
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '7d';

// Génération de tokens
function generateTokens(userId, roles) {
  const accessToken = jwt.sign(
    { sub: userId, roles, type: 'access' },
    JWT_SECRET,
    {
      expiresIn: ACCESS_TOKEN_EXPIRY,
      algorithm: 'HS256',
      issuer: 'your-app',
      audience: 'your-app-api',
    }
  );

  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh', jti: crypto.randomUUID() },
    JWT_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRY, algorithm: 'HS256' }
  );

  return { accessToken, refreshToken };
}

// Middleware de vérification
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requis' });
  }

  try {
    const token = authHeader.slice(7);
    const payload = jwt.verify(token, JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: 'your-app',
      audience: 'your-app-api',
    });

    if (payload.type !== 'access') {
      return res.status(401).json({ error: 'Type de token invalide' });
    }

    req.user = { id: payload.sub, roles: payload.roles };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expiré' });
    }
    return res.status(401).json({ error: 'Token invalide' });
  }
}
```

### Cookies de session sécurisés

```javascript
app.use(session({
  name: '__Host-session', // Préfixe __Host- empêche l'override
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,     // Inaccessible via JavaScript
    secure: true,       // HTTPS uniquement
    sameSite: 'strict', // Protection CSRF
    maxAge: 3600000,    // 1 heure
    path: '/',
    domain: undefined,  // Restreint au domaine courant
  },
  store: new RedisStore({ client: redisClient }), // Stockage serveur
}));
```

---

## Protection CSRF

### Token CSRF (Double Submit Cookie)

```javascript
const csrf = require('csurf');

// Middleware CSRF
const csrfProtection = csrf({
  cookie: {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
  },
});

// Appliquer sur les routes avec mutation
app.post('/api/transfer', csrfProtection, (req, res) => {
  // Le middleware vérifie automatiquement le token
  // ...
});

// Fournir le token au frontend
app.get('/api/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});
```

### SameSite comme défense en profondeur

```javascript
// ✅ SameSite=Strict bloque l'envoi du cookie depuis un site tiers
res.cookie('session', token, {
  sameSite: 'strict',
  httpOnly: true,
  secure: true,
});
```

---

## Validation des entrées

### Schéma de validation (Node.js avec Joi/Zod)

```javascript
const { z } = require('zod');

// Schéma de validation strict
const userSchema = z.object({
  email: z.string()
    .email('Email invalide')
    .max(255)
    .toLowerCase()
    .trim(),
  password: z.string()
    .min(8, 'Minimum 8 caractères')
    .max(128, 'Maximum 128 caractères')
    .regex(/[A-Z]/, 'Au moins une majuscule')
    .regex(/[0-9]/, 'Au moins un chiffre'),
  name: z.string()
    .min(1)
    .max(100)
    .regex(/^[\p{L}\p{N}\s\-'.]+$/u, 'Caractères non autorisés'),
  age: z.number()
    .int()
    .min(13)
    .max(150)
    .optional(),
});

// Middleware de validation
function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(400).json({
        error: 'Données invalides',
        details: result.error.issues.map(i => ({
          field: i.path.join('.'),
          message: i.message,
        })),
      });
    }
    req.validatedBody = result.data;
    next();
  };
}

app.post('/api/users', validate(userSchema), createUser);
```

### Protection XSS (encodage des sorties)

```javascript
const he = require('he'); // HTML entities

// ✅ Encodage contextuel
function encodeForHTML(input) {
  return he.encode(input, { useNamedReferences: true });
}

function encodeForAttribute(input) {
  return he.encode(input, { useNamedReferences: true });
}

function encodeForJS(input) {
  return JSON.stringify(input); // JSON.stringify échappe les caractères dangereux
}

function encodeForURL(input) {
  return encodeURIComponent(input);
}

// Usage dans les templates (la plupart des frameworks modernes encodent par défaut)
// React : encodé automatiquement (sauf dangerouslySetInnerHTML)
// Vue : encodé automatiquement (sauf v-html)
// Angular : encodé automatiquement (sauf bypassSecurityTrust*)
```

---

## Requêtes SQL sécurisées

### ORM avec protection (Prisma)

```javascript
// ✅ BON : Prisma - Requêtes paramétrées par défaut
const user = await prisma.user.findUnique({
  where: { id: parseInt(req.params.id) },
  select: { id: true, name: true, email: true }, // Projection explicite
});

// ✅ BON : Requête brute paramétrée quand nécessaire
const results = await prisma.$queryRaw`
  SELECT id, name FROM users WHERE email = ${email} AND active = ${true}
`;

// ❌ MAUVAIS : Injection possible
const results = await prisma.$queryRawUnsafe(
  `SELECT * FROM users WHERE email = '${email}'`
);
```

### Sequelize

```javascript
// ✅ BON : ORM avec paramètres
const users = await User.findAll({
  where: {
    email: req.body.email,    // Paramétré automatiquement
    status: 'active',
  },
  attributes: ['id', 'name', 'email'], // Limiter les champs
  limit: 50,                            // Pagination obligatoire
  offset: parseInt(req.query.offset) || 0,
});
```

---

## Rate Limiting

```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');

// Rate limiter global
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requêtes par fenêtre
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Trop de requêtes, réessayez plus tard' },
  store: new RedisStore({ sendCommand: (...args) => redisClient.sendCommand(args) }),
});

// Rate limiter strict pour l'authentification
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true, // Ne compte que les échecs
  message: { error: 'Trop de tentatives, réessayez dans 15 minutes' },
});

// Rate limiter pour les API sensibles
const sensitiveLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 heure
  max: 10,
  message: { error: 'Limite atteinte pour cette opération' },
});

app.use('/api/', globalLimiter);
app.post('/auth/login', authLimiter, loginHandler);
app.post('/api/password-reset', sensitiveLimiter, resetHandler);
```

---

## Upload de fichiers sécurisé

```javascript
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

// Configuration sécurisée de multer
const ALLOWED_MIMES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const storage = multer.diskStorage({
  destination: '/app/uploads/temp/',
  filename: (req, file, cb) => {
    // Nom de fichier aléatoire (empêche le path traversal et la prédiction)
    const randomName = crypto.randomBytes(32).toString('hex');
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${randomName}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1, // Un seul fichier à la fois
  },
  fileFilter: (req, file, cb) => {
    // Vérifier le MIME type
    if (!ALLOWED_MIMES.includes(file.mimetype)) {
      return cb(new Error('Type de fichier non autorisé'), false);
    }
    // Vérifier l'extension
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];
    if (!allowedExts.includes(ext)) {
      return cb(new Error('Extension de fichier non autorisée'), false);
    }
    cb(null, true);
  },
});

// ✅ Vérifier aussi le contenu du fichier (magic bytes)
const fileType = require('file-type');

app.post('/api/upload', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Fichier requis' });
  }

  // Double vérification du type réel
  const type = await fileType.fromFile(req.file.path);
  if (!type || !ALLOWED_MIMES.includes(type.mime)) {
    fs.unlinkSync(req.file.path); // Supprimer le fichier suspect
    return res.status(400).json({ error: 'Contenu de fichier invalide' });
  }

  // Traiter le fichier...
});
```

---

## Gestion d'erreurs sécurisée

```javascript
// Middleware de gestion d'erreurs centralisé
app.use((err, req, res, next) => {
  // Logger l'erreur complète en interne
  logger.error({
    timestamp: new Date().toISOString(),
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
    userId: req.user?.id,
  });

  // ✅ Réponse générique au client (pas de stack trace)
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: statusCode === 500
      ? 'Une erreur interne est survenue' // Message générique
      : err.message,                      // Messages d'erreur métier
    // ❌ NE PAS inclure : err.stack, err.sql, req.headers, etc.
  });
});
```

