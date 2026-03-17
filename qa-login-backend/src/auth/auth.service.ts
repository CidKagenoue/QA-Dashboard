import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UserService } from '../user/user.service';
import * as bcrypt from 'bcrypt';
import { createHash, randomUUID } from 'crypto';
import * as jwt from 'jsonwebtoken';
import { JwtPayload } from 'jsonwebtoken';
import { LoginDto, RegisterDto } from './dto/auth.dto';
import {
  getJwtSecret,
  getJwtSignOptions,
  getJwtVerifyOptions,
  getRefreshJwtSecret,
  getRefreshJwtSignOptions,
  getRefreshJwtVerifyOptions,
} from './jwt.config';

type SafeUser = {
  id: number;
  email: string;
  name: string | null;
};

@Injectable()
export class AuthService {
  constructor(
    private userService: UserService,
    private prisma: PrismaService,
  ) {}

  async register(registerDto: RegisterDto) {
    const { email, password, name } = registerDto;

    // Check if user already exists
    const existingUser = await this.userService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('User already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Create user
    const user = await this.userService.create({
      email,
      password: hashedPassword,
      name,
    });

    return this.buildAuthResponse(user);
  }

  async login(loginDto: LoginDto) {
    const { email, password } = loginDto;

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.buildAuthResponse(user);
  }

  async refreshTokens(refreshToken: string) {
    const payload = this.verifyRefreshToken(refreshToken);
    const userId = this.readUserId(payload.sub);
    const sessionId = this.readRefreshSessionId(payload);

    const session = await this.prisma.refreshTokenSession.findUnique({
      where: { id: sessionId },
    });

    if (!session || session.userId !== userId || session.revokedAt) {
      throw new UnauthorizedException('Refresh session is invalid');
    }

    if (session.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException('Refresh token has expired');
    }

    if (session.tokenHash !== this.hashToken(refreshToken)) {
      throw new UnauthorizedException('Refresh token is invalid');
    }

    const user = await this.userService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('User does not exist');
    }

    await this.prisma.refreshTokenSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });

    return this.buildAuthResponse(user);
  }

  async revokeRefreshToken(refreshToken: string) {
    const payload = this.verifyRefreshToken(refreshToken);
    const sessionId = this.readRefreshSessionId(payload);

    const session = await this.prisma.refreshTokenSession.findUnique({
      where: { id: sessionId },
    });

    if (session && !session.revokedAt && session.tokenHash === this.hashToken(refreshToken)) {
      await this.prisma.refreshTokenSession.update({
        where: { id: session.id },
        data: { revokedAt: new Date() },
      });
    }

    return { success: true };
  }

  private generateAccessToken(userId: number, email: string): string {
    try {
      return jwt.sign(
        { sub: userId, email, type: 'access' },
        getJwtSecret(),
        getJwtSignOptions(),
      );
    } catch {
      throw new InternalServerErrorException('JWT configuration is invalid');
    }
  }

  private async generateRefreshToken(userId: number, email: string) {
    const sessionId = randomUUID();

    try {
      const refreshToken = jwt.sign(
        { sub: userId, email, type: 'refresh', jti: sessionId },
        getRefreshJwtSecret(),
        getRefreshJwtSignOptions(),
      );

      const expiresAt = this.readExpiryDate(refreshToken);

      await this.prisma.refreshTokenSession.create({
        data: {
          id: sessionId,
          userId,
          tokenHash: this.hashToken(refreshToken),
          expiresAt,
        },
      });

      return refreshToken;
    } catch {
      throw new InternalServerErrorException('Refresh token configuration is invalid');
    }
  }

  private async buildAuthResponse(user: SafeUser) {
    const accessToken = this.generateAccessToken(user.id, user.email);
    const refreshToken = await this.generateRefreshToken(user.id, user.email);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      token: accessToken,
      accessToken,
      refreshToken,
    };
  }

  private verifyRefreshToken(refreshToken: string): JwtPayload {
    try {
      const payload = jwt.verify(
        refreshToken,
        getRefreshJwtSecret(),
        getRefreshJwtVerifyOptions(),
      ) as JwtPayload | string;

      if (typeof payload === 'string' || payload.type !== 'refresh') {
        throw new UnauthorizedException('Invalid refresh token type');
      }

      return payload;
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private readUserId(sub: JwtPayload['sub']): number {
    const userId = typeof sub === 'number' ? sub : Number(sub);
    if (!Number.isInteger(userId) || userId <= 0) {
      throw new UnauthorizedException('Invalid token subject');
    }

    return userId;
  }

  private readRefreshSessionId(payload: JwtPayload): string {
    if (typeof payload.jti !== 'string' || payload.jti.length === 0) {
      throw new UnauthorizedException('Refresh token session is missing');
    }

    return payload.jti;
  }

  private readExpiryDate(token: string): Date {
    const decoded = jwt.decode(token);
    if (!decoded || typeof decoded === 'string' || typeof decoded.exp !== 'number') {
      throw new InternalServerErrorException('Failed to parse token expiration');
    }

    return new Date(decoded.exp * 1000);
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  async verifyToken(token: string) {
    try {
      const payload = jwt.verify(
        token,
        getJwtSecret(),
        getJwtVerifyOptions(),
      ) as JwtPayload | string;
      if (typeof payload === 'string' || payload.type !== 'access') {
        throw new UnauthorizedException('Invalid token type');
      }

      return payload;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}