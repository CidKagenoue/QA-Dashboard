# QA Dashboard

QA Dashboard is a Flutter web application for Vlotter that centralizes quality and safety workflows:

- account management with module-specific access rights;
- OVA tickets, cause analysis and follow-up actions;
- JAP/GPP planning, comments, export and Excel import;
- maintenance inspections and due-date monitoring;
- in-app and optional e-mail notifications;
- WHS Tours reports from a separately deployed backend.

The application consists of a Flutter frontend, a NestJS API, PostgreSQL with Prisma ORM, and a Docker deployment behind Traefik.

## Prerequisites

- Flutter SDK with Dart 3.x
- Node.js 20+
- npm
- PostgreSQL for local development
- Git
- Docker Engine and Docker Compose for containerized deployment

## Project Structure

```text
QA-Dashboard/
|-- backend/                     # NestJS API
|   |-- prisma/                  # Prisma schema and active migrations
|   |-- scripts/                 # Backend maintenance and import scripts
|   |-- src/                     # Application modules, controllers and services
|   |-- .env.example
|   |-- Dockerfile
|   `-- package.json
|-- frontend/                    # Flutter web application
|   |-- assets/
|   |-- lib/
|   |-- test/
|   |-- web/
|   |-- Dockerfile.frontend
|   `-- pubspec.yaml
|-- build/                       # Docker Compose and Traefik configuration
|   |-- docker-compose.yml
|   `-- traefik/
|-- .github/workflows/           # CI and deployment workflows
`-- README.md
```

The active application code lives in `backend/` and `frontend/`. Generated output, local databases, logs, `node_modules`, `.env` files and build artifacts must not be committed.

## Local Setup

### 1. Configure PostgreSQL

Create an empty PostgreSQL database. The examples use `qa_login_backend`.

### 2. Configure the backend

```bash
cd backend
npm install
```

Copy `backend/.env.example` to `backend/.env` and replace the example values:

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/qa_login_backend?schema=public"

# JWT
JWT_SECRET="replace-with-a-random-secret-at-least-32-characters"
JWT_REFRESH_SECRET="replace-with-a-different-random-secret-at-least-32-characters"
JWT_ISSUER="qa-login-backend"
JWT_AUDIENCE="qa-dashboard"
JWT_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"

# Initial admin account
BOOTSTRAP_ADMIN_EMAIL="admin@example.com"
BOOTSTRAP_ADMIN_PASSWORD="ChangeMe-Strong!23"

# Frontend URLs used for CORS and password-reset links
FRONTEND_URL="http://localhost:3000"
PUBLIC_FRONTEND_URL="http://localhost:3000"

# SMTP: optional during development, required to send e-mails
SMTP_HOST=""
SMTP_PORT="587"
SMTP_SECURE="false"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_FROM="noreply@qa-dashboard.local"
SMTP_IGNORE_TLS_ERRORS="false"
```

Important:

- Never commit real credentials or secrets.
- `JWT_SECRET` must contain at least 32 characters.
- Use a separate `JWT_REFRESH_SECRET` outside local experiments.
- `BOOTSTRAP_ADMIN_PASSWORD` must contain at least 10 characters, including uppercase, lowercase, numeric and special characters.
- SMTP can remain empty during development. Password-reset and notification e-mails require valid SMTP settings.

### 3. Initialize and start the backend

```bash
cd backend
npx prisma migrate dev
npx prisma generate
npm run start:dev
```

`npm run start:dev` deploys existing Prisma migrations before starting the NestJS development server.

Backend URL: `http://localhost:3001`

### 4. Start the frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Flutter usually starts the local web application on a URL such as `http://localhost:3000`. Use the URL shown by Flutter if a different port is selected.

## API Base URL

The frontend resolves the backend URL in `frontend/lib/services/api_client.dart`.

| Environment | Default URL |
|-------------|-------------|
| Production release | `https://tst.vlotterqa.tech` |
| Local web development | `http://localhost:3001` |
| Android emulator | `http://10.0.2.2:3001` |
| Other local platforms | `http://localhost:3001` |

