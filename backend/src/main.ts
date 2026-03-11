import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  // Allow all origins for local development. Restrict this in production.
  app.enableCors();
  await app.listen(3000);
}
bootstrap();
