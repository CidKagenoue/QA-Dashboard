# QA Dashboard

A bare-bones connected full-stack starter app. Every layer talks to the next — Flutter → NestJS → Prisma → PostgreSQL.

## Tech Stack

- **Frontend:** Flutter (web + mobile)
- **Backend:** NestJS (TypeScript)
- **ORM:** Prisma
- **Database:** PostgreSQL

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Node.js 20+](https://nodejs.org/)
- [Docker & Docker Compose](https://docs.docker.com/get-docker/)

## Quick Start

### Option A — Docker (PostgreSQL + backend together)

```bash
docker-compose up -d
```

This starts PostgreSQL on port `5432` and the NestJS backend on port `3000`.

> **Note:** On first run the backend will start, but the database may not have migrations applied yet.
> Run migrations manually after the containers are up:
>
> ```bash
> cd backend
> npm install
> npx prisma migrate dev --name init
> ```

### Option B — Run the backend manually

```bash
cd backend
npm install
cp .env.example .env          # edit DATABASE_URL if needed
npx prisma migrate dev --name init
npm run start:dev
```

### Run the frontend

```bash
cd frontend
flutter pub get
flutter run
```

> For **web** or **iOS simulator**, change `baseUrl` in `frontend/lib/services/api_service.dart` from `http://10.0.2.2:3000/api` to `http://localhost:3000/api`.

## API Endpoints

| Method | Path          | Description                     |
|--------|---------------|---------------------------------|
| GET    | /api/health   | Returns `{ status, timestamp }` |
| GET    | /api/users    | Returns all users from the DB   |

## Notes

This is a **bare-bones starter** — no auth, no complex state management, no extra modules. The team will add everything else incrementally on top of this foundation.
