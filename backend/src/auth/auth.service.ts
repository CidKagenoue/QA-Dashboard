
import {
  BadRequestException,
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { UserService } from '../user/user.service';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import * as jwt from 'jsonwebtoken';
import {
  ForgotPasswordDto,
  LoginDto,
  RefreshTokenDto,
  ResetPasswordDto,
  VerifyResetTokenDto,
} from './dto/auth.dto';
import {
  getJwtSecret,
  getJwtSignOptions,
  getJwtVerifyOptions,
  getRefreshJwtSecret,
  getRefreshJwtSignOptions,
  getRefreshJwtVerifyOptions,
} from './jwt.config';
import { NotificationService } from '../notifications/notifications.service';
import { NotificationType } from '@prisma/client';
import { assertPasswordPolicy } from '../common/password-policy';
import { getBootstrapAdminCredentials } from './admin-bootstrap.config';

import type { ManagedAccount } from '../user/user.service';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    private readonly userService: UserService,
    private readonly prismaService: PrismaService,
    private readonly emailService: EmailService,
    private readonly notificationsService: NotificationService,
  ) {}

  async onModuleInit() {
    await this.ensureDefaultAdmin();
  }

  async login(loginDto: LoginDto) {
    const email = loginDto.email.trim().toLowerCase();
    const { password } = loginDto;

    const user = await this.userService.findByEmail(email);
    if (!user) {
      throw new UnauthorizedException('Ongeldig e-mailadres of wachtwoord');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Ongeldig e-mailadres of wachtwoord');
    }

    // Fetch managed user with departments
    const managedUser = await this.userService.findManagedById(user.id);
    return this.buildAuthResponse(managedUser);
  }

  async refresh(refreshTokenDto: RefreshTokenDto) {
    const { refreshToken } = refreshTokenDto;
    if (!refreshToken) {
      throw new UnauthorizedException('Refresh token ontbreekt');
    }

    let payload: jwt.JwtPayload;
    try {
      const verified = jwt.verify(
        refreshToken,
        getRefreshJwtSecret(),
        getRefreshJwtVerifyOptions(),
      );

      if (typeof verified === 'string') {
        throw new UnauthorizedException('Ongeldige refresh token');
      }

      payload = verified as jwt.JwtPayload;
    } catch {
      throw new UnauthorizedException('Ongeldige refresh token');
    }

    if (payload.type !== 'refresh' || typeof payload.sid !== 'string') {
      throw new UnauthorizedException('Ongeldig refresh token-type');
    }

    const userId = Number(payload.sub);
    if (!Number.isInteger(userId)) {
      throw new UnauthorizedException('Ongeldige refresh token payload');
    }

    const session = await this.prismaService.refreshTokenSession.findUnique({
      where: { id: payload.sid },
    });

    if (!session || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Refresh sessie is ongeldig of verlopen');
    }

    const incomingHash = this.hashToken(refreshToken);
    if (session.tokenHash !== incomingHash) {
      throw new UnauthorizedException(
        'Refresh token komt niet overeen met sessie',
      );
    }

    const user = await this.userService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('Gebruiker niet gevonden');
    }

    // Fetch managed user with departments
    const managedUser = await this.userService.findManagedById(user.id);

    const nextSessionId = crypto.randomUUID();
    const nextRefreshToken = this.generateRefreshToken(userId, nextSessionId);
    const nextRefreshTokenHash = this.hashToken(nextRefreshToken);
    const nextRefreshTokenExpiresAt = this.getTokenExpiration(nextRefreshToken);

    await this.prismaService.$transaction([
      this.prismaService.refreshTokenSession.update({
        where: { id: session.id },
        data: { revokedAt: new Date() },
      }),
      this.prismaService.refreshTokenSession.create({
        data: {
          id: nextSessionId,
          userId,
          tokenHash: nextRefreshTokenHash,
          expiresAt: nextRefreshTokenExpiresAt,
        },
      }),
    ]);

    return this.buildAuthResponse(managedUser);
  }

  async revokeRefreshToken(refreshToken: string) {
    if (!refreshToken) {
      return { success: true };
    }

    try {
      const verified = jwt.verify(
        refreshToken,
        getRefreshJwtSecret(),
        getRefreshJwtVerifyOptions(),
      );

      if (typeof verified === 'string') {
        return { success: true };
      }

      const payload = verified as jwt.JwtPayload;
      if (payload.type !== 'refresh' || typeof payload.sid !== 'string') {
        return { success: true };
      }

      const session = await this.prismaService.refreshTokenSession.findUnique({
        where: { id: payload.sid },
      });

      if (
        session &&
        !session.revokedAt &&
        session.tokenHash === this.hashToken(refreshToken)
      ) {
        await this.prismaService.refreshTokenSession.update({
          where: { id: session.id },
          data: { revokedAt: new Date() },
        });
      }
    } catch {
      return { success: true };
    }

    return { success: true };
  }

  async forgotPassword(
    forgotPasswordDto: ForgotPasswordDto,
    requestOrigin?: string,
  ) {
    const email = forgotPasswordDto.email.trim().toLowerCase();

    // Altijd exact dezelfde respons, ongeacht of het account bestaat. Zo kan
    // niemand via dit endpoint achterhalen welke e-mailadressen geregistreerd
    // zijn (anti-enumeratie).
    const genericResponse = {
      message:
        'Als er een account bestaat met dit e-mailadres, is er een resetlink verzonden.',
    };

    const user = await this.userService.findByEmail(email);
    if (!user) {
      return genericResponse;
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto
      .createHash('sha256')
      .update(resetToken)
      .digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await this.prismaService.passwordResetToken.create({
      data: {
        userId: user.id,
        token: hashedToken,
        expiresAt,
      },
    });

    const frontendBaseUrl = this.resolveFrontendBaseUrl(requestOrigin);
    const resetLink = `${frontendBaseUrl}/reset-password?token=${resetToken}`;

    try {
      await this.emailService.sendPasswordResetEmail(
        email,
        resetToken,
        resetLink,
      );
    } catch (error) {
      // Server-side loggen, maar geen foutmelding teruggeven die het bestaan
      // van het account zou verraden.
      console.error('Verzenden van reset e-mail is mislukt:', error);
    }

    return genericResponse;
  }

  async verifyResetToken(verifyResetTokenDto: VerifyResetTokenDto) {
    const { token } = verifyResetTokenDto;

    if (!token) {
      throw new BadRequestException('Reset-token is verplicht');
    }

    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

    const resetTokenRecord =
      await this.prismaService.passwordResetToken.findUnique({
        where: { token: hashedToken },
      });

    if (!resetTokenRecord) {
      throw new BadRequestException('Ongeldige reset-token');
    }

    if (new Date() > resetTokenRecord.expiresAt) {
      throw new BadRequestException('Reset-link is verlopen');
    }

    if (resetTokenRecord.usedAt) {
      throw new BadRequestException('Reset-link is al gebruikt');
    }

    return {
      valid: true,
      expiresAt: resetTokenRecord.expiresAt,
    };
  }

  async resetPassword(resetPasswordDto: ResetPasswordDto) {
    const { token, password, confirmPassword } = resetPasswordDto;

    if (password !== confirmPassword) {
      throw new BadRequestException('Wachtwoorden komen niet overeen');
    }

    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

    const resetTokenRecord =
      await this.prismaService.passwordResetToken.findUnique({
        where: { token: hashedToken },
        include: { user: true },
      });

    if (!resetTokenRecord) {
      throw new BadRequestException('Ongeldige reset-token');
    }

    if (new Date() > resetTokenRecord.expiresAt) {
      throw new BadRequestException('Reset-link is verlopen');
    }

    if (resetTokenRecord.usedAt) {
      throw new BadRequestException('Reset-link is al gebruikt');
    }

    assertPasswordPolicy(password, {
      email: resetTokenRecord.user.email,
      name: resetTokenRecord.user.name,
    });

    const hashedPassword = await bcrypt.hash(password, 12);

    await this.prismaService.$transaction([
      this.prismaService.user.update({
        where: { id: resetTokenRecord.userId },
        data: { password: hashedPassword },
      }),
      this.prismaService.passwordResetToken.update({
        where: { id: resetTokenRecord.id },
        data: { usedAt: new Date() },
      }),
    ]);

    await this.notificationsService.notifyUser({
      recipientUserId: resetTokenRecord.userId,
      type: NotificationType.PASSWORD_CHANGED,
      title: 'Wachtwoord gewijzigd',
      body: 'Je wachtwoord werd gewijzigd via de reset-flow.',
      metadata: {
        source: 'reset-password',
      },
    });

    return {
      message:
        'Wachtwoord is succesvol gewijzigd. Je kunt nu inloggen met je nieuwe wachtwoord.',
    };
  }


  async changePassword(
    userId: number,
    currentPassword: string,
    newPassword: string,
    confirmNewPassword: string
    ) {
      const user = await this.userService.findById(userId);
      if (!user) throw new UnauthorizedException('Gebruiker niet gevonden');

      const valid = await bcrypt.compare(currentPassword, user.password);
      if (!valid) throw new UnauthorizedException('Huidig wachtwoord klopt niet');

      if (newPassword !== confirmNewPassword) {
        throw new BadRequestException('Wachtwoorden komen niet overeen');
      }

      assertPasswordPolicy(newPassword, {
        email: user.email,
        name: user.name,
      });

      const hashed = await bcrypt.hash(newPassword, 12);

      await this.prismaService.user.update({
        where: { id: userId },
        data: { password: hashed },
      });

      await this.notificationsService.notifyUser({
        recipientUserId: userId,
        type: NotificationType.PASSWORD_CHANGED,
        title: 'Wachtwoord gewijzigd',
        body: 'Je wachtwoord werd gewijzigd via accountinstellingen.',
        metadata: {
          source: 'change-password',
        },
      });

      return { message: 'Wachtwoord succesvol gewijzigd' };
  }

  private async buildAuthResponse(user: ManagedAccount) {
    const tokens = await this.generateTokenPair(user.id, user.email);

    // Map departments to [{id, name}, ...]
    const mappedDepartments = Array.isArray(user.departments)
      ? user.departments.map((d: any) => d.department)
      : [];

    const access = {
      basis: user.basisAccess,
      whsTours: user.whsToursAccess,
      ova: user.ovaAccess,
      japGpp: user.japGppAccess,
      maintenanceInspections: user.maintenanceInspectionsAccess,
    };

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        isAdmin: user.isAdmin,
        departments: mappedDepartments,
        access,
        hasAnyAccess: user.isAdmin || Object.values(access).some(Boolean),
        profileImage: user.profileImage,
      },
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    };
  }

  private generateAccessToken(userId: number, email: string): string {
    return jwt.sign(
      { sub: userId, email, type: 'access' },
      getJwtSecret(),
      getJwtSignOptions(),
    );
  }

  private generateRefreshToken(userId: number, sessionId: string): string {
    return jwt.sign(
      { sub: userId, type: 'refresh', sid: sessionId },
      getRefreshJwtSecret(),
      getRefreshJwtSignOptions(),
    );
  }

  private async generateTokenPair(userId: number, email: string) {
    const accessToken = this.generateAccessToken(userId, email);

    const sessionId = crypto.randomUUID();
    const refreshToken = this.generateRefreshToken(userId, sessionId);
    const refreshTokenHash = this.hashToken(refreshToken);
    const refreshTokenExpiresAt = this.getTokenExpiration(refreshToken);

    await this.prismaService.refreshTokenSession.create({
      data: {
        id: sessionId,
        userId,
        tokenHash: refreshTokenHash,
        expiresAt: refreshTokenExpiresAt,
      },
    });

    return {
      accessToken,
      refreshToken,
    };
  }

  private hashToken(rawToken: string): string {
    return crypto.createHash('sha256').update(rawToken).digest('hex');
  }

  private getTokenExpiration(token: string): Date {
    const payload = jwt.decode(token) as jwt.JwtPayload | null;
    if (!payload?.exp) {
      throw new BadRequestException('Kan token expiratie niet bepalen');
    }

    return new Date(payload.exp * 1000);
  }

  async verifyToken(token: string) {
    try {
      return jwt.verify(token, getJwtSecret(), getJwtVerifyOptions());
    } catch {
      throw new UnauthorizedException('Ongeldige token');
    }
  }

  private async ensureDefaultAdmin() {
    const { email, password } = getBootstrapAdminCredentials();

    const existingAdmin = await this.userService.findByEmail(email);
    if (existingAdmin) {
      if (!existingAdmin.isAdmin) {
        await this.userService.update(existingAdmin.id, {
          isAdmin: true,
        });
      }
      return;
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    await this.userService.create({
      email,
      password: hashedPassword,
      name: 'Administrator',
      isAdmin: true,
    });
  }

  private resolveFrontendBaseUrl(requestOrigin?: string): string {
    const configuredUrl =
      process.env.PUBLIC_FRONTEND_URL || process.env.FRONTEND_URL || 'https://tst.vlotterqa.tech';
    const baseUrl = requestOrigin?.trim() || configuredUrl.trim();

    return baseUrl.replace(/\/+$/, '');
  }
}
