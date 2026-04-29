import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { assertJwtConfiguration } from './auth/jwt.config';
import japRouter from './routes/jap';
import * as express from 'express';
import gppRouter from './routes/gpp';

async function bootstrap() {
  assertJwtConfiguration();

  const app = await NestFactory.create(AppModule);
  
  // Enable CORS for Flutter app
  app.enableCors({
    origin: true, // Allow all origins in development
    credentials: true,
  });
  
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  
  app.use('/jap', japRouter);
  app.use('/gpp', gppRouter);
  
  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);
  console.log(`🚀 Server running on http://localhost:${port}`);
}
bootstrap();