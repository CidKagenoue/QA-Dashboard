# QA Dashboard - Login System

A full-stack authentication system with:

- **Flutter** app (login interface)
- **NestJS** API (authentication backend)
- **Prisma + PostgreSQL** (database)

## Prerequisites

- Flutter SDK (Dart 3.x)
- Node.js 20+
- npm
- PostgreSQL (local or remote)
- Git

## Project Structure

```
QA-Dashboard/
|-- backend/                     # NestJS API
|   |-- src/                     # Application modules, controllers and services
|   |-- prisma/                  # Prisma schema and migrations
|   |-- scripts/                 # Backend maintenance/import scripts
|   |-- Dockerfile
|   |-- package.json
|   `-- package-lock.json
|-- frontend/                    # Flutter application
|   |-- lib/                     # Dart app source
|   |-- assets/                  # Images and static frontend assets
|   |-- test/                    # Flutter tests
|   |-- web/                     # Flutter web shell
|   |-- Dockerfile.frontend
|   `-- pubspec.yaml
|-- build/                       # Deployment and infrastructure config
|   |-- docker-compose.yml
|   `-- traefik/
|-- .github/workflows/           # GitHub Actions deployment workflow
|-- .gitignore
`-- README.md
```

The active application code lives only in `backend/` and `frontend/`. Root-level Flutter output, old backend experiments, local databases, logs, `node_modules`, and generated build artifacts are ignored and should not be committed.

## 1. Backend Setup

### Step 1: Install Dependencies

```bash
cd backend
npm install
```

### Step 2: Configure Environment Variables

The values below are examples only. Do not commit real credentials, passwords, API keys, JWT secrets, or SMTP secrets.
Create or update a local `.env` file in the `backend` directory:

```env
# Database Connection
DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/qa_dashboard?schema=public"

# JWT Configuration
JWT_SECRET="replace-with-a-random-secret-at-least-32-characters"
JWT_ISSUER="qa-login-backend"
JWT_AUDIENCE="qa-dashboard"
JWT_EXPIRES_IN="15m"

# Initial admin account
BOOTSTRAP_ADMIN_EMAIL="admin@example.com"
BOOTSTRAP_ADMIN_PASSWORD="replace-with-a-strong-admin-password"

# Password reset link target
FRONTEND_URL="https://tst.vlotterqa.tech"
PUBLIC_FRONTEND_URL="https://tst.vlotterqa.tech"

# SMTP (required for forgot-password/reset e-mails)
SMTP_HOST="smtp.your-provider.com"
SMTP_PORT="587"
SMTP_SECURE="false"
SMTP_USER="your-smtp-user"
SMTP_PASSWORD="your-smtp-password"
SMTP_FROM="noreply@your-domain.com"
SMTP_IGNORE_TLS_ERRORS="false"
```

For production deployment through GitHub Actions, keep secrets in repository settings instead of any file:

`VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `POSTGRES_PASSWORD`, `JWT_SECRET`, `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_PASSWORD`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`

Optional overrides: `JWT_REFRESH_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `SMTP_SECURE`, `SMTP_IGNORE_TLS_ERRORS`

**Environment Variables Explained:**

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:<password>@localhost:5432/qa_dashboard?schema=public` |
| `JWT_SECRET` | Secret key for JWT signing (use a strong random string) | `replace-with-a-random-secret-at-least-32-characters` |
| `JWT_ISSUER` | JWT issuer claim | `qa-login-backend` |
| `JWT_AUDIENCE` | JWT audience claim | `qa-dashboard` |
| `JWT_EXPIRES_IN` | Access token expiration time | `15m` |
| `BOOTSTRAP_ADMIN_EMAIL` | E-mail address for the initial administrator account | `admin@example.com` |
| `BOOTSTRAP_ADMIN_PASSWORD` | Strong password for the initial administrator account | `replace-with-a-strong-admin-password` |
| `FRONTEND_URL` / `PUBLIC_FRONTEND_URL` | URL used in reset links sent by e-mail | `https://tst.vlotterqa.tech` |
| `SMTP_HOST` | SMTP server hostname | `smtp.your-provider.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_SECURE` | Start with TLS immediately (usually true on port 465) | `false` |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP credentials | `your-smtp-user` / `your-smtp-password` |
| `SMTP_FROM` | Sender e-mail address | `noreply@your-domain.com` |
| `SMTP_IGNORE_TLS_ERRORS` | Ignore bad certs (only for self-signed/broken SMTP TLS) | `false` |

### Step 3: Setup Database

```bash
# Run migrations
npx prisma migrate dev

# Generate Prisma client
npx prisma generate
```

### Step 4: Start Backend

```bash
npm run start:dev
```

This runs Prisma migrations first, then starts the NestJS dev server.

Backend will run on: **`http://localhost:3001`**

## 2. Frontend Setup (Flutter)

Open another terminal at the repository root:

```bash
cd frontend
flutter pub get
flutter run
```

## 3. API Endpoints

### GPP / JAP Excel Import

The JAP & GPP screen now supports importing a workbook like `2021-2026 - GPP + JAP Facilities.xlsx` directly from the GPP tab.

Expected behavior:

