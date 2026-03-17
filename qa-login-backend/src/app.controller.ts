import { Controller, Get } from '@nestjs/common';
import { Public } from './auth/public.decorator';

@Controller()
export class AppController {
  @Public()
  @Get()
  getApiInfo() {
    return {
      message: 'QA Dashboard API is running',
      version: '1.0.0',
      endpoints: {
        'POST /auth/register': 'Register a new user',
        'POST /auth/login': 'Login user',
      },
      timestamp: new Date().toISOString(),
    };
  }
}