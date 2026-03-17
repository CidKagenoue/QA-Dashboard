import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { assertJwtConfiguration } from './auth/jwt.config';

async function bootstrap() {
  assertJwtConfiguration();

  const app = await NestFactory.create(AppModule);
  
  // Enable CORS for Flutter app
  app.enableCors({
    origin: true, // Allow all origins in development
    credentials: true,
  });
  
  await app.listen(3001);
  console.log('🚀 Server running on http://localhost:3001');
}
bootstrap();