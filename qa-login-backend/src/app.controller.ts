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
        'POST /auth/refresh': 'Access token vernieuwen',
        'POST /auth/logout': 'Refresh token ongeldig maken',
        'POST /auth/forgot-password': 'Resetlink versturen',
        'POST /auth/verify-reset-token': 'Reset-token valideren',
        'POST /auth/reset-password': 'Wachtwoord resetten',
        'GET /accounts': 'Accounts opvragen voor accountbeheer',
        'POST /accounts': 'Beheerd account aanmaken',
        'PATCH /accounts/:id/access': 'Toegangsrechten van account aanpassen',
        'DELETE /accounts/:id': 'Account verwijderen',
        'GET /departments': 'Afdelingen opvragen',
        'GET /maintenance-inspections': 'Onderhoud en keuringen opvragen',
        'GET /maintenance-inspections/form-data': 'Vestigingen voor onderhoudsformulier opvragen',
        'POST /maintenance-inspections': 'Onderhoud/keuring aanmaken',
      },
      timestamp: new Date().toISOString(),
    };
  }
}
