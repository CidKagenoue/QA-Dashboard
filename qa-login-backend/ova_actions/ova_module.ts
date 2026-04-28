// qa-login-backend/src/ova/ova.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { UserModule } from 'src/user/user.module';
import { OvaActionsController } from './ova_actions_controller';
import { OvaActionsService } from './ova_actions_service';


// Importeer hier ook je bestaande OvaTickets controller/service als die al bestaat
// import { OvaTicketsController } from './ova-tickets.controller';
// import { OvaTicketsService } from './ova-tickets.service';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [
    OvaActionsController,
    // OvaTicketsController,  // voeg toe als die al bestaat
  ],
  providers: [
    OvaActionsService,
    // OvaTicketsService,     // voeg toe als die al bestaat
  ],
})
export class OvaModule {}