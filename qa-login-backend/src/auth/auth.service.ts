import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UserService } from '../user/user.service';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { LoginDto, RegisterDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(private userService: UserService) {}

  async register(registerDto: RegisterDto) {
    const { email, password, name } = registerDto;

    console.log('Registration attempt for email:', email);

    // Check if user already exists
    const existingUser = await this.userService.findByEmail(email);
    if (existingUser) {
      console.log('User already exists for email:', email);
      throw new UnauthorizedException('User already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    console.log('Creating new user...');

    // Create user
    const user = await this.userService.create({
      email,
      password: hashedPassword,
      name,
    });

    console.log('User created successfully with ID:', user.id);

    // Generate JWT token
    const token = this.generateToken(user.id, user.email);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      token,
    };
  }

  async login(loginDto: LoginDto) {
    const { email, password } = loginDto;

    console.log('Login attempt for email:', email);

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user) {
      console.log('User not found for email:', email);
      throw new UnauthorizedException('Invalid email or password');
    }

    console.log('User found, verifying password...');

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log('Invalid password for email:', email);
      throw new UnauthorizedException('Invalid email or password');
    }

    console.log('Login successful for email:', email);

    // Generate JWT token
    const token = this.generateToken(user.id, user.email);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      token,
    };
  }

<<<<<<< HEAD
  private generateToken(userId: number, email: string): string {
=======
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
      throw new UnauthorizedException('Refresh token komt niet overeen met sessie');
    }

    const user = await this.userService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('Gebruiker niet gevonden');
    }

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

    return {
      token: this.generateAccessToken(user.id, user.email),
      refreshToken: nextRefreshToken,
    };
  }

  async forgotPassword(
    forgotPasswordDto: ForgotPasswordDto,
    requestOrigin?: string,
  ) {
    const { email } = forgotPasswordDto;

    console.log('Forgot password request for email:', email);

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user) {
      console.log('User not found for email:', email);
      throw new BadRequestException('Deze e-mail is niet gelinkt aan een gebruiker.');
    }

    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');
    
    // Create password reset token in database (expires in 1 hour)
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    
    await this.prismaService.passwordResetToken.create({
      data: {
        userId: user.id,
        token: hashedToken,
        expiresAt,
      },
    });

    // Build reset link (adjust the URL to your app's URL)
    const frontendBaseUrl = requestOrigin || process.env.FRONTEND_URL || 'http://localhost:3000';
    const resetLink = `${frontendBaseUrl}/reset-password?token=${resetToken}`;

    // Send email
    try {
      await this.emailService.sendPasswordResetEmail(email, resetToken, resetLink);
      console.log('Password reset email sent to:', email);
    } catch (error) {
      console.error('Verzenden van reset e-mail is mislukt:', error);
      throw new BadRequestException('Verzenden van reset e-mail is mislukt');
    }

    return {
      message: 'Resetlink is verzonden. Controleer je e-mail.',
    };
  }

  async verifyResetToken(verifyResetTokenDto: VerifyResetTokenDto) {
    const { token } = verifyResetTokenDto;

    if (!token) {
      throw new BadRequestException('Reset-token is verplicht');
    }

    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

    const resetTokenRecord = await this.prismaService.passwordResetToken.findUnique({
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

    console.log('Reset password request with token');

    // Validate password match
    if (password !== confirmPassword) {
      throw new BadRequestException('Wachtwoorden komen niet overeen');
    }

    // Validate password strength (at least 8 characters)
    if (password.length < 8) {
      throw new BadRequestException('Wachtwoord moet minimaal 8 tekens lang zijn');
    }

    // Hash the provided token to find it in database
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

    // Find the reset token
    const resetTokenRecord = await this.prismaService.passwordResetToken.findUnique({
      where: { token: hashedToken },
      include: { user: true },
    });

    if (!resetTokenRecord) {
      throw new BadRequestException('Ongeldige reset-token');
    }

    // Check if token has expired
    if (new Date() > resetTokenRecord.expiresAt) {
      throw new BadRequestException('Reset-link is verlopen');
    }

    // Check if token was already used
    if (resetTokenRecord.usedAt) {
      throw new BadRequestException('Reset-link is al gebruikt');
    }

    // Hash the new password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Update user password and mark token as used
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

    console.log('Password reset successful for user:', resetTokenRecord.user.email);

    return {
      message: 'Wachtwoord is succesvol gewijzigd. Je kunt nu inloggen met je nieuwe wachtwoord.',
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

      if (newPassword.length < 8) {
        throw new BadRequestException('Wachtwoord moet minimaal 8 tekens zijn');
      }

      const hashed = await bcrypt.hash(newPassword, 12);

      await this.prismaService.user.update({
        where: { id: userId },
        data: { password: hashed },
      });

      return { message: 'Wachtwoord succesvol gewijzigd' };
  }

  private generateAccessToken(userId: number, email: string): string {
>>>>>>> 17698a8 (feat(profile): implement password change modal and backend route)
    return jwt.sign(
      { sub: userId, email },
      process.env.JWT_SECRET || 'dev_secret_change_me',
      { expiresIn: '7d' }
    );
  }

  async verifyToken(token: string) {
    try {
      return jwt.verify(token, process.env.JWT_SECRET || 'dev_secret_change_me');
    } catch (error) {
      throw new UnauthorizedException('Invalid token');
    }
  }
}