import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtPayload } from 'jsonwebtoken';
import * as jwt from 'jsonwebtoken';
import { getJwtSecret, getJwtVerifyOptions } from './jwt.config';
import { IS_PUBLIC_KEY } from './public.decorator';

export interface AuthenticatedRequest {
  headers: {
    authorization?: string | string[];
  };
  user?: string | JwtPayload;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractBearerToken(request.headers.authorization);

    if (!token) {
      throw new UnauthorizedException('Authorization-header ontbreekt of is ongeldig');
    }

    try {
      const payload = jwt.verify(
        token,
        getJwtSecret(),
        getJwtVerifyOptions(),
      ) as JwtPayload | string;
      if (typeof payload === 'string' || payload.type !== 'access') {
        throw new UnauthorizedException('Ongeldig token-type');
      }

      request.user = payload;
      return true;
    } catch {
      throw new UnauthorizedException('Ongeldige token');
    }
  }

  private extractBearerToken(header?: string | string[]): string | null {
    if (!header || Array.isArray(header)) {
      return null;
    }

    const [scheme, token] = header.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      return null;
    }

    return token.trim();
  }
}