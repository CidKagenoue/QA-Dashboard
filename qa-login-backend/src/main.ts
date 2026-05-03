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
  
  // Enable CORS for Flutter app
  app.enableCors({
    origin: true, // Allow all origins in development
    credentials: true,
  });
  const port = Number(process.env.PORT ?? 3001);
  // Mount simple Express routers for JAP/GPP (temporary lightweight implementation)
  const expressApp = app.getHttpAdapter().getInstance();
  const notificationsService = app.get(NotificationService);
  const prismaService = app.get(PrismaService);

  expressApp.use('/jap', createJapRouter(notificationsService, prismaService));
  expressApp.use('/gpp', createGppRouter(notificationsService, prismaService));
  await app.listen(port);
  console.log(`🚀 Server running on http://localhost:${port}`);
}
bootstrap();