- One GPP master plan is created for the workbook.
- Each Excel row becomes one or more yearly JAP entries.
- You can edit JAP rows per year after import, so goal text, risk field, priority, executor, dates, and remarks can differ by year.

Excel columns that are mapped:

- `Jaar`
- `Doelstelling - maatregel`
- `Risicoveld`
- `Prioriteit (tijdsplanning)`
- `Uitvoerder`
- `Middelen : Budget of werkuren`
- `Startdatum`
- `Realisatie`
- `Einddatum`
- `Opmerkingen`

In the app, open **JAP & GPP** and use **Excel import** in the GPP tab.

### Login
```
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}

Response: 200 OK
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjEsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsInR5cGUiOiJhY2Nlc3MiLCJpc3MiOiJxYS1sb2dpbi1iYWNrZW5kIiwiYXVkIjoicWEtZGFzaGJvYXJkIiwiaWF0IjoxNjI3ODk3NjAwLCJleHAiOjE2Mjc4OTgyMDB9.signature",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjEsInR5cGUiOiJyZWZyZXNoIiwic2Vzc2lvbklkIjoiYWJjMTIzIn0.signature",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "User Name"
  }
}
```

**Example Token Payload (decoded):**
```json
{
  "sub": 1,                    // User ID
  "email": "user@example.com",
  "type": "access",
  "iss": "qa-login-backend",   // Issuer
  "aud": "qa-dashboard",       // Audience
  "iat": 1627897600,           // Issued at
  "exp": 1627898200            // Expiration (15 minutes)
}
```

## 4. Login Flow

1. User enters email & password in Flutter app
2. App sends POST request to `/auth/login`
3. Backend validates credentials against database
4. On success: Returns JWT access token + user info
5. App stores token in secure storage
6. Subsequent API requests include token in Authorization header

## 5. API Base URL Configuration

The API base URL is configured in `frontend/lib/services/api_service.dart`:

- **Local development**: `http://localhost:3001`
- **Android Emulator**: `http://10.0.2.2:3001` (use this instead of localhost)
- **Physical device**: Use your machine's local IP address (e.g., `http://192.168.x.x:3001`)

## Common Commands

From `backend` directory:

```bash
# Development
npm run start:dev              # Start dev server with hot reload

# Database
npx prisma migrate dev         # Run migrations with auto-generation
npx prisma migrate deploy      # Run migrations (production)
npx prisma generate            # Generate Prisma client
                                # Open Prisma Studio GUI

# Linting & Formatting
npm run lint                   # Run ESLint
npm run format                 # Format code with Prettier
```

## Database Schema

The system uses the following main tables:

- **User**: Stores user credentials and info
- **RefreshTokenSession**: Manages refresh token lifecycle (for token rotation)

Check `backend/prisma/schema.prisma` for full schema details.

## Troubleshooting

### Database Connection Error
- Ensure PostgreSQL is running
- Verify `DATABASE_URL` in `.env` is correct
- Check username/password credentials

### Flutter App Can't Connect to API
- Local dev: Ensure backend is running on `http://localhost:3001`
- Android Emulator: Use `http://10.0.2.2:3001`
- Physical device: Use local machine IP (e.g., `http://192.168.1.100:3001`)

### JWT Token Issues
- Regenerate `JWT_SECRET` in `.env` if needed
- Ensure `JWT_EXPIRES_IN` is properly formatted (e.g., `15m`, `1h`)

### Reset E-mail Works Locally But Not On VM
- Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` and `SMTP_FROM` in `backend/.env`.
- Verify the VM/container can reach your SMTP provider on the configured SMTP port.
- Set `FRONTEND_URL` or `PUBLIC_FRONTEND_URL` to your public web URL so reset links do not point to localhost.

## Domain And HTTPS (Docker)

This project is configured for:

- Domain: `tst.vlotterqa.tech` and `www.tst.vlotterqa.tech`
- HTTP on port `80`
- HTTPS on port `443` (enabled automatically when certificates are available)

### 1. DNS Records

In your domain provider panel, create:

- `A` record: `@` -> your server IP
- `A` record: `www` -> your server IP

### 2. Start Services

```bash
docker compose -f build/docker-compose.yml up -d
```

If no cert is present yet, frontend starts in HTTP mode automatically.

### 3. Issue Let's Encrypt Certificate

```bash
mkdir -p certbot/conf certbot/www

docker run --rm \
  -v "$PWD/certbot/conf:/etc/letsencrypt" \
  -v "$PWD/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --webroot \
  -w /var/www/certbot \
  -d tst.vlotterqa.tech -d www.tst.vlotterqa.tech \
  --email your-email@example.com --agree-tos --no-eff-email
```

Then restart frontend to switch to HTTPS config:

```bash
docker compose -f build/docker-compose.yml restart frontend
```

### 4. Renew Certificate

Run this periodically (cron or systemd timer):

```bash
docker run --rm \
  -v "$PWD/certbot/conf:/etc/letsencrypt" \
  -v "$PWD/certbot/www:/var/www/certbot" \
  certbot/certbot renew

docker compose -f build/docker-compose.yml restart frontend
```

## Environment Notes

- This is a **login-only** system (no registration endpoint)
- Users must be pre-added to the database
- JWT tokens expire based on `JWT_EXPIRES_IN` setting
- Refresh tokens enable obtaining new access tokens without re-login
