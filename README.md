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
qa_dashboard/
├── lib/                          # Flutter frontend
│   ├── screens/
│   │   └── login_screen.dart    # Login UI
│   └── services/
│       ├── api_service.dart     # API communication
│       └── auth_service.dart    # Auth logic
├── qa-login-backend/            # NestJS backend
│   ├── src/
│   │   ├── auth/               # Auth controllers & services
│   │   ├── user/               # User services
│   │   └── prisma/             # Database service
│   ├── prisma/
│   │   ├── schema.prisma       # Database schema
│   │   └── migrations/         # Migration files
│   └── .env                    # Environment variables
└── README.md
```

## 1. Backend Setup

### Step 1: Install Dependencies

```bash
cd qa-login-backend
npm install
```

### Step 2: Configure Environment Variables

Create or update `.env` file in the `qa-login-backend` directory:

```env
# Database Connection
DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/qa_dashboard?schema=public"

# JWT Configuration
JWT_SECRET="8e7c0bf3c75692835fe967af1db691c4f8a7e603b34a1d9426c1ef577c8702aa"
JWT_ISSUER="qa-login-backend"
JWT_AUDIENCE="qa-dashboard"
JWT_EXPIRES_IN="15m"
```

**Environment Variables Explained:**

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:root@localhost:5432/qa_dashboard?schema=public` |
| `JWT_SECRET` | Secret key for JWT signing (use a strong random string) | `8e7c0bf3c75692835fe967af1db691c4f8a7e603b34a1d9426c1ef577c8702aa` |
| `JWT_ISSUER` | JWT issuer claim | `qa-login-backend` |
| `JWT_AUDIENCE` | JWT audience claim | `qa-dashboard` |
| `JWT_EXPIRES_IN` | Access token expiration time | `15m` |

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

Backend will run on: **`http://localhost:3001`**

## 2. Frontend Setup (Flutter)

Open another terminal at the repository root:

```bash
flutter pub get
flutter run
```

## 3. API Endpoints

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

The API base URL is configured in `lib/services/api_service.dart`:

- **Local development**: `http://localhost:3001`
- **Android Emulator**: `http://10.0.2.2:3001` (use this instead of localhost)
- **Physical device**: Use your machine's local IP address (e.g., `http://192.168.x.x:3001`)

## Common Commands

From `qa-login-backend` directory:

```bash
# Development
npm run start:dev              # Start dev server with hot reload

# Database
npx prisma migrate dev         # Run migrations with auto-generation
npx prisma migrate deploy      # Run migrations (production)
npx prisma generate            # Generate Prisma client
npx prisma studio              # Open Prisma Studio GUI

# Linting & Formatting
npm run lint                   # Run ESLint
npm run format                 # Format code with Prettier
```

## Database Schema

The system uses the following main tables:

- **User**: Stores user credentials and info
- **RefreshTokenSession**: Manages refresh token lifecycle (for token rotation)

Check `qa-login-backend/prisma/schema.prisma` for full schema details.

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

## Environment Notes

- This is a **login-only** system (no registration endpoint)
- Users must be pre-added to the database
- JWT tokens expire based on `JWT_EXPIRES_IN` setting
- Refresh tokens enable obtaining new access tokens without re-login
