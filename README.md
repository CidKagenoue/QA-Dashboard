# QA Dashboard

Full-stack login starter with:

- Flutter app in the repository root
- NestJS API in `qa-login-backend`
- Prisma + PostgreSQL for data storage

## Prerequisites

- Flutter SDK (Dart 3.x)
- Node.js 20+
- npm
- PostgreSQL running locally (or remotely)

## Project Structure

- Flutter frontend: `./`
- Backend API: `./qa-login-backend`
- Prisma schema: `./qa-login-backend/prisma/schema.prisma`

## 1. Start the Backend

Open a terminal in `qa-login-backend`:

```bash
cd qa-login-backend
npm install
```

Make sure your `.env` has a valid PostgreSQL connection string:

```env
DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/qa_dashboard?schema=public"
```

In `qa-login-backend/prisma/schema.prisma`, confirm the datasource includes the URL:

```prisma
datasource db {
	provider = "postgresql"
	url      = env("DATABASE_URL")
}
```

Apply database migrations and generate Prisma client:

```bash
npx prisma migrate dev
npx prisma generate
```

Start the API:

```bash
npm run start:dev
```

Backend runs on:

`http://localhost:3001`

## 2. Start the Flutter App

Open another terminal at the repository root:

```bash
flutter pub get
flutter run
```

## API Base URL Notes

The app currently uses:

`http://localhost:3001`

in `lib/services/api_service.dart`.

If you run on Android emulator, use:

`http://10.0.2.2:3001`

instead of localhost.

## Auth Endpoints

- `POST /auth/login`

## Common Commands

From `qa-login-backend`:

```bash
npm run start:dev
npm run db:migrate
npm run db:push
npm run db:studio
```
