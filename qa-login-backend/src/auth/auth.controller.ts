import { Controller, Post, Body, HttpStatus, HttpCode, HttpException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';

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
}