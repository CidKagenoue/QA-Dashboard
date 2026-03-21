import { Controller, Post, Body, HttpStatus, HttpCode, Req } from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  LoginDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  VerifyResetTokenDto,
} from './dto/auth.dto';
import { Public } from './public.decorator';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Public()
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
}