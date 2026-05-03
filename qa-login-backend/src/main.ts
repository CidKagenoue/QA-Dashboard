import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { assertJwtConfiguration } from './auth/jwt.config';
import japRouter from './routes/jap';
import gppRouter from './routes/gpp';

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
  expressApp.use('/jap', japRouter);
  expressApp.use('/gpp', gppRouter);
  await app.listen(port);
  console.log(`🚀 Server running on http://localhost:${port}`);
}
bootstrap();