<<<<<<< HEAD
import { Controller, Post, Body, HttpStatus, HttpCode, HttpException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';
=======
import { Controller, Post, Body, HttpStatus, HttpCode, Req, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  LoginDto,
  RefreshTokenDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  VerifyResetTokenDto,
} from './dto/auth.dto';
import { Public } from './public.decorator';
import { JwtPayload } from 'jsonwebtoken';
>>>>>>> 17698a8 (feat(profile): implement password change modal and backend route)

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  async register(@Body() registerDto: RegisterDto) {
    try {
      console.log('Register request received:', { email: registerDto.email, hasName: !!registerDto.name });
      return await this.authService.register(registerDto);
    } catch (error) {
      console.error('Registration error:', error.message);
      throw error;
    }
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() loginDto: LoginDto) {
    try {
      console.log('Login request received for email:', loginDto.email);
      return await this.authService.login(loginDto);
    } catch (error) {
      console.error('Login error:', error.message);
      throw error;
    }
  }
<<<<<<< HEAD
=======

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  async forgotPassword(@Body() forgotPasswordDto: ForgotPasswordDto, @Req() req: any) {
    try {
      console.log('Forgot password request received for email:', forgotPasswordDto.email);
      return await this.authService.forgotPassword(forgotPasswordDto, req?.headers?.origin);
    } catch (error) {
      console.error('Forgot password error:', error.message);
      throw error;
    }
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() refreshTokenDto: RefreshTokenDto) {
    try {
      return await this.authService.refresh(refreshTokenDto);
    } catch (error) {
      console.error('Refresh error:', error.message);
      throw error;
    }
  }

  @Public()
  @Post('verify-reset-token')
  @HttpCode(HttpStatus.OK)
  async verifyResetToken(@Body() verifyResetTokenDto: VerifyResetTokenDto) {
    try {
      console.log('Verify reset token request received');
      return await this.authService.verifyResetToken(verifyResetTokenDto);
    } catch (error) {
      console.error('Verify reset token error:', error.message);
      throw error;
    }
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  async resetPassword(@Body() resetPasswordDto: ResetPasswordDto) {
    try {
      console.log('Reset password request received');
      return await this.authService.resetPassword(resetPasswordDto);
    } catch (error) {
      console.error('Reset password error:', error.message);
      throw error;
    }
  }
  
  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  async changePassword(
    @Req() req: any,
    @Body()
    body: {
      currentPassword: string;
      newPassword: string;
      confirmNewPassword: string;
    },
  ) {
    const authHeader = req.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Geen geldige token');
    }

    const token = authHeader.replace('Bearer ', '');
    const decoded = await this.authService.verifyToken(token);

    if (typeof decoded !== 'object' || decoded === null) {
      throw new UnauthorizedException('Ongeldig token formaat');
    }

    const payload = decoded as JwtPayload;

    if (!payload.sub) {
      throw new UnauthorizedException('Token bevat geen geldig user ID');
    }

    const userId = Number(payload.sub);

    if (isNaN(userId)) {
      throw new UnauthorizedException('Ongeldig user ID in token');
    }

    return await this.authService.changePassword(
      userId,
      body.currentPassword,
      body.newPassword,
      body.confirmNewPassword,
    );
  }
>>>>>>> 17698a8 (feat(profile): implement password change modal and backend route)
}