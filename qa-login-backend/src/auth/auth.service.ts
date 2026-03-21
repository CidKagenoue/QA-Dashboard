import {
  Injectable,
  OnModuleInit,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { UserService } from '../user/user.service';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import {
  LoginDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  VerifyResetTokenDto,
} from './dto/auth.dto';
import * as crypto from 'crypto';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    private userService: UserService,
    private prismaService: PrismaService,
    private emailService: EmailService,
  ) {}

  async onModuleInit() {
    await this.ensureDefaultAdmin();
    await this.ensureTestUser();
  }

  async login(loginDto: LoginDto) {
    const { email, password } = loginDto;

    console.log('Login attempt for email:', email);

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user) {
      console.log('User not found for email:', email);
      throw new UnauthorizedException('Ongeldig e-mailadres of wachtwoord');
    }

    console.log('User found, verifying password...');

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log('Invalid password for email:', email);
      throw new UnauthorizedException('Ongeldig e-mailadres of wachtwoord');
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

  private generateToken(userId: number, email: string): string {
    return jwt.sign(
      { sub: userId, email },
      process.env.JWT_SECRET || 'dev_secret_change_me',
      { expiresIn: '7d' }
    );
  }

  async verifyToken(token: string) {
    try {
      return jwt.verify(token, process.env.JWT_SECRET || 'dev_secret_change_me');
    } catch {
      throw new UnauthorizedException('Ongeldige token');
    }
  }

  private async ensureDefaultAdmin() {
    const existingAdmin = await this.userService.findByEmail('admin');
    if (existingAdmin) {
      return;
    }

    const hashedPassword = await bcrypt.hash('root123', 12);
    await this.userService.create({
      email: 'admin',
      password: hashedPassword,
      name: 'Administrator',
    });
  }

  private async ensureTestUser() {
    const existingUser = await this.userService.findByEmail('Oualidkasmi5@gmail.com');
    if (existingUser) {
      return;
    }

    const hashedPassword = await bcrypt.hash('root123', 12);
    await this.userService.create({
      email: 'Oualidkasmi5@gmail.com',
      password: hashedPassword,
      name: 'Ouali Kasmi',
    });
    console.log('Test user created: Oualidkasmi5@gmail.com');
  }
}