Override the URL at build or run time when needed:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
flutter build web --release --dart-define=API_BASE_URL=https://tst.vlotterqa.tech
```

## Authentication

### Login

```http
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "your-password"
}
```

The response contains:

- `accessToken` and compatibility alias `token`;
- `refreshToken`;
- the authenticated user, departments and module access rights.

### Token lifecycle

- Access tokens expire after `JWT_EXPIRES_IN` (`15m` by default).
- Refresh tokens expire after `JWT_REFRESH_EXPIRES_IN` (`7d` by default).
- Refresh tokens are stored server-side as hashed sessions and rotated on refresh.
- Logout revokes the submitted refresh-token session.
- The Flutter web client stores tokens through `SharedPreferences`, which maps to browser storage on web. This is practical for the current SPA but remains readable by JavaScript. See `SECURITY.md` for the documented trade-off and stronger cookie-based alternative.

### Authentication endpoints

| Method | Route | Purpose |
|--------|-------|---------|
| `POST` | `/auth/login` | Log in |
| `POST` | `/auth/refresh` | Rotate refresh token and obtain new tokens |
| `POST` | `/auth/logout` | Revoke refresh-token session |
| `POST` | `/auth/forgot-password` | Request password-reset link |
| `POST` | `/auth/verify-reset-token` | Verify password-reset token |
| `POST` | `/auth/reset-password` | Reset password |
| `POST` | `/auth/change-password` | Change password while authenticated |

## Main API Modules

All application routes are protected by JWT authentication unless explicitly marked public. Additional guards enforce admin or module-specific access where required.

| Module | Route prefix | Purpose |
|--------|--------------|---------|
| Accounts | `/accounts` | Admin-only account and access-right management |
| Users | `/users` | User profiles and departments |
| Departments | `/departments` | Admin-only department management |
| Branches | `/branches` | Admin-only branch management |
| OVA | `/ova` | Tickets, form data and follow-up actions |
| JAP | `/jap` | JAP entries and recent comments |
| GPP | `/gpp` | GPP entries, comments and workbook import |
| Domains | `/domain` | JAP/GPP domain values |
| Executors | `/executor` | JAP/GPP executor values |
| Maintenance | `/maintenance-inspections` | Inspections, form data and upcoming due dates |
| Notifications | `/notifications` | Notification list, unread count and read status |
| Notification settings | `/notification-settings` | Per-user notification preferences |

## JAP/GPP Excel Import

The GPP tab supports importing `.xlsx` and `.csv` files through:

```http
POST /gpp/import-excel
```

The upload is limited to one file with a maximum size of 10 MB. Legacy `.xls` files are rejected after upload; convert them to `.xlsx`.

Expected behavior:

- The importer reads the GPP worksheet from an Excel workbook, or delimited rows from a CSV file.
- Every valid source row with a goal measure becomes one GPP entry.
- Existing GPP entries are cleared by default. Send `clearExisting=false` to preserve them.
- Domains and executor values are added when needed.
- JAP rows for a selected year can be derived from GPP ranges during reporting and export. The import does not persist separate editable JAP rows for every year.

Mapped columns:

- `Jaar`
- `Doelstelling - maatregel`
- `Domein`
- `Risicoveld`
- `Prioriteit (tijdsplanning)`
- `Uitvoerder`
- `Middelen : Budget of werkuren`
- `Startdatum`
- `Realisatie`
- `Einddatum`
- `Opmerkingen`

For a command-line bulk replacement import, run:

```bash
cd backend
npm run import:japgpp -- ../path/to/file.xlsx
```

The command-line script supports `.xlsx`, `.csv`, `.tsv` and `.txt` input and replaces all existing JAP/GPP rows.

## WHS Tours Integration

WHS Tours is a separate application and backend. QA Dashboard reads WHS reports through selected `/api/*` routes, including `/api/rapport`.

In the test deployment, Traefik forwards these paths to:

```text
http://qa-whs-backend:8080
```

The `qa-whs-backend` service is not created by this repository's Docker Compose file. It must already be available on the shared Docker network or the Traefik target must be adjusted for the environment.

## Database

PostgreSQL is accessed through Prisma ORM. The schema is defined in:

```text
backend/prisma/schema.prisma
```

The current schema contains these main groups:

- users, refresh-token sessions and password-reset tokens;
- departments, branches and link tables;
- OVA tickets, follow-up actions and external contacts;
- maintenance inspections and branch links;
- notifications and notification settings;
- JAP/GPP entries, domains, comments and executors.

Useful commands from `backend/`:

```bash
npx prisma migrate dev         # Create and apply development migration
npx prisma migrate deploy      # Apply existing migrations
npx prisma generate            # Generate Prisma Client
npx prisma studio              # Open Prisma Studio
```

## Docker Deployment

The deployment stack is defined in `build/docker-compose.yml` and contains:

- `traefik`: reverse proxy, HTTPS redirect and Let's Encrypt ACME certificates;
- `frontend`: Nginx serving the Flutter web build;
- `backend`: NestJS API;
- `db`: PostgreSQL 16 with persistent `qa_db_data` volume.

The separately deployed WHS backend is reached through Traefik but is not part of this Compose stack.

### Required runtime variables

The deployment workflow injects runtime variables from GitHub Actions secrets. Important values include:

```text
VPS_HOST
VPS_USER
VPS_SSH_KEY
POSTGRES_PASSWORD
JWT_SECRET
JWT_REFRESH_SECRET
BOOTSTRAP_ADMIN_EMAIL
BOOTSTRAP_ADMIN_PASSWORD
SMTP_HOST
SMTP_PORT
SMTP_USER
SMTP_PASSWORD
SMTP_FROM
```

Optional overrides include:

```text
VPS_PORT
JWT_ISSUER
JWT_AUDIENCE
JWT_EXPIRES_IN
JWT_REFRESH_EXPIRES_IN
SMTP_SECURE
SMTP_IGNORE_TLS_ERRORS
```

### Start the stack manually

Run this from the repository root after exporting the required environment variables:

```bash
docker compose -f build/docker-compose.yml up -d --build
```

### Domain and HTTPS

The test deployment uses:

- `tst.vlotterqa.tech`
- `www.tst.vlotterqa.tech`
- `traefik.tst.vlotterqa.tech` for the protected Traefik dashboard

Configure DNS records for `tst`, `www.tst` and `traefik.tst` to point to the server IP when managing the `vlotterqa.tech` DNS zone.

Traefik redirects HTTP traffic on port `80` to HTTPS on port `443` and automatically requests and renews certificates through Let's Encrypt ACME. No manual Certbot step is required.

## CI/CD

### Continuous integration

`.github/workflows/ci.yml` installs backend dependencies and runs the Jest test suite for pushes and pull requests targeting `main` or `master`.

### Deployment

`.github/workflows/deploy.yml` deploys pushes to `main` and `Build`:

1. connect to the VPS through SSH;
2. fetch and reset to the pushed branch;
3. rebuild and restart the Docker Compose stack;
4. wait for the frontend and backend healthchecks.

The backend container applies Prisma migrations before starting the NestJS process.

## Common Backend Commands

Run commands from `backend/`:

```bash
npm run start:dev              # Start development server with hot reload
npm run build                  # Build NestJS application
npm run format                 # Format backend TypeScript
npm test                       # Run Jest tests
npm run test:ci                # Run Jest tests serially
npm run db:studio              # Open Prisma Studio
```

## Troubleshooting

### Backend startup fails

- Verify that PostgreSQL is running and `DATABASE_URL` uses the correct database name.
- Set `JWT_SECRET`, `JWT_REFRESH_SECRET`, `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD`.
- Ensure the bootstrap-admin password satisfies the password policy.

### Flutter app cannot connect to the API

- Ensure the backend is available on `http://localhost:3001`.
- Review `frontend/lib/services/api_client.dart`.
- Pass `--dart-define=API_BASE_URL=...` when using a custom URL.
- Android emulators use `http://10.0.2.2:3001` by default.

### Reset e-mail is not sent

- Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` and `SMTP_FROM`.
- Confirm that the runtime environment can reach the SMTP provider.
- For Gmail SMTP, use an App Password instead of the normal account password.
- Set `FRONTEND_URL` or `PUBLIC_FRONTEND_URL` so reset links point to the correct frontend.

### WHS reports cannot be loaded

- Confirm that the separately deployed `qa-whs-backend` is running.
- Confirm that it is reachable from Traefik as `http://qa-whs-backend:8080`.
- Review the WHS path rules in `build/traefik/traefik-dynamic.yml`.
