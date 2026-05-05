FROM node:20-alpine

WORKDIR /app

# 1) Copy package files FIRST to leverage Docker layer caching
COPY package*.json ./

# 2) Install dependencies with optimizations
RUN npm ci --legacy-peer-deps --ignore-scripts --no-optional

# 3) Copy Prisma schema
COPY prisma ./prisma

# 4) Generate Prisma client
RUN npx prisma generate

# 5) Copy source code
COPY . .

# 6) Build NestJS application
RUN npm run build

# 7) Verify build
RUN echo "=== Checking dist directory ===" && ls -laR dist/ || echo "ERROR: dist directory not found!"

EXPOSE 3001

# Use exec form for proper signal handling
CMD ["sh", "-c", "if [ \"$AUTO_RESET_DB\" = \"true\" ]; then npx prisma migrate reset --force --skip-seed; else npx prisma migrate deploy; fi && npm run start:prod"]