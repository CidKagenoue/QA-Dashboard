import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { assertJwtConfiguration } from './auth/jwt.config';
import createJapRouter from './routes/jap';
import createGppRouter from './routes/gpp';
import { NotificationService } from './notifications/notifications.service';
import { PrismaService } from './prisma/prisma.service';

async function bootstrap() {
  assertJwtConfiguration();

  const app = await NestFactory.create(AppModule);

  const allowedOrigins = new Set(
    [
      process.env.PUBLIC_FRONTEND_URL,
      process.env.FRONTEND_URL,
      'https://tst.vlotterqa.tech',
      'https://www.tst.vlotterqa.tech',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
    ]
      .map((origin) => origin?.trim().replace(/\/+$/, ''))
      .filter((origin): origin is string => Boolean(origin)),
  );

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, true);
        return;
      }

      const normalizedOrigin = origin.trim().replace(/\/+$/, '');
      callback(null, allowedOrigins.has(normalizedOrigin));
    },
    credentials: true,
  });
  const port = Number(process.env.PORT ?? 3001);
  // Mount simple Express routers for JAP/GPP (temporary lightweight implementation)
  const expressApp = app.getHttpAdapter().getInstance();
  const notificationsService = app.get(NotificationService);
  const prismaService = app.get(PrismaService);
  expressApp.use(require('express').json());

  expressApp.use('/jap', createJapRouter(notificationsService, prismaService));
  expressApp.use('/gpp', createGppRouter(notificationsService, prismaService));
  // Bind to 0.0.0.0 so the server is reachable from other containers
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Server running on http://0.0.0.0:${port}`);
}
bootstrap();