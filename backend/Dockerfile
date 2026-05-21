FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps --ignore-scripts

COPY prisma ./prisma
RUN ./node_modules/.bin/prisma generate

COPY . .
RUN npm run build

EXPOSE 3001

CMD ["sh", "-c", "if [ \"$AUTO_RESET_DB\" = \"true\" ]; then ./node_modules/.bin/prisma migrate reset --force --skip-seed; else ./node_modules/.bin/prisma migrate deploy; fi && node dist/main"]