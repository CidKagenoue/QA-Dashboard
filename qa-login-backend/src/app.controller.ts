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
        'GET /accounts': 'List accounts for account management',
        'POST /accounts': 'Create a managed account',
        'PATCH /accounts/:id/access': 'Update account access rights',
        'DELETE /accounts/:id': 'Delete a managed account',
      },
      timestamp: new Date().toISOString(),
    };
  }
}
