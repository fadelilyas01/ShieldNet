# Patterns Sécurisés Multi-Langages (Python, Java, C#, PHP, Go, Rust) — Référence

Ce document fournit des implémentations de code sécurisé (*Secure-by-Design*) pour les langages et frameworks backend majeurs.

---

## 📋 Table des matières

1. [Python (FastAPI & Django)](#1-python-fastapi--django)
2. [Java & Kotlin (Spring Boot 3 / Spring Security 6)](#2-java--kotlin-spring-boot-3--spring-security-6)
3. [C# (.NET 8+ / ASP.NET Core)](#3-c-net-8--aspnet-core)
4. [PHP (Laravel 10+ / Symfony)](#4-php-laravel-10--symfony)
5. [Go (Gin & net/http)](#5-go-gin--nethttp)
6. [Rust (Axum & Actix-web)](#6-rust-axum--actix-web)

---

## 1. Python (FastAPI & Django)

### FastAPI : Validation Stricte & Authentification JWT

```python
# app/auth.py
from datetime import datetime, timedelta, timezone
import os
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field

router = APIRouter(prefix="/auth", tags=["auth"])

SECRET_KEY = os.environ["JWT_SECRET_KEY"]  # Min 256 bits, depuis env
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15

pwd_context = CryptContext(schemes=["argon2", "bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# Modèle d'entrée validé par Pydantic (Whitelist)
class UserRegisterRequest(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_-]+$")
    password: str = Field(..., min_length=12, max_length=128)

class TokenPayload(BaseModel):
    sub: str
    roles: list[str] = []
    exp: datetime

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identifiants invalides ou token expiré",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        return payload
    except JWTError:
        raise credentials_exception
```

### Django : Durcissement de `settings.py`

```python
# settings.py - Configuration de production durcie
DEBUG = False
ALLOWED_HOSTS = [os.environ["ALLOWED_HOST"]]

# HTTPS & HSTS
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000  # 1 an
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Cookies & XSS
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = False  # True si SPA n'a pas besoin de le lire en JS
SESSION_COOKIE_SAMESITE = 'Strict'
CSRF_COOKIE_SAMESITE = 'Strict'

# Headers du navigateur
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# Protection contre les mass assignments
# Dans les serializers Django REST Framework, toujours spécifier fields explicitement
# fields = ['id', 'username', 'email']  # JAMAIS '__all__'
```

---

## 2. Java & Kotlin (Spring Boot 3 / Spring Security 6)

### Configuration `SecurityFilterChain` & CSRF

```java
// SecurityConfig.java
package com.example.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true) // Active @PreAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // 1. Session Stateless pour API REST JWT
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            // 2. Headers de sécurité renforcés
            .headers(headers -> headers
                .contentTypeOptions(ct -> {})
                .frameOptions(fo -> fo.deny())
                .referrerPolicy(rp -> rp.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true)
                    .maxAgeInSeconds(31536000)
                )
            )
            // 3. Règles d'autorisation granulaires
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/login", "/api/v1/auth/register").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        // Argon2id par défaut (16 bytes salt, 32 bytes hash, 1 thread, 65536 KB, 3 iterations)
        return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    }
}
```

### Validation des Entrées (Jakarta Bean Validation)

```java
// UserRegistrationDto.java
package com.example.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UserRegistrationDto(
    @NotBlank(message = "L'email est requis")
    @Email(message = "Format d'email invalide")
    String email,

    @NotBlank(message = "Le mot de passe est obligatoire")
    @Size(min = 12, max = 128, message = "Le mot de passe doit comporter entre 12 et 128 caractères")
    @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&]).+$",
             message = "Le mot de passe doit contenir majuscule, minuscule, chiffre et caractère spécial")
    String password
) {}
```

---

## 3. C# (.NET 8+ / ASP.NET Core)

### Endpoint Sécurisé (Minimal API) avec FluentValidation

```csharp
// Program.cs
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Configuration JWT sécurisée
var jwtKey = Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? throw new InvalidOperationException("Clé JWT manquante"));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(jwtKey),
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidateAudience = true,
            ValidAudience = builder.Configuration["Jwt:Audience"],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero // Pas de tolérance de dérive temporelle excessive
        };
    });

builder.Services.AddAuthorization(options => {
    options.AddPolicy("RequireAdminRole", policy => policy.RequireRole("Admin"));
});

builder.Services.AddValidatorsFromAssemblyContaining<CreateUserRequestValidator>();

var app = builder.Build();

// Headers de sécurité
app.Use(async (context, next) => {
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("Content-Security-Policy", "default-src 'self'");
    await next();
});

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

// Endpoint typé et validé
app.MapPost("/api/users", async (CreateUserRequest request, IValidator<CreateUserRequest> validator, UserService service) => {
    var validationResult = await validator.ValidateAsync(request);
    if (!validationResult.IsValid) {
        return Results.ValidationProblem(validationResult.ToDictionary());
    }
    var createdUser = await service.CreateUserAsync(request);
    return Results.Created($"/api/users/{createdUser.Id}", createdUser);
}).RequireAuthorization();

app.Run();

// Request Record & Validator
public record CreateUserRequest(string Email, string Username, string Password);

public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest> {
    public CreateUserRequestValidator() {
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(255);
        RuleFor(x => x.Username).NotEmpty().Length(3, 50).Matches(@"^[a-zA-Z0-9_\-]+$");
        RuleFor(x => x.Password).NotEmpty().MinimumLength(12).MaximumLength(128);
    }
}
```

---

## 4. PHP (Laravel 10+ / Symfony)

### Laravel : Form Request Sécurisée & Hashing Robuste

```php
// app/Http/Requests/StoreUserRequest.php
namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreUserRequest extends FormRequest
{
    // Autorisation explicite
    public function authorize(): bool
    {
        return $this->user() && $this->user()->can('create-users');
    }

    // Règles strictes de validation
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email:rfc,dns', 'max:255', 'unique:users,email'],
            'username' => ['required', 'string', 'min:3', 'max:50', 'regex:/^[a-zA-Z0-9_-]+$/', 'unique:users,username'],
            'password' => ['required', 'string', 'min:12', 'max:128', 'uncompromised'], // Vérifie avec HaveIBeenPwned
            'role' => ['required', 'string', 'in:user,manager'], // Whitelist stricte (empêche l'auto-attribution 'admin')
        ];
    }
}
```

### Laravel Controller & Modèle (Protection Mass Assignment)

```php
// app/Models/User.php
class User extends Authenticatable
{
    // ✅ Whitelist stricte des champs assignables (JAMAIS de $guarded = [])
    protected $fillable = [
        'username',
        'email',
        'password',
    ];

    // Cacher les données sensibles lors des sérialisations JSON
    protected $hidden = [
        'password',
        'remember_token',
        'two_factor_secret',
    ];

    protected $casts = [
        'password' => 'hashed', // Hachage automatique avec Argon2id / bcrypt
    ];
}
```

---

## 5. Go (Gin & net/http)

### Handler Sécurisé en Go

```go
package main

import (
	"crypto/subtle"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

var validate = validator.New()

type TransferRequest struct {
	RecipientAccount string  `json:"recipient_account" validate:"required,alphanum,len=24"`
	Amount           float64 `json:"amount" validate:"required,gt=0,lte=50000"`
	Reference        string  `json:"reference" validate:"required,printascii,max=140"`
}

func TransferHandler(c *gin.Context) {
	var req TransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "JSON malformé"})
		return
	}

	if err := validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "Données non conformes"})
		return
	}

	// Éviter les timing attacks lors de la comparaison de tokens ou clés
	userProvidedToken := c.GetHeader("X-Signature")
	expectedToken := "expected_precomputed_hash"
	if subtle.ConstantTimeCompare([]byte(userProvidedToken), []byte(expectedToken)) != 1 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Signature invalide"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "transfert_valide"})
}

func main() {
	router := gin.New()
	router.Use(gin.Recovery())

	// Timeouts stricts du serveur HTTP contre les attaques Slowloris
	server := &http.Server{
		Addr:         ":8443",
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}
	server.ListenAndServeTLS("cert.pem", "key.pem")
}
```

---

## 6. Rust (Axum, SQLx, Zeroize & Tokio)

### Règles Fondamentales de Sécurité Rust
1. **Zéro `unsafe` :** Placer `#![forbid(unsafe_code)]` en haut de `main.rs` ou `lib.rs`.
2. **Zéro `unwrap()` / `expect()` en production :** Un `unwrap()` sur un `None` ou `Err` provoque un *panic* qui tue le thread ou le processus (vulnérabilité de Déni de Service / DoS). Toujours utiliser `?` et des types d'erreurs stricts (`thiserror`).
3. **Protection des Secrets en RAM (`zeroize`) :** Les mots de passe et clés privées restent dans la mémoire vive même après avoir été détruits. La crate `zeroize` écrase la mémoire avec des zéros lors du `Drop`.
4. **Requêtes SQL vérifiées à la compilation (`sqlx`) :** Les macros `query!` et `query_as!` vérifient la syntaxe SQL et les types par rapport à la base de données réelle lors du `cargo build`.

### Exemple Complet : API Axum Sécurisée avec Zeroize, SQLx et Gestion d'Erreurs

```rust
// src/main.rs
#![forbid(unsafe_code)] // Interdiction formelle du code unsafe

use axum::{
    extract::{Json, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::sync::Arc;
use thiserror::Error;
use validator::Validate;
use zeroize::{Zeroize, ZeroizeOnDrop};

// -------------------------------------------------------------
// 1. Structure de Secret avec Effacement Mémoire Automatique (Zeroize)
// -------------------------------------------------------------
#[derive(Deserialize, Validate, Zeroize, ZeroizeOnDrop)]
pub struct RegisterDto {
    #[validate(email(message = "Format d'email invalide"))]
    #[zeroize(skip)] // L'email n'est pas un secret critique
    pub email: String,

    #[validate(length(min = 12, max = 128, message = "Mot de passe trop court ou trop long"))]
    pub password: String, // Sera écrasé par des 0 en mémoire dès la sortie de portée
}

// -------------------------------------------------------------
// 2. Newtype Pattern pour éviter la confusion d'identifiants
// -------------------------------------------------------------
#[derive(Debug, Clone, Copy, Serialize, Deserialize, sqlx::Type)]
#[sqlx(transparent)]
pub struct UserId(pub uuid::Uuid);

// -------------------------------------------------------------
// 3. Gestion Robuste des Erreurs (Anti-Panic & Anti-Information Leakage)
// -------------------------------------------------------------
#[derive(Debug, Error)]
pub enum AppError {
    #[error("Erreur de validation: {0}")]
    Validation(#[from] validator::ValidationErrors),

    #[error("Erreur de base de données")]
    Database(#[from] sqlx::Error),

    #[error("Conflit: ressource déjà existante")]
    Conflict,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, client_message) = match self {
            AppError::Validation(e) => (StatusCode::BAD_REQUEST, e.to_string()),
            AppError::Conflict => (StatusCode::CONFLICT, "Cet utilisateur existe déjà".into()),
            // Masquage systématique des erreurs internes SQL / serveurs
            AppError::Database(ref e) => {
                tracing::error!("Erreur interne base de données: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Une erreur interne est survenue".into())
            }
        };

        (status, Json(serde_json::json!({ "error": client_message }))).into_response()
    }
}

// -------------------------------------------------------------
// 4. Handler Axum avec Requête SQL Paramétrée et Typée
// -------------------------------------------------------------
pub async fn register_user(
    State(pool): State<Arc<PgPool>>,
    Json(payload): Json<RegisterDto>,
) -> Result<(StatusCode, Json<serde_json::Value>), AppError> {
    // A. Validation stricte du format
    payload.validate()?;

    // B. Hachage sécurisé du mot de passe avec Argon2id
    let salt = argon2::password_hash::SaltString::generate(&mut rand::thread_rng());
    let argon2 = argon2::Argon2::default();
    let password_hash = argon2
        .hash_password(payload.password.as_bytes(), &salt)
        .map_err(|_| AppError::Conflict)?
        .to_string();

    let user_id = UserId(uuid::Uuid::new_v4());

    // C. Requête SQLx préparée et compilée
    sqlx::query!(
        r#"
        INSERT INTO users (id, email, password_hash, created_at)
        VALUES ($1, $2, $3, NOW())
        "#,
        user_id.0,
        payload.email,
        password_hash
    )
    .execute(&*pool)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(db_err) if db_err.is_unique_violation() => AppError::Conflict,
        other => AppError::Database(other),
    })?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({ "id": user_id, "status": "compte_créé" })),
    ))
}

pub fn create_app(pool: Arc<PgPool>) -> Router {
    Router::new()
        .route("/api/register", post(register_user))
        .layer(tower_http::limit::RequestBodyLimitLayer::new(1024 * 64)) // Limite de 64 KB anti-DoS
        .with_state(pool)
}
```
