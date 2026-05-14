// qa-login-backend/src/ova/ova.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { UserModule } from 'src/user/user.module';
import { OvaActionsController } from './ova-actions.controller';
import { OvaActionsService } from './ova-actions.service';
import { OvaTicketsController } from './ova-tickets.controller';
import { OvaTicketsService } from './ova-tickets.service';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [
    OvaActionsController,
    OvaTicketsController,
  ],
  providers: [
    OvaActionsService,
    OvaTicketsService,
  ],
})
export class OvaModule {}