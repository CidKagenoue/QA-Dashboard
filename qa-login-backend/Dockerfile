FROM node:20-alpine

WORKDIR /app

# 1) Install deps, but do NOT run prepare/postinstall yet
COPY package*.json ./
RUN npm ci --legacy-peer-deps --ignore-scripts

# 2) Copy source (includes prisma/schema.prisma)
COPY . .

# 3) Now prisma schema exists, generate client
RUN npx prisma generate

# 4) Build NestJS 
RUN npm run build
RUN echo "=== Checking dist directory ===" && ls -laR dist/ || echo "ERROR: dist directory not found!"

EXPOSE 3001

CMD ["sh", "-c", "npx prisma migrate deploy && npm run start:prod"]