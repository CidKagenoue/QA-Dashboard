import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { assertJwtConfiguration } from './auth/jwt.config';
import { assertBootstrapAdminConfiguration } from './auth/admin-bootstrap.config';

async function bootstrap() {
  assertJwtConfiguration();
  assertBootstrapAdminConfiguration();

  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Eén reverse proxy (Traefik) staat voor de API, dus vertrouw één hop.
  // Hierdoor reflecteert req.ip het echte client-IP (uit X-Forwarded-For),
  // wat de rate-limiting per gebruiker laat werken i.p.v. per proxy.
  app.set('trust proxy', 1);

  // Globale input-validatie. `whitelist` stript velden zonder decorator uit de
  // body (voorkomt mass-assignment, bv. een gebruiker die zichzelf isAdmin
  // probeert te zetten). `transform` zet bodies om naar hun DTO-type.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

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

  const isLocalDevOrigin = (origin: string): boolean => {
    try {
      const parsedOrigin = new URL(origin);
      return (
        (parsedOrigin.protocol === 'http:' || parsedOrigin.protocol === 'https:') &&
        (parsedOrigin.hostname === 'localhost' || parsedOrigin.hostname === '127.0.0.1')
      );
    } catch {
      return false;
    }
  };

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, true);
        return;
      }

      const normalizedOrigin = origin.trim().replace(/\/+$/, '');
      callback(null, allowedOrigins.has(normalizedOrigin) || isLocalDevOrigin(normalizedOrigin));
    },
    credentials: true,
  });
  const port = Number(process.env.PORT ?? 3001);
  // Bind to 0.0.0.0 so the server is reachable from other containers
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Server running on http://0.0.0.0:${port}`);
}
bootstrap();