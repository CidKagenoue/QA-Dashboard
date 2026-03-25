import { Controller, Get } from '@nestjs/common';
import { Public } from './auth/public.decorator';

@Controller()
export class AppController {
  @Public()
  @Get()
  getApiInfo() {
    return {
      message: 'QA Dashboard API draait',
      version: '1.0.0',
      endpoints: {
        'POST /auth/login': 'Gebruiker inloggen',
      },
      timestamp: new Date().toISOString(),
    };
  }
}