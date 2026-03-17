import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  getApiInfo() {
    return {
      message: 'QA Dashboard API is running',
      version: '1.0.0',
      endpoints: {
        'POST /auth/login': 'Login user',
      },
      timestamp: new Date().toISOString(),
    };
  }